#!/usr/bin/env bash
# test_execute_task_coordinator_firewall.sh - gateway for Execute_Task_Coordinator_Source_Firewall.
# Fixtures are mktemp repos; the vault and kit repos are never mutated.
# ECF_SKIP_SUITES=1 skips the full-chain run (aggregators use it to avoid recursion).
set -uo pipefail
unset TITAN_SESSION_ID TELEMETRY_DIR ACC_SKIP_GATEWAY

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
KIT="$(cd "${KIT_ROOT:-$HOME/AI_Workflow/claude-agent-kit}" && pwd -P)"
OC_AGENT="${ECF_OC_AGENT_DIR:-$HOME/.config/opencode/agent}"
OC_CMD="$(dirname "$OC_AGENT")/command"
ET="$KIT/project-template/.claude/commands/execute_task.md"
CT="$KIT/project-template/.claude/commands/close_task.md"
TMP="$(cd "$(mktemp -d)" && pwd -P)"; trap 'rm -rf "$TMP"' EXIT
FAILS=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAILS=$((FAILS + 1)); }
eq() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (got '$2', want '$3')"; fi; }
nonempty() { if [ -n "$2" ]; then pass "$1"; else fail "$1 (empty)"; fi; }
empty() { if [ -z "$2" ]; then pass "$1"; else fail "$1 (got '$2')"; fi; }

# require_all <label> <file> <fixed string>...
require_all() {
  local label="$1" f="$2" s; shift 2
  for s in "$@"; do
    grep -qF -- "$s" "$f" && pass "$label has: $s" || fail "$label missing: $s"
  done
}
# fixed-string checker returns 0 when every string is present
has_all() { local f="$1" s; shift; for s in "$@"; do grep -qF -- "$s" "$f" || return 1; done; }

newrepo() {
  local d="$TMP/$1"; mkdir -p "$d"; git -C "$d" init -q
  git -C "$d" config user.name t; git -C "$d" config user.email t@t; git -C "$d" config commit.gpgsign false
  echo "$d"
}

[ -f "$ET" ] && [ -f "$CT" ] || { echo "FAIL: kit runbooks not found under $KIT"; exit 1; }

# --- DoD1: HARD RULE ---
awk '/^## HARD RULE/{f=1;next} /^## /{f=0} f' "$ET" > "$TMP/hard"
HR_STRINGS=('never creates, edits or deletes repo source' '`Edit`' '`Write`' '`write`' '`search_replace`' '`apply_patch`' '`>`' '`rm`' '`mv`' '`sed -i`' '`disallowed-tools` is not enforced on every harness' 'this text is the rule')
has_all "$TMP/hard" "${HR_STRINGS[@]}" && pass "DoD1 HARD RULE has the source firewall phrases" || fail "DoD1 HARD RULE phrases"
grep -vF 'search_replace' "$TMP/hard" > "$TMP/hard_red"
has_all "$TMP/hard_red" "${HR_STRINGS[@]}" && fail "DoD1 RED: copy without search_replace should fail" || pass "DoD1 RED: copy without search_replace fails the checker"

# --- DoD2: Step 10 static ---
awk '/^## Step 10 /{f=1} /^## Step 11 /{f=0} f' "$ET" > "$TMP/s10"
awk '/^## Step 11 /{f=1} /^## Step 12 /{f=0} f' "$ET" > "$TMP/s11"
require_all "DoD2 Step 10" "$TMP/s10" 'cancelled, killed, timed out or errored' 'git status --short' 'BUILD_CHANGED=' '§ Builder failure' "never takes over the builder's work"
n="$(grep -o 'builder check' "$TMP/s10" | wc -l | tr -d ' ')"
[ "$n" -ge 3 ] && pass "DoD2 builder check count >= 3 ($n)" || fail "DoD2 builder check count ($n)"
require_all "DoD2 Step 11" "$TMP/s11" '§ Builder failure'

# --- DoD2: Step 10 behavioural ---
awk '/^## Step 10 /{f=1} /^## Step 11 /{f=0} f' "$ET" | awk '/^BUILD_CHANGED=/{on=1} on{ if ($0 ~ /^```/) exit; print }' > "$TMP/bc.sh"
nonempty "DoD2 builder-check block extracted" "$(cat "$TMP/bc.sh")"
sed 's#on && /^\#/{on=0}##' "$TMP/bc.sh" > "$TMP/bc_red.sh"
grep -qF 'on=0' "$TMP/bc_red.sh" && fail "DoD2 RED block still contains the stop rule" || pass "DoD2 RED block built (stop rule removed)"

R="$(newrepo bc)"; R2="$(newrepo bc2)"
mkdir -p "$R/sub" "$R/dir with space"
echo 1 > "$R/a.txt"; echo 1 > "$R/b.txt"; echo 1 > "$R/sub/keep.txt"; echo 1 > "$R/dir with space/f.txt"; echo 1 > "$R2/x.txt"
git -C "$R" add -A; git -C "$R" commit -qm init; git -C "$R2" add -A; git -C "$R2" commit -qm init
cat > "$TMP/task.md" <<EOF
### Files touched
- [EDIT] \`a.txt\`
- [NEW] \`sub/new.txt\` - new
- [EDIT] \`dir with space/f.txt\`
- [EDIT] \`$R2/x.txt\`

### Risks
- [EDIT] \`b.txt\`
EOF
runbc() { # script ; prints result
  (cd "$R" && TASK_PATH="$TMP/task.md" bash -c "$(cat "$1"); printf %s \"\$BUILD_CHANGED\"" 2>/dev/null)
}
reset() { git -C "$R" checkout -q -- . ; git -C "$R" clean -fdq; git -C "$R2" checkout -q -- .; }
empty "DoD2 clean tree -> empty" "$(runbc "$TMP/bc.sh")"
echo 2 >> "$R/b.txt"; empty "DoD2 only b.txt (Risks heading) -> empty" "$(runbc "$TMP/bc.sh")"
nonempty "DoD2 RED: without stop rule b.txt is reported" "$(runbc "$TMP/bc_red.sh")"
reset
echo 2 >> "$R/a.txt"; nonempty "DoD2 a.txt modified -> non-empty" "$(runbc "$TMP/bc.sh")"; reset
echo 2 > "$R/sub/new.txt"; nonempty "DoD2 sub/new.txt created -> non-empty" "$(runbc "$TMP/bc.sh")"; reset
echo 2 >> "$R/dir with space/f.txt"; nonempty "DoD2 spaced-dir file modified -> non-empty" "$(runbc "$TMP/bc.sh")"; reset
echo 2 >> "$R2/x.txt"; nonempty "DoD2 second-repo file modified -> non-empty" "$(runbc "$TMP/bc.sh")"; reset

# --- DoD3: Builder failure section ---
c="$(grep -cxF '## Builder failure' "$ET")"; eq "DoD3 exactly one '## Builder failure' heading" "$c" 1
l16="$(grep -n '^## Step 16' "$ET" | cut -d: -f1 | head -n 1)"; lbf="$(grep -nxF '## Builder failure' "$ET" | cut -d: -f1 | head -n 1)"; leh="$(grep -n '^## Error handling protocol' "$ET" | cut -d: -f1 | head -n 1)"
[ -n "$l16" ] && [ -n "$lbf" ] && [ -n "$leh" ] && [ "$l16" -lt "$lbf" ] && [ "$lbf" -lt "$leh" ] && pass "DoD3 section placed after Step 16 and before Error handling" || fail "DoD3 section placement"
awk '/^## Builder failure$/{f=1;next} /^## /{f=0} f' "$ET" > "$TMP/bf"
BF_STRINGS=('emit_telemetry.sh invoke_builders error auto E2 Executioner "<Task_Name>"' 'Reply `retry`, `panel` or `abort`.' 'panel_guard.sh --task "<Task_Name>" --run-id "${ORCH_RUN_ID:-interactive}"' '`failure-panel`' 'runtime' 'last commands' 'files changed' 'never authorizes the coordinator to write code' '`abort`, then `/quick`' 'Steps 11-13 are never skipped' 'remains in_progress' '--state no_progress' 'never takes over' 'telemetry_start.sh invoke_builders')
has_all "$TMP/bf" "${BF_STRINGS[@]}" && pass "DoD3 Builder failure section phrases" || { fail "DoD3 Builder failure section phrases"; for s in "${BF_STRINGS[@]}"; do grep -qF -- "$s" "$TMP/bf" || echo "  missing: $s"; done; }
sed 's/`retry`, `panel` or/`retry` or/' "$TMP/bf" > "$TMP/bf_red"
has_all "$TMP/bf_red" "${BF_STRINGS[@]}" && fail "DoD3 RED: HALT line without panel should fail" || pass "DoD3 RED: HALT line without panel fails the checker"

# --- DoD4: error protocol, Step 16, agent starts ---
awk '/^## Error handling protocol/{f=1;next} /^## /{f=0} f' "$ET" > "$TMP/eh"
require_all "DoD4 Error handling" "$TMP/eh" 'a builder failure (§ Builder failure)'
awk '/^## Step 16/{f=1;next} /^## /{f=0} f' "$ET" > "$TMP/s16"
require_all "DoD4 Step 16" "$TMP/s16" 'queued no_progress'
awk '/^## Agent starts/{f=1;next} /^## /{f=0} f' "$ET" > "$TMP/as"
require_all "DoD4 Agent starts" "$TMP/as" 'every `failure-panel`'

# --- DoD5: close_task static ---
awk '/^## Invocation/{f=1;next} /^## /{f=0} f' "$CT" > "$TMP/inv"
require_all "DoD5 Invocation" "$TMP/inv" '--override-evidence' 'EVIDENCE_OVERRIDE=1'
a="$(grep -n '^## Step 4 ' "$CT" | cut -d: -f1 | head -n 1)"; b="$(grep -nxF '## Step 4.4 — evidence guard' "$CT" | cut -d: -f1 | head -n 1)"; c="$(grep -n '^## Step 4\.5' "$CT" | cut -d: -f1 | head -n 1)"
[ -n "$a" ] && [ -n "$b" ] && [ -n "$c" ] && [ "$a" -lt "$b" ] && [ "$b" -lt "$c" ] && pass "DoD5 Step 4 < 4.4 < 4.5" || fail "DoD5 step order"
awk '/^## Step 4\.4/{f=1;next} /^## Step 4\.5/{f=0} f' "$CT" > "$TMP/s44"
require_all "DoD5 Step 4.4" "$TMP/s44" '--state close_gate' 'evidence missing' 'do not run Steps 4.5-10' 'E3: refusing to close'
awk '/^## Step 5 /{f=1;next} /^## Step 5\.5/{f=0} f' "$CT" > "$TMP/s5"
require_all "DoD5 Step 5" "$TMP/s5" '**Evidence override:**'
awk '/^## Step 8 /{f=1;next} /^## Step 9/{f=0} f' "$CT" > "$TMP/s8"
require_all "DoD5 Step 8" "$TMP/s8" '<EVIDENCE_NOTE>' 'Evidence override:'

# --- DoD5: close_task behavioural ---
awk '/^## Step 4\.4/{f=1} /^## Step 4\.5/{f=0} f' "$CT" | awk '/^EV_RC=0; EV_MISSING=""/{on=1} on{ if ($0 ~ /^```/) exit; print }' > "$TMP/ev.sh"
nonempty "DoD5 evidence block extracted" "$(cat "$TMP/ev.sh")"
grep -v '|| EV_MISSING=' "$TMP/ev.sh" | sed 's/ \\$//' > "$TMP/ev_red.sh"
W="$TMP/work"; mkdir -p "$W"; ln -s "$REPO_ROOT" "$W/.vault_link"
mktask() { # name vr vo ; vr/vo = empty|full|none
  local f="$TMP/$1.md"
  { echo "# T"; echo
    case "$2" in
      empty) printf '## ✅ Validator Report\n> template\n<!-- write_task_section section=validator_report -->\n\n' ;;
      full) printf '## ✅ Validator Report\nSHIP\n\n' ;;
    esac
    case "$3" in
      empty) printf '## 📊 Verification Output\n> template\n<!-- write_task_section section=verification_output -->\n\n' ;;
      full) printf '## 📊 Verification Output\nexit 0\n\n' ;;
    esac
    printf '## 🏁 COMPLETION SUMMARY (Post-Mortem)\n- **Technical Meat:** x\n'; } > "$f"
  echo "$f"
}
runev() { # script taskfile [env...] ; sets EVOUT
  local s="$1" t="$2"; shift 2
  EVOUT="$(cd "$W" && env "$@" TASK_PATH="$t" bash -c "$(cat "$s"); printf '%s|%s' \"\$EV_RC\" \"\$EV_MISSING\"" 2>/dev/null)"
}
T_EE="$(mktask ee empty empty)"; T_FE="$(mktask fe full empty)"; T_FF="$(mktask ff full full)"; T_NN="$(mktask nn none none)"
runev "$TMP/ev.sh" "$T_EE" X=1
case "$EVOUT" in 3\|*"Validator Report"*"Verification Output"*) pass "DoD5 both empty -> 3 naming both" ;; *) fail "DoD5 both empty (got '$EVOUT')" ;; esac
runev "$TMP/ev.sh" "$T_FE" X=1; case "$EVOUT" in 3\|*"Verification Output") pass "DoD5 report populated, output empty -> 3" ;; *) fail "DoD5 half-empty (got '$EVOUT')" ;; esac
runev "$TMP/ev.sh" "$T_FF" X=1; eq "DoD5 both populated -> 0, no missing" "$EVOUT" "0|"
runev "$TMP/ev.sh" "$T_EE" EVIDENCE_OVERRIDE=1; case "$EVOUT" in 0\|?*) pass "DoD5 override -> 0 with missing recorded" ;; *) fail "DoD5 override (got '$EVOUT')" ;; esac
runev "$TMP/ev.sh" "$T_EE" EVIDENCE_OVERRIDE=1 ORCH_RUN_ID=run-20261111T000000Z; case "$EVOUT" in 3\|*) pass "DoD5 override ignored under run-id -> 3" ;; *) fail "DoD5 override under run-id (got '$EVOUT')" ;; esac
runev "$TMP/ev.sh" "$T_NN" X=1; case "$EVOUT" in 3\|*) pass "DoD5 sections missing -> 3" ;; *) fail "DoD5 missing sections (got '$EVOUT')" ;; esac
runev "$TMP/ev_red.sh" "$T_EE" X=1; case "$EVOUT" in 0\|*) pass "DoD5 RED: without || EV_MISSING= returns 0 on empty fixture" ;; *) fail "DoD5 RED (got '$EVOUT')" ;; esac

# --- DoD6: CI check, OpenCode, guards ---
( cd "$KIT" && bash tests/test_no_inline_mutations.sh >/dev/null 2>&1 ) && pass "kit test_no_inline_mutations green" || fail "kit test_no_inline_mutations"
bash "$KIT/install.sh" check-opencode --path "$OC_AGENT" >/dev/null 2>&1 && pass "check-opencode exits 0" || fail "check-opencode (run install.sh setup-opencode)"
{ grep -qF '## Builder failure' "$OC_CMD/execute_task.md" && grep -qF 'never creates, edits or deletes repo source' "$OC_CMD/execute_task.md"; } 2>/dev/null && pass "OpenCode execute_task is fresh" || fail "OpenCode execute_task stale (run install.sh setup-opencode)"
grep -qF -- '--override-evidence' "$OC_CMD/close_task.md" 2>/dev/null && pass "OpenCode close_task is fresh" || fail "OpenCode close_task stale (run install.sh setup-opencode)"
grep -q '@' "$ET" && fail "execute_task.md contains @" || pass "execute_task.md has no @"
eq "Autonomous caller (Orchestrator) — count" "$(grep -c 'Autonomous caller (Orchestrator) —' "$ET")" 3
awk '/^## Step 6/{f=1} /^## Step 13/{f=0} f' "$ET" | grep -qwE 'Edit|Write' && fail "Steps 6-12 contain Edit/Write" || pass "Steps 6-12 have no Edit/Write"

# --- wiring ---
for f in test_chain_consolidation test_chain_targeted_tests test_spec_gate_hardening test_pm_reviewer_single_pass test_macro_start_timestamp test_hook_argument_scope test_kit_telemetry_isolation; do
  c="$(grep -cF '[ "$b" = test_execute_task_coordinator_firewall.sh ] && envp="ECF_SKIP_SUITES=1"' "$REPO_ROOT/tests/$f.sh")"
  eq "$f wires ECF_SKIP_SUITES" "$c" 1
done

# --- suites ---
if [ "${ECF_SKIP_SUITES:-0}" = 1 ]; then
  echo "suites skipped: ECF_SKIP_SUITES=1"
else
  if ( cd "$REPO_ROOT" && bash tests/test_chain_consolidation.sh >"$TMP/chain.out" 2>&1 ); then
    pass "full chain consolidation green"
  else
    fail "full chain consolidation failed"; grep '^FAIL' "$TMP/chain.out"
  fi
fi

if [ "$FAILS" -eq 0 ]; then echo "ALL GREEN"; exit 0; fi
echo "$FAILS check(s) failed"; exit 1

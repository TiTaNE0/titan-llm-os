#!/usr/bin/env bash
# test_pm_reviewer_single_pass.sh - gateway for PM_Reviewer_Single_Pass_Findings.
# Pins the pm-reviewer single-pass contract and the execute_task Step 8 revision loop
# (with RED checks), then runs every kit suite and every vault test_*/smoke_* suite.
# PMR_SKIP_SUITES=1 skips the suite loops (the aggregator uses it to avoid recursion).
set -uo pipefail
unset TITAN_SESSION_ID

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
KIT="${KIT_ROOT:-$HOME/AI_Workflow/claude-agent-kit}"
EXEC="$KIT/project-template/.claude/commands/execute_task.md"
PMR="$KIT/global/agents/pm-reviewer.md"
PMR_DOC="$KIT/docs/cld/pm-reviewer.md"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
FAILS=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAILS=$((FAILS + 1)); }
want() {
  if printf '%s\n' "$2" | grep -qF -- "$3"; then pass "$1"; else fail "$1 (missing: $3)"; fi
}
deny() {
  if printf '%s\n' "$2" | grep -qF -- "$3"; then fail "$1 (present: $3)"; else pass "$1"; fi
}
eq() {
  if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (got '$2', want '$3')"; fi
}

# --- DoD 1: pm-reviewer contract -----------------------------------------------
check_pmr() { # file -> count of missing/forbidden items
  local f="$1" bad=0 p
  for p in 'List every finding in one pass' 'numbered list' \
    '[DoD fails on correct work]' '[DoD passes without delivery]' '[misreported result]' \
    '[internal contradiction]' '[scope creep]' '[03_Brain edit]' \
    'Style and hypothetical-misuse findings are excluded' 'FLAG: <N> findings' \
    'check only those findings plus regressions'; do
    grep -qF -- "$p" "$f" || bad=$((bad + 1))
  done
  for p in 'FLAG: <one-line reason>' 'Return EXACTLY one line' 'FLAG(reason)'; do
    ! grep -qF -- "$p" "$f" || bad=$((bad + 1))
  done
  echo "$bad"
}
eq "DoD1 global pm-reviewer contract" "$(check_pmr "$PMR")" 0
eq "DoD1 docs/cld pm-reviewer contract" "$(check_pmr "$PMR_DOC")" 0
cmp -s "$PMR" "$PMR_DOC" && pass "DoD1 global and docs copies byte-identical" || fail "DoD1 global and docs copies differ"
want "DoD1 model unchanged" "$(cat "$PMR")" 'model: opus'

grep -vF 'List every finding in one pass' "$PMR" > "$TMP/red1.md"
[ "$(check_pmr "$TMP/red1.md")" -ne 0 ] && pass "DoD1 RED single-pass sentence removed" || fail "DoD1 RED single-pass sentence removed not detected"
grep -vF 'Style and hypothetical-misuse findings are excluded' "$PMR" > "$TMP/red2.md"
[ "$(check_pmr "$TMP/red2.md")" -ne 0 ] && pass "DoD1 RED exclusion sentence removed" || fail "DoD1 RED exclusion sentence removed not detected"

# --- DoD 2: Step 8 contract ----------------------------------------------------
step8() { awk 'index($0,"## Step 8 ")==1{on=1} index($0,"## Step 9 ")==1{on=0} on' "$1"; }
auto_half() { step8 "$1" | awk '/^\*\*Autonomous caller/{on=1} on'; }
check_s8() { # exec file -> count of missing items
  local f="$1" bad=0 h p n spawns
  h="$(auto_half "$f")"
  for p in 'full numbered findings list' 'in one resume' 'resume the planner' \
    'check only those findings plus regressions' 'at most 2 revisions' \
    'reviewer flag after 2 revisions' '--overwrite' 'queue_attention.sh'; do
    printf '%s\n' "$h" | grep -qF -- "$p" || bad=$((bad + 1))
  done
  n="$(printf '%s\n' "$h" | grep -oF 'spec_rubric.sh' | wc -l | tr -d ' ')"
  [ "$n" -ge 2 ] || bad=$((bad + 1))
  spawns="$(printf '%s\n' "$h" | grep -oE '[Ss]pawn(ing)? (the )?`[a-z-]+`' | grep -oE '`[a-z-]+`' | sort -u | tr -d '`' | tr '\n' ' ')"
  [ "$spawns" = "pm-reviewer " ] || bad=$((bad + 1))
  echo "$bad"
}
eq "DoD2 Step 8 autonomous contract" "$(check_s8 "$EXEC")" 0

grep -vF 'check only those findings plus regressions' "$EXEC" > "$TMP/red3.md"
[ "$(check_s8 "$TMP/red3.md")" -ne 0 ] && pass "DoD2 RED re-review sentence removed" || fail "DoD2 RED re-review sentence removed not detected"
grep -vF 'at most 2 revisions' "$EXEC" > "$TMP/red4.md"
[ "$(check_s8 "$TMP/red4.md")" -ne 0 ] && pass "DoD2 RED bound removed" || fail "DoD2 RED bound removed not detected"

S8="$(step8 "$EXEC")"
want "DoD2 interactive half intact" "$S8" 'Do not proceed until the user approves'
want "DoD2 Exit 0 line starts spec_gate timer" "$(printf '%s\n' "$S8" | grep -F -- '- Exit 0 →')" 'telemetry_start.sh spec_gate'
want "DoD2 spec_gate emit with Orchestrator" "$S8" 'emit_telemetry.sh spec_gate <approve|flag> auto null Orchestrator'
deny "DoD2 no spec_gate duration arg" "$S8" 'spec_gate <approve|flag> 0'
eq "DoD2 Autonomous heading count" "$(grep -c '^\*\*Autonomous caller (Orchestrator) —' "$EXEC")" 3
if printf '%s\n' "$S8" | grep -qwE 'Write|Edit'; then fail "DoD2 Step 8 has no Write/Edit word"; else pass "DoD2 Step 8 has no Write/Edit word"; fi

# --- DoD 3: suites -------------------------------------------------------------
if [ "${PMR_SKIP_SUITES:-0}" = 1 ]; then
  echo "SKIP: suites"
else
  n=0
  for t in "$KIT"/tests/test_*.sh; do
    [ -f "$t" ] || continue
    n=$((n + 1))
    if ( cd "$KIT" && CLAUDE_BIN=__nonexistent__ bash "$t" >/dev/null 2>&1 ); then pass "kit $(basename "$t")"; else fail "kit $(basename "$t")"; fi
  done
  [ "$n" -ge 1 ] || fail "kit suite glob matched nothing"
  n=0
  for t in "$REPO_ROOT"/tests/test_*.sh "$REPO_ROOT"/tests/smoke_*.sh; do
    [ -f "$t" ] || continue
    b="$(basename "$t")"
    [ "$b" = test_pm_reviewer_single_pass.sh ] && continue
    n=$((n + 1))
    if [ "$b" = test_chain_consolidation.sh ]; then
      out="$( cd "$REPO_ROOT" && CHAIN_SKIP_SUITES=1 bash "tests/$b" 2>&1 )"
      if ! printf '%s\n' "$out" | grep -q '^FAIL:' && printf '%s\n' "$out" | grep -qF 'suites skipped: not a gateway pass'; then
        pass "vault $b (skip mode)"; else fail "vault $b (skip mode)"; fi
      continue
    fi
    envp=""; [ "$b" = test_thin_orchestrator.sh ] && envp="THIN_ORCH_SKIP_SUITES=1"; [ "$b" = test_kit_telemetry_isolation.sh ] && envp="KTI_SKIP_SUITES=1"; [ "$b" = test_chain_targeted_tests.sh ] && envp="CTT_SKIP_SUITES=1"; [ "$b" = test_macro_start_timestamp.sh ] && envp="MST_SKIP_SUITES=1"; [ "$b" = test_hook_argument_scope.sh ] && envp="HAS_SKIP_SUITES=1"; [ "$b" = test_spec_gate_hardening.sh ] && envp="SGH_SKIP_SUITES=1"
    if ( cd "$REPO_ROOT" && env $envp bash "tests/$b" >/dev/null 2>&1 ); then pass "vault $b"; else fail "vault $b"; fi
  done
  [ "$n" -ge 1 ] || fail "vault suite glob matched nothing"
  echo "not in suite glob: tests/acceptance/ (acceptance folders run test_chain_consolidation.sh in full, which runs this gateway)"
fi

if [ "$FAILS" -eq 0 ]; then echo "ALL GREEN"; exit 0; fi
echo "$FAILS check(s) failed"; exit 1

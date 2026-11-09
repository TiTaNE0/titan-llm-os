#!/usr/bin/env bash
# test_chain_consolidation.sh - gateway for Chain_Consolidation_Planner_Context_Pack.
# Checks: kernel classes (read-only), kit agent files, execute_task.md step structure,
# spec_rubric Responsibility-map / context-pack fixtures (+RED), telemetry_task_report
# --since fixtures, then every kit suite and every vault test_*/smoke_* suite.
# CHAIN_SKIP_SUITES=1 skips both suite loops for local iteration and forces exit 1.
# Every acceptance folder runs with the shared ACC_SKIP_GATEWAY=1 set.
set -uo pipefail
unset TITAN_SESSION_ID

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
KIT="${KIT_ROOT:-$HOME/AI_Workflow/claude-agent-kit}"
EXEC="$KIT/project-template/.claude/commands/execute_task.md"
AGENTS="$KIT/global/agents"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
FAILS=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAILS=$((FAILS + 1)); }
want() { # label text pattern(fixed)
  if printf '%s\n' "$2" | grep -qF -- "$3"; then pass "$1"; else fail "$1 (missing: $3)"; fi
}
deny() {
  if printf '%s\n' "$2" | grep -qF -- "$3"; then fail "$1 (present: $3)"; else pass "$1"; fi
}
want_re() { # label text pattern(ERE)
  if printf '%s\n' "$2" | grep -qE -- "$3"; then pass "$1"; else fail "$1 (missing: $3)"; fi
}
deny_w() { # label text word (whole-word, fixed-ish)
  if printf '%s\n' "$2" | grep -qw -- "$3"; then fail "$1 (present word: $3)"; else pass "$1"; fi
}
eq() { # label got want
  if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (got '$2', want '$3')"; fi
}

# --- DoD 1: kernel classes (read-only) ----------------------------------------
KERNEL="$REPO_ROOT/03_Brain/System_Agents.md"
want "DoD1 kernel lists planner as gate class" "$(cat "$KERNEL")" 'spec-writer, planner, pm-reviewer'
want "DoD1 kernel lists builder as worker class" "$(cat "$KERNEL")" 'story-writer, builder, backend-builder'

# --- DoD 2: agent files + execute_task structure -------------------------------
for a in planner builder researcher spec-writer backend-builder frontend-builder; do
  [ -f "$AGENTS/$a.md" ] && pass "DoD2 agent file $a.md" || fail "DoD2 agent file $a.md"
done
EXEC_TXT="$(cat "$EXEC")"
step() { awk -v a="## Step $1 " -v b="## Step $2 " 'index($0,a)==1{on=1} index($0,b)==1{on=0} on' "$EXEC"; }
S6="$(step 6 7)"; S8="$(step 8 9)"; S10="$(step 10 11)"; S13="$(step 13 14)"; S14="$(step 14 15)"
S612="$(step 6 13)"
S_NOT_910="$(printf '%s\n%s\n%s\n' "$(step 6 9)" "$(step 11 12)" "$(step 12 13)")"
want "DoD2 step6 spawns planner" "$S6" '`planner`'
want "DoD2 step6 invoke_planner" "$S6" 'invoke_planner'
for w in researcher spec-writer; do deny_w "DoD2 steps 6-12 no '$w'" "$S612" "$w"; done
for p in invoke_researcher invoke_spec_writer; do deny "DoD2 steps 6-12 no $p" "$S612" "$p"; done
for w in backend-builder frontend-builder; do deny_w "DoD2 steps 6-8,11-12 no '$w'" "$S_NOT_910" "$w"; done
want "DoD2 step8 persisted by the planner" "$S8" 'persisted by the planner'
want "DoD2 step8 planner brief" "$S8" 'planner brief'
want "DoD2 step10 builder" "$S10" '`builder`'
want "DoD2 step10 split field" "$S10" 'Build split: backend-frontend'
want "DoD2 states 4 agent starts" "$EXEC_TXT" '4 agent starts'
want "DoD2 description 4-agent" "$(grep -m1 '^description:' "$EXEC")" '4-agent'

# --- DoD 3: aliases, markers, install lists, pinned tests ----------------------
fm_model() { awk '/^---[ \t\r]*$/{n++; if(n==2) exit; next} n==1 && /^model:/{sub(/^model:[ \t]*/,""); print; exit}' "$1" | tr -d ' \t\r"'; }
eq "DoD3 planner model opus" "$(fm_model "$AGENTS/planner.md")" opus
eq "DoD3 builder model sonnet" "$(fm_model "$AGENTS/builder.md")" sonnet
for a in planner builder; do
  m="$(fm_model "$AGENTS/$a.md")"
  case "$m" in */*) fail "DoD3 $a alias has no slash" ;; *) pass "DoD3 $a alias has no slash" ;; esac
  case "$m" in sonnet|opus|haiku|fable) pass "DoD3 $a alias is a tier alias" ;; *) fail "DoD3 $a alias is a tier alias ($m)" ;; esac
done
PL="$(cat "$AGENTS/planner.md")"
for p in '### Responsibility map' 'name the file that currently owns it' '### Context pack' 'Build split:' 'bash_write_task_section_only.sh'; do
  want "DoD3 planner.md has '$p'" "$PL" "$p"
done
want "DoD3 install.sh gate list has planner" "$(grep '^OPENCODE_GATE_ROLES=' "$KIT/install.sh")" ' planner '
want "DoD3 install.sh worker list has builder" "$(grep '^OPENCODE_WORKER_ROLES=' "$KIT/install.sh")" ' builder '
want "DoD3 test_agent_models EXPECTED planner" "$(grep '^EXPECTED=' "$KIT/tests/test_agent_models.sh")" 'planner:opus'
want "DoD3 test_agent_models EXPECTED builder" "$(grep '^EXPECTED=' "$KIT/tests/test_agent_models.sh")" 'builder:sonnet'
want "DoD3 test_install_opencode GATE_ROLES planner" "$(grep '^GATE_ROLES=' "$KIT/tests/test_install_opencode.sh")" 'planner'
want "DoD3 test_install_opencode WORKER_ROLES builder" "$(grep '^WORKER_ROLES=' "$KIT/tests/test_install_opencode.sh")" ' builder '
TOPO="$KIT/tests/test_topology_regression.sh"
for fn in check_researcher_contract check_planner_contract; do
  n="$(grep -c "$fn" "$TOPO" || true)"
  [ "$n" -ge 2 ] && pass "DoD3 topology defines and calls $fn" || fail "DoD3 topology defines and calls $fn (found $n)"
done

# spec_rubric fixtures
RUB="$REPO_ROOT/.scripts/spec_rubric.sh"
mk_task() { # file spec_body
  {
    printf -- '---\nproject: [[P]]\nstatus: in_progress\ntype: task\npriority: high\n---\n\n# Task\n\n'
    printf -- '## 📐 Spec\n> Populated by invoke_spec_writer.\n<!-- write_task_section section=spec -->\n\n%s\n\n' "$2"
    printf -- '## ✅ Validator Report\n> placeholder\n'
  } > "$1"
}
rubric_rc() { # script file -> sets RC, ERR
  RC=0; ERR="$("$1" --task-path "$2" 2>&1 >/dev/null)" || RC=$?
}
BASE='Edit `.scripts/foo.sh`.'
MAP=$'### Responsibility map\n- Rubric: `.scripts/spec_rubric.sh`\n'
PACK=$'### Context pack\n- Read: `.scripts/spec_rubric.sh:1-20` - checks\n- Do not touch: x\n'
mk_task "$TMP/full.md" "$BASE
$MAP$PACK"
mk_task "$TMP/nomap.md" "$BASE
$PACK"
mk_task "$TMP/emptymap.md" "$BASE
### Responsibility map

$PACK"
mk_task "$TMP/nopack.md" "$BASE
$MAP"
mk_task "$TMP/emptypack.md" "$BASE
$MAP### Context pack
Only prose here.
"
mk_task "$TMP/outside.md" "$BASE
- Read: \`.scripts/foo.sh:1-5\` - outside any block
$MAP### Context pack

### Build split
Build split: none"
rubric_rc "$RUB" "$TMP/full.md";     eq "DoD3 rubric full spec -> 0" "$RC" 0
rubric_rc "$RUB" "$TMP/nomap.md";    eq "DoD3 rubric missing map -> 3" "$RC" 3; want "DoD3 rubric missing map msg" "$ERR" 'no Responsibility map'
rubric_rc "$RUB" "$TMP/emptymap.md"; eq "DoD3 rubric empty map -> 3" "$RC" 3; want "DoD3 rubric empty map msg" "$ERR" 'no Responsibility map'
rubric_rc "$RUB" "$TMP/nopack.md";   eq "DoD3 rubric missing pack -> 3" "$RC" 3; want "DoD3 rubric missing pack msg" "$ERR" 'no context pack'
rubric_rc "$RUB" "$TMP/emptypack.md"; eq "DoD3 rubric empty pack -> 3" "$RC" 3; want "DoD3 rubric empty pack msg" "$ERR" 'no context pack'
rubric_rc "$RUB" "$TMP/outside.md";  eq "DoD3 rubric Read outside block -> 3" "$RC" 3; want "DoD3 rubric Read outside msg" "$ERR" 'no context pack'
# RED: the same fixture passes when checks (d)/(e) are stripped.
mkdir -p "$TMP/red"; cp -R "$REPO_ROOT/.scripts/." "$TMP/red/"
sed -i.bak '/^# (d) Responsibility map/,/^echo "RUBRIC: PASS"/{/^echo "RUBRIC: PASS"/!d;}' "$TMP/red/spec_rubric.sh"
rubric_rc "$TMP/red/spec_rubric.sh" "$TMP/nomap.md"
eq "DoD3 RED stripped rubric accepts map-less spec" "$RC" 0

# --- DoD 4 structure -----------------------------------------------------------
for p in 'telemetry_task_report.sh --task' '--since' 'task_owner.sh --get' 'agent_starts:' 'measurement_scope:'; do
  want "DoD4 step13 has '$p'" "$S13" "$p"
done
L_AS="$(printf '%s\n' "$S13" | grep -nF 'agent_starts:' | head -n 1 | cut -d: -f1)"
L_TC="$(printf '%s\n' "$S13" | grep -nF '**Test command:**' | head -n 1 | cut -d: -f1)"
if [ -n "$L_AS" ] && [ -n "$L_TC" ] && [ "$L_AS" -lt "$L_TC" ]; then pass "DoD4 step13 agent_starts precedes Test command"; else fail "DoD4 step13 agent_starts precedes Test command ($L_AS/$L_TC)"; fi
for p in 'measurement missing' 'agent_starts: [1-9][0-9]*' 'agent_time_ms: [0-9]+' '--state close_gate'; do
  want "DoD4 step14 has '$p'" "$S14" "$p"
done
# Step 14 guard: run the extractor line from the kit against fixtures. A Spec that quotes the
# anchor followed by measurement lines must not satisfy it; the real section must.
GUARD_LINE="$(printf '%s\n' "$S14" | grep '^MEAS_BLOCK=')"
guard_ok() { # task file -> 0 when all three markers found
  local TASK_PATH="$1" MEAS_BLOCK
  eval "$GUARD_LINE"
  printf '%s\n' "$MEAS_BLOCK" | grep -qE '^agent_starts: [1-9][0-9]*$' \
    && printf '%s\n' "$MEAS_BLOCK" | grep -qE '^agent_time_ms: [0-9]+$' \
    && printf '%s\n' "$MEAS_BLOCK" | grep -qE '^measurement_scope: (run run-[0-9]{8}T[0-9]{6}Z|invocation)$'
}
ANCH='<!-- write_task_section section=verification_output -->'
MEASL=$'agent_starts: 4\nagent_time_ms: 10\nmeasurement_scope: invocation'
printf '## 📐 Spec\nquoted: %s\n%s\n\n## 📊 Verification Output\n%s\n\n## 🏁 Done\n' "$ANCH" "$MEASL" "$ANCH" > "$TMP/g_quoted.md"
guard_ok "$TMP/g_quoted.md" && fail "DoD4 guard refuses Spec-quoted anchor with empty Verification Output" || pass "DoD4 guard refuses Spec-quoted anchor with empty Verification Output"
printf '## 📐 Spec\n%s\n%s\n\n## 📊 Verification Output\n%s\n\n## 🏁 Done\n' "$ANCH" "$MEASL" "$ANCH" > "$TMP/g_quoted2.md"
guard_ok "$TMP/g_quoted2.md" && fail "DoD4 guard refuses anchor-only-in-Spec" || pass "DoD4 guard refuses anchor-only-in-Spec"
printf '## 📊 Verification Output\n%s\n%s\n\n**Test command:** `x`\n\n## 🏁 Done\n' "$ANCH" "$MEASL" > "$TMP/g_ok.md"
guard_ok "$TMP/g_ok.md" && pass "DoD4 guard accepts real measurement block" || fail "DoD4 guard accepts real measurement block"
printf '## 📊 Verification Output\n%s\n**Test command:** `x`\n%s\n' "$ANCH" "$MEASL" > "$TMP/g_after.md"
guard_ok "$TMP/g_after.md" && fail "DoD4 guard ignores markers after Test command" || pass "DoD4 guard ignores markers after Test command"
AS_BLOCK="$(awk '/^## Agent starts/{on=1;next} /^## /{on=0} on' "$EXEC")"
want "DoD4 Agent starts block rule" "$AS_BLOCK" 'resumes of an existing agent are not new starts'
want "DoD4 step8 spec_gate timer" "$S8" 'telemetry_start.sh spec_gate'
want "DoD4 step8 spec_gate measured" "$S8" 'spec_gate <approve|flag> auto'
deny "DoD4 step8 no hard-coded 0 duration" "$S8" 'spec_gate <approve|flag> 0'
# The spec's "exactly 3" counts the branch headings; Step 5.6's prose mention carries no em dash.
eq "DoD4 'Autonomous caller (Orchestrator) —' exactly 3" "$(grep -cF 'Autonomous caller (Orchestrator) —' "$EXEC")" 3

# --- DoD 4 report fixtures -----------------------------------------------------
REPORT="$REPO_ROOT/.scripts/telemetry_task_report.sh"
TD="$TMP/tel"; mkdir -p "$TD"
row() { printf '{"ts":"%s","macro":"%s","duration_ms":%s,"task":"%s"}\n' "$1" "$2" "$3" "$4"; }
{
  row 2026-11-08T10:00:00Z invoke_researcher 500 T
  row 2026-11-08T11:00:00Z invoke_spec_writer 100 T
  row 2026-11-08T12:00:00Z invoke_planner 1000 T
  row 2026-11-08T12:30:00Z spec_gate 0 T
  row 2026-11-08T12:40:00Z write_task_section 50 T
  row 2026-11-08T13:00:00Z invoke_validator 2000 T
  row 2026-11-08T13:10:00Z invoke_planner 777 U
  echo 'not json {'
} > "$TD/2026-11-08.jsonl"
OUT="$(TELEMETRY_DIR="$TD" "$REPORT" --task T --since 2026-11-08T11:00:00Z 2>"$TMP/err")"; RC=$?
eq "DoD4 report --since rc" "$RC" 0
eq "DoD4 report --since stdout" "$OUT" $'agent_time_ms: 3100\nzero_duration_rows: 1'
OUT="$(TELEMETRY_DIR="$TD" "$REPORT" --since 2026-11-08T11:00:00Z --task T 2>/dev/null)"
eq "DoD4 report args in either order" "$OUT" $'agent_time_ms: 3100\nzero_duration_rows: 1'
OUT="$(TELEMETRY_DIR="$TD" "$REPORT" --task T --since 2026-11-08T14:00:00Z 2>"$TMP/err")"; RC=$?
eq "DoD4 report no rows rc" "$RC" 3
eq "DoD4 report no rows stdout empty" "$OUT" ""
eq "DoD4 report no rows stderr" "$(cat "$TMP/err")" 'no telemetry rows for T since 2026-11-08T14:00:00Z'
TELEMETRY_DIR="$TD" "$REPORT" --since 2026-11-08T11:00:00Z >/dev/null 2>&1; eq "DoD4 report --since without --task -> 1" "$?" 1
TELEMETRY_DIR="$TD" "$REPORT" --task T --since 2026-11-08 >/dev/null 2>&1; eq "DoD4 report bad --since -> 1" "$?" 1
OUT="$(TELEMETRY_DIR="$TD" "$REPORT" --task T 2>/dev/null)"
eq "DoD4 report default CSV header" "$(printf '%s\n' "$OUT" | sed -n 1p)" 'task,rows,agent_ms,wall_ms,excluded'
want "DoD4 report default CSV row" "$(printf '%s\n' "$OUT" | sed -n 2p)" 'T,'

# --- Live install (WARN only, not counted) -------------------------------------
for a in planner builder; do
  t="$(readlink "$HOME/.claude/agents/$a.md" 2>/dev/null || true)"
  case "$t" in "$KIT"/*) echo "OK: ~/.claude/agents/$a.md -> kit" ;; *) echo "WARN: ~/.claude/agents/$a.md is not a symlink into the kit (run install.sh setup-global)" ;; esac
done

# --- DoD 5: suites -------------------------------------------------------------
if [ "${CHAIN_SKIP_SUITES:-0}" = 1 ]; then
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
    [ "$b" = test_chain_consolidation.sh ] && continue
    n=$((n + 1))
    envp=""; [ "$b" = test_thin_orchestrator.sh ] && envp="THIN_ORCH_SKIP_SUITES=1"; [ "$b" = test_pm_reviewer_single_pass.sh ] && envp="PMR_SKIP_SUITES=1"; [ "$b" = test_kit_telemetry_isolation.sh ] && envp="KTI_SKIP_SUITES=1"; [ "$b" = test_chain_targeted_tests.sh ] && envp="CTT_SKIP_SUITES=1"
    if ( cd "$REPO_ROOT" && env $envp bash "tests/$b" >/dev/null 2>&1 ); then pass "vault $b"; else fail "vault $b"; fi
  done
  [ "$n" -ge 1 ] || fail "vault suite glob matched nothing"
  for ra in "$REPO_ROOT"/tests/acceptance/*/run_all.sh; do
    [ -f "$ra" ] || continue
    d="$(basename "$(dirname "$ra")")"
    [ "$d" = Chain_Consolidation_Planner_Context_Pack ] && continue
    echo "acceptance: $d"
    aenv="ACC_SKIP_GATEWAY=1"
    if ( cd "$REPO_ROOT" && env $aenv bash "$ra" >/dev/null 2>&1 ); then pass "acceptance $d"; else fail "acceptance $d"; fi
  done
  echo "not in suite glob: tests/acceptance_commit_task.sh, tests/acceptance/ (task-scoped acceptance tests; every other tests/acceptance/*/run_all.sh runs above, this task's own folder excluded)"
fi

if [ "${CHAIN_SKIP_SUITES:-0}" = 1 ]; then
  echo "suites skipped: not a gateway pass"; exit 1
fi
if [ "$FAILS" -eq 0 ]; then echo "ALL GREEN"; exit 0; fi
echo "$FAILS check(s) failed"; exit 1

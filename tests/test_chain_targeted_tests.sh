#!/usr/bin/env bash
# test_chain_targeted_tests.sh - gateway for Chain_Targeted_Tests_Per_Stage.
# Pins the targeted-test wording in the kit's execute_task.md and agent files (with RED checks),
# the shared ACC_SKIP_GATEWAY acceptance env and aggregator wiring, and OpenCode freshness,
# then runs every kit suite and every vault test_*/smoke_* suite.
# CTT_SKIP_SUITES=1 skips the suite loops (the aggregators use it to avoid recursion).
set -uo pipefail
unset TITAN_SESSION_ID ACC_SKIP_GATEWAY

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
KIT="${KIT_ROOT:-$HOME/AI_Workflow/claude-agent-kit}"
EXEC="$KIT/project-template/.claude/commands/execute_task.md"
AG="$KIT/global/agents"
OC_AGENT="${CTT_OC_AGENT_DIR:-$HOME/.config/opencode/agent}"
OC_CMD="$(dirname "$OC_AGENT")/command"
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
nonzero() { if [ "$2" -ne 0 ]; then pass "$1"; else fail "$1 not detected"; fi; }

step() { awk -v a="## Step $2 " -v b="## Step $3 " 'index($0,a)==1{on=1} index($0,b)==1{on=0} on' "$1"; }
cnt() { printf '%s\n' "$1" | grep -cF -- "$2"; }

# --- DoD 1/2/3: execute_task.md ------------------------------------------------
check_exec() { # file -> count of missing/forbidden items
  local f="$1" bad=0 p s10 s11 s12 s13 rem
  s10="$(step "$f" 10 11)"; s11="$(step "$f" 11 12)"; s12="$(step "$f" 12 13)"; s13="$(step "$f" 13 14)"
  rem="$(awk '/^## Reminders/{on=1; next} /^## /{on=0} on' "$f")"
  for p in 'only targeted tests' 'in its skip mode' 'full kit or vault suite loops'; do
    [ "$(cnt "$s10" "$p")" -ge 3 ] || bad=$((bad + 1))
    [ "$(cnt "$s11" "$p")" -ge 1 ] || bad=$((bad + 1))
    [ "$(cnt "$s12" "$p")" -ge 1 ] || bad=$((bad + 1))
  done
  for p in 'nested full-gateway run' '`ACC_SKIP_GATEWAY=1`' 'the aggregator sets for every acceptance folder'; do
    printf '%s\n' "$s11" | grep -qF -- "$p" || bad=$((bad + 1))
  done
  printf '%s\n' "$s13" | grep -qF 'single full-suite run per task' || bad=$((bad + 1))
  printf '%s\n' "$rem" | grep -qF 'single full-suite run per task' || bad=$((bad + 1))
  if printf '%s\n%s\n%s\n' "$s10" "$s11" "$s12" | grep -qF 'full test suite'; then bad=$((bad + 1)); fi
  printf '%s\n' "$s13" | grep -qF 'run_gateway.sh' || bad=$((bad + 1))
  echo "$bad"
}
check_agent() { # file -> count of missing items
  local f="$1" bad=0 p
  for p in 'only targeted tests' 'skip mode' 'full kit or vault suite loops'; do
    grep -qF -- "$p" "$f" || bad=$((bad + 1))
  done
  echo "$bad"
}
check_tv() { # test-verifier file -> count of missing items
  local f="$1" bad p
  bad="$(check_agent "$f")"
  for p in 'nested full-gateway run' '`ACC_SKIP_GATEWAY=1`' 'the aggregator sets for every acceptance folder' \
    'Under `/execute_task`, do not add a nested full-gateway run'; do
    grep -qF -- "$p" "$f" || bad=$((bad + 1))
  done
  echo "$bad"
}
scope_bad() { # files -> count of new-wording lines lacking /execute_task
  grep -hE 'only targeted tests|nested full-gateway run' "$@" | grep -vF '/execute_task' | wc -l | tr -d ' '
}

eq "DoD1-3 execute_task.md wording" "$(check_exec "$EXEC")" 0
for a in builder backend-builder frontend-builder validator; do
  eq "DoD1 $a.md wording" "$(check_agent "$AG/$a.md")" 0
done
eq "DoD1/3 test-verifier.md wording" "$(check_tv "$AG/test-verifier.md")" 0
FILES5=("$AG/builder.md" "$AG/backend-builder.md" "$AG/frontend-builder.md" "$AG/test-verifier.md" "$AG/validator.md")
eq "DoD1 agent wording scoped to /execute_task" "$(scope_bad "${FILES5[@]}")" 0

grep -vF 'only targeted tests' "$EXEC" > "$TMP/r1.md"
nonzero "DoD1 RED exec 'only targeted tests' removed" "$(check_exec "$TMP/r1.md")"
sed 's/single full-suite run per task/full run/' "$EXEC" > "$TMP/r2.md"
nonzero "DoD2 RED exec single-run phrase removed" "$(check_exec "$TMP/r2.md")"
grep -vF 'nested full-gateway run' "$AG/test-verifier.md" > "$TMP/r3.md"
nonzero "DoD3 RED test-verifier nested rule removed" "$(check_tv "$TMP/r3.md")"
grep -vF 'only targeted tests' "$AG/builder.md" > "$TMP/r4.md"
nonzero "DoD1 RED builder sentence removed" "$(check_agent "$TMP/r4.md")"
sed 's#Under `/execute_task`, do not add a nested#Do not add a nested#' "$AG/test-verifier.md" > "$TMP/r5.md"
nonzero "DoD1 RED scope clause removed" "$(scope_bad "$TMP/r5.md")"

# --- kit pin guards ------------------------------------------------------------
[ "$(grep -cF 'If absent, proceed with standard typecheck/lint/test.' "$EXEC")" -ge 4 ] && pass "guard degradation sentence count" || fail "guard degradation sentence count"
S11="$(step "$EXEC" 11 12)"
want "guard step11 run_result: PASS" "$S11" 'run_result: PASS'
want "guard step11 no vault persist" "$S11" 'Do not persist anything into the vault'
if step "$EXEC" 6 13 | grep -qwE 'Edit|Write'; then fail "guard steps 6-12 no Edit/Write word"; else pass "guard steps 6-12 no Edit/Write word"; fi
if grep -qF '@' "$EXEC"; then fail "guard execute_task.md has no @"; else pass "guard execute_task.md has no @"; fi

# --- DoD 4: OpenCode freshness -------------------------------------------------
bash "$KIT/install.sh" check-opencode --path "$OC_AGENT" >/dev/null 2>&1 && pass "DoD4 check-opencode exit 0" || fail "DoD4 check-opencode exit 0"
for a in builder backend-builder frontend-builder test-verifier validator; do
  if grep -qF 'only targeted tests' "$OC_AGENT/$a.md" 2>/dev/null; then pass "DoD4 opencode $a fresh"; else fail "DoD4 opencode $a stale (run install.sh setup-opencode)"; fi
done
if grep -qF 'single full-suite run per task' "$OC_CMD/execute_task.md" 2>/dev/null; then pass "DoD4 opencode execute_task fresh"; else fail "DoD4 opencode execute_task stale (run install.sh setup-opencode)"; fi

# --- DoD 3: wiring, static -----------------------------------------------------
for t in test_chain_consolidation.sh test_pm_reviewer_single_pass.sh test_kit_telemetry_isolation.sh; do
  grep -qF '[ "$b" = test_chain_targeted_tests.sh ] && envp="CTT_SKIP_SUITES=1"' "$REPO_ROOT/tests/$t" && pass "DoD3 $t runs CTT in skip mode" || fail "DoD3 $t runs CTT in skip mode"
done
AENV="$(grep -F 'aenv=' "$REPO_ROOT/tests/test_chain_consolidation.sh")"
printf '%s\n' "$AENV" | grep -qE '(^|[" ])ACC_SKIP_GATEWAY=1' && pass "DoD3 aenv sets ACC_SKIP_GATEWAY=1" || fail "DoD3 aenv sets ACC_SKIP_GATEWAY=1"
deny "DoD3 aenv unconditional" "$AENV" '[ "$d" ='
PMR_RA="$REPO_ROOT/tests/acceptance/PM_Reviewer_Single_Pass_Findings/run_all.sh"
KTI_RA="$REPO_ROOT/tests/acceptance/Kit_Suites_Live_Telemetry_Isolation/run_all.sh"
for ra in "$PMR_RA" "$KTI_RA"; do
  grep -qF '${ACC_SKIP_GATEWAY:-0}' "$ra" && pass "DoD3 $(basename "$(dirname "$ra")") honours shared env" || fail "DoD3 $(basename "$(dirname "$ra")") honours shared env"
done
deny "DoD3 PMR skip line has no rc=1" "$(grep -F 'SKIP $n' "$PMR_RA")" 'rc=1'

# --- DoD 3: wiring, behavioral -------------------------------------------------
beh() { # label, run_all, stub name
  local d="$TMP/acc/$1" out rc
  mkdir -p "$d" "$TMP/kit_$1"
  cp "$2" "$d/run_all.sh"
  printf '#!/usr/bin/env bash\ntouch "%s/ran_%s"\n' "$TMP" "$1" > "$d/$3"
  out="$(cd "$d" && KIT_ROOT="$TMP/kit_$1" ACC_SKIP_GATEWAY=1 bash run_all.sh 2>&1)"; rc=$?
  [ ! -e "$TMP/ran_$1" ] && pass "DoD3 $1 stub gateway skipped" || fail "DoD3 $1 stub gateway ran under ACC_SKIP_GATEWAY=1"
  want "DoD3 $1 prints SKIP" "$out" 'SKIP'
  eq "DoD3 $1 skip does not force failure" "$rc" 0
}
beh PMR "$PMR_RA" test_dod3_gateway_green.sh
beh KTI "$KTI_RA" test_dod3_stub.sh

# --- DoD 5: suites -------------------------------------------------------------
if [ "${CTT_SKIP_SUITES:-0}" = 1 ]; then
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
    [ "$b" = test_chain_targeted_tests.sh ] && continue
    n=$((n + 1))
    if [ "$b" = test_chain_consolidation.sh ]; then
      out="$( cd "$REPO_ROOT" && CHAIN_SKIP_SUITES=1 bash "tests/$b" 2>&1 )"
      if ! printf '%s\n' "$out" | grep -q '^FAIL:' && printf '%s\n' "$out" | grep -qF 'suites skipped: not a gateway pass'; then
        pass "vault $b (skip mode)"; else fail "vault $b (skip mode)"; fi
      continue
    fi
    envp=""; [ "$b" = test_thin_orchestrator.sh ] && envp="THIN_ORCH_SKIP_SUITES=1"; [ "$b" = test_pm_reviewer_single_pass.sh ] && envp="PMR_SKIP_SUITES=1"; [ "$b" = test_kit_telemetry_isolation.sh ] && envp="KTI_SKIP_SUITES=1"
    if ( cd "$REPO_ROOT" && env $envp bash "tests/$b" >/dev/null 2>&1 ); then pass "vault $b"; else fail "vault $b"; fi
  done
  [ "$n" -ge 1 ] || fail "vault suite glob matched nothing"
  echo "not in suite glob: tests/acceptance/ (acceptance folders run test_chain_consolidation.sh in full, which runs this gateway)"
fi

if [ "$FAILS" -eq 0 ]; then echo "ALL GREEN"; exit 0; fi
echo "$FAILS check(s) failed"; exit 1

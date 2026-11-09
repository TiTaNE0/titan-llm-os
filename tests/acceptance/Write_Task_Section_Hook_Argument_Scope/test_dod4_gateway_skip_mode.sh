#!/usr/bin/env bash
# DoD 4 (fast half): the task's Verification Gateway passes its full block/allow matrix in skip mode,
# and every vault aggregator runs it in skip mode (no recursion).
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
OUT="$(cd "$VAULT" && HAS_SKIP_SUITES=1 bash tests/test_hook_argument_scope.sh 2>&1)"; rc=$?
[ "$rc" = 0 ] && printf '%s\n' "$OUT" | grep -qx 'ALL GREEN' && pass "gateway skip mode ALL GREEN" || fail "gateway skip mode rc=$rc: $(printf '%s\n' "$OUT" | grep FAIL)"
printf '%s\n' "$OUT" | grep -qx 'SKIP: suites' && pass "suites skipped under HAS_SKIP_SUITES=1" || fail "skip line missing"
for a in test_chain_consolidation.sh test_chain_targeted_tests.sh test_pm_reviewer_single_pass.sh test_kit_telemetry_isolation.sh test_macro_start_timestamp.sh; do
  grep -qF '[ "$b" = test_hook_argument_scope.sh ] && envp="HAS_SKIP_SUITES=1"' "$VAULT/tests/$a" \
    && pass "$a runs the gateway in skip mode" || fail "$a not wired"
done
finish

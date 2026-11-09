#!/usr/bin/env bash
# DoD 4: the full Verification Gateway (kit + vault suites) is green. Slow; run_all.sh skips it under ACC_SKIP_GATEWAY=1.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
OUT="$(cd "$VAULT" && bash tests/test_hook_argument_scope.sh 2>&1)"; rc=$?
[ "$rc" = 0 ] && printf '%s\n' "$OUT" | grep -qx 'ALL GREEN' && pass "full gateway ALL GREEN" || fail "gateway rc=$rc: $(printf '%s\n' "$OUT" | grep FAIL)"
printf '%s\n' "$OUT" | grep -qx 'SKIP: suites' && fail "suites were skipped in full mode" || pass "suites ran"
finish

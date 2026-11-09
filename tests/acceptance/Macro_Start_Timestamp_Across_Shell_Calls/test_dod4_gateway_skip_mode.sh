#!/usr/bin/env bash
# DoD 4 (targeted): the gateway in its skip mode is green, skips only the suite loops, and the four
# aggregators pass MST_SKIP_SUITES=1 to it so a full run never recurses.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
out="$(cd "$VAULT" && MST_SKIP_SUITES=1 bash tests/test_macro_start_timestamp.sh 2>&1)"; rc=$?
expect "gateway skip mode exit" 0 "$rc"
printf '%s\n' "$out" | grep -q '^FAIL' && fail "gateway skip mode has FAIL lines" || pass "no FAIL lines"
printf '%s\n' "$out" | grep -qx 'SKIP: suites' && pass "suites skipped" || fail "no SKIP: suites line"
printf '%s\n' "$out" | tail -n1 | grep -qx 'ALL GREEN' && pass "ALL GREEN" || fail "no ALL GREEN"
# The aggregator loop line, executed for b=test_macro_start_timestamp.sh, must yield the skip env.
for f in test_chain_consolidation.sh test_chain_targeted_tests.sh test_pm_reviewer_single_pass.sh test_kit_telemetry_isolation.sh; do
  line="$(grep -E '^[[:space:]]*envp="";' "$VAULT/tests/$f" | head -n1)"
  got="$(b=test_macro_start_timestamp.sh; envp=x; eval "$line"; echo "$envp")"
  expect "$f gives the MST gateway MST_SKIP_SUITES=1" MST_SKIP_SUITES=1 "$got"
done
finish

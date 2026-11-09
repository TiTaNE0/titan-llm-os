#!/usr/bin/env bash
# DoD 7: the six aggregators run the new gateway in its skip mode (no nested suite loop),
# and the gateway itself exists and honours SGH_SKIP_SUITES in its source.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
W='[ "$b" = test_spec_gate_hardening.sh ] && envp="SGH_SKIP_SUITES=1"'
for a in test_kit_telemetry_isolation.sh test_chain_consolidation.sh test_chain_targeted_tests.sh \
         test_pm_reviewer_single_pass.sh test_hook_argument_scope.sh test_macro_start_timestamp.sh; do
  grep -qF "$W" "$VAULT/tests/$a" && pass "$a wires SGH_SKIP_SUITES" || fail "$a lacks SGH skip wiring"
done
G="$VAULT/tests/test_spec_gate_hardening.sh"
[ -f "$G" ] && pass "gateway exists" || fail "gateway missing"
grep -q 'SGH_SKIP_SUITES' "$G" && pass "gateway reads SGH_SKIP_SUITES" || fail "gateway ignores SGH_SKIP_SUITES"
for k in THIN_ORCH_SKIP_SUITES=1 PMR_SKIP_SUITES=1 KTI_SKIP_SUITES=1 CTT_SKIP_SUITES=1 MST_SKIP_SUITES=1 HAS_SKIP_SUITES=1; do
  grep -q "envp=.*$k" "$G" && pass "gateway envp carries $k" || fail "gateway envp lacks $k"
done
grep -q 'CHAIN_SKIP_SUITES=1 bash' "$G" && pass "gateway runs chain_consolidation in skip mode" \
  || fail "gateway does not special-case test_chain_consolidation.sh"
finish

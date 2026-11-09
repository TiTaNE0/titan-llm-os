#!/usr/bin/env bash
# DoD 4: the new gateway is wired into the vault aggregators without recursion:
# KTI_SKIP_SUITES=1 runs only the override checks and exits 0, and both aggregators pass it.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
( cd "$VAULT" && KTI_SKIP_SUITES=1 bash tests/test_kit_telemetry_isolation.sh >"$TMP/out" 2>&1 ); rc=$?
expect "skip mode exit code" 0 "$rc"
grep -qx 'SKIP: suites' "$TMP/out" && pass "skip mode prints SKIP: suites" || fail "skip mode line missing"
grep -q '^FAIL' "$TMP/out" && fail "skip mode FAIL lines: $(grep '^FAIL' "$TMP/out" | tr '\n' ';')" || pass "skip mode no FAIL lines"
grep -q '^PASS: kit \|^PASS: vault ' "$TMP/out" && fail "skip mode still ran suites" || pass "skip mode ran no suites"
for agg in test_chain_consolidation.sh test_pm_reviewer_single_pass.sh; do
  grep -qF '[ "$b" = test_kit_telemetry_isolation.sh ] && envp="KTI_SKIP_SUITES=1"' "$VAULT/tests/$agg" \
    && pass "$agg runs the gateway in skip mode" || fail "$agg does not pass KTI_SKIP_SUITES=1"
done
grep -qF '[ "$b" = test_pm_reviewer_single_pass.sh ] && envp="PMR_SKIP_SUITES=1"' "$VAULT/tests/test_chain_consolidation.sh" \
  && pass "chain keeps PMR skip clause" || fail "chain lost PMR skip clause"
grep -qF '[ "$b" = test_kit_telemetry_isolation.sh ] && continue' "$GATEWAY" && pass "gateway skips itself" || fail "gateway does not skip itself"
finish

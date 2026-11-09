#!/usr/bin/env bash
# DoD 3: the Verification Gateway, run exactly as the task states, is green
# (contract pins plus every kit suite and every vault test_*/smoke_* suite).
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
( cd "$VAULT" && bash tests/test_pm_reviewer_single_pass.sh >"$TMP/gw" 2>&1 ); rc=$?
expect "bash tests/test_pm_reviewer_single_pass.sh exit code" 0 "$rc"
grep -qx 'ALL GREEN' "$TMP/gw" && pass "gateway ALL GREEN" || fail "gateway not green: $(grep '^FAIL' "$TMP/gw" | tr '\n' ';')"
grep -q '^PASS: kit ' "$TMP/gw" && pass "gateway ran kit suites" || fail "gateway ran no kit suite"
grep -q '^PASS: vault ' "$TMP/gw" && pass "gateway ran vault suites" || fail "gateway ran no vault suite"
grep -qx 'SKIP: suites' "$TMP/gw" && fail "gateway skipped suites" || pass "gateway did not skip suites"
finish

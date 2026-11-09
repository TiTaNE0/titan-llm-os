#!/usr/bin/env bash
# DoD 5 (cheap half): the gateway names its skip env in its header (agents find it there, per
# the targeted-test sentence), and in skip mode it runs every pin and exits 0 without suites.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
has "gateway header names CTT_SKIP_SUITES=1" "$(sed -n '2,10p' "$GATEWAY")" 'CTT_SKIP_SUITES=1'
( cd "$VAULT" && env -u ACC_SKIP_GATEWAY CTT_SKIP_SUITES=1 bash tests/test_chain_targeted_tests.sh >"$TMP/out" 2>&1 ); rc=$?
expect "skip-mode gateway exit code" 0 "$rc"
grep -qx 'SKIP: suites' "$TMP/out" && pass "prints SKIP: suites" || fail "no SKIP: suites line"
grep -qx 'ALL GREEN' "$TMP/out" && pass "prints ALL GREEN" || fail "no ALL GREEN line"
grep -q '^FAIL:' "$TMP/out" && fail "FAIL lines: $(grep '^FAIL:' "$TMP/out" | tr '\n' ';')" || pass "no FAIL: line"
grep -qE '^PASS: (kit|vault) ' "$TMP/out" && fail "skip mode still ran suites" || pass "skip mode ran no suites"
finish

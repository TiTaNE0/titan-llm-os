#!/usr/bin/env bash
# DoD 4 (full): the gateway with no skip env runs every kit and vault suite green.
# Expensive; run_all.sh skips it under ACC_SKIP_GATEWAY=1 (the chain aggregator sets it).
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
out="$(cd "$VAULT" && env -u MST_SKIP_SUITES bash "$GATEWAY" 2>&1)"; rc=$?
expect "full gateway exit" 0 "$rc"
printf '%s\n' "$out" | grep '^FAIL' >&2 && fail "full gateway has FAIL lines" || pass "no FAIL lines"
printf '%s\n' "$out" | grep -q '^PASS: kit ' && pass "kit suites ran" || fail "kit suites did not run"
printf '%s\n' "$out" | grep -q '^PASS: vault ' && pass "vault suites ran" || fail "vault suites did not run"
finish

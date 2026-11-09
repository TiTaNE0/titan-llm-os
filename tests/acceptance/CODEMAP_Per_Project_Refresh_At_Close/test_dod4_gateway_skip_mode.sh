#!/usr/bin/env bash
# DoD4: the task's Verification Gateway, in its skip mode only (never the full suites from here).
. "$(dirname "$0")/_lib.sh"
O="$(cd "$VAULT" && CMR_SKIP_SUITES=1 bash tests/test_codemap_refresh.sh 2>&1)"; RC=$?
eq "gateway (CMR_SKIP_SUITES=1) exit 0" "$RC" 0
printf '%s' "$O" | grep -qx 'suites skipped: CMR_SKIP_SUITES=1' && pass "skip banner" || fail "skip banner"
printf '%s' "$O" | grep -q '^FAIL' && { fail "gateway FAIL lines"; printf '%s\n' "$O" | grep '^FAIL' >&2; } || pass "no FAIL lines"
done_

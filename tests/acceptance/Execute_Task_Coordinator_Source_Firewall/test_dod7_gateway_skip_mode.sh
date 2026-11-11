#!/usr/bin/env bash
# DoD7: the task's Verification Gateway, in its skip mode only (the full kit/vault suites run once
# in the gateway step, never from here). run_all.sh skips this file under ACC_SKIP_GATEWAY=1.
. "$(dirname "$0")/_lib.sh"
O="$(cd "$VAULT" && ECF_SKIP_SUITES=1 bash tests/test_execute_task_coordinator_firewall.sh 2>&1)"; RC=$?
eq "gateway (ECF_SKIP_SUITES=1) exit 0" "$RC" 0
printf '%s\n' "$O" | grep -qx 'suites skipped: ECF_SKIP_SUITES=1' && pass "skip banner" || fail "skip banner"
printf '%s\n' "$O" | grep -q '^FAIL' && { fail "gateway FAIL lines"; printf '%s\n' "$O" | grep '^FAIL' >&2; } || pass "no FAIL lines"
done_

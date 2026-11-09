#!/usr/bin/env bash
# Runs every Kit_Suites_Live_Telemetry_Isolation acceptance test, then proves no test wrote
# into the real vault: no acc_kti_ sentinel in live telemetry, and the files under test are
# byte-identical. The live log's row count is never asserted (other sessions write it).
# ACC_SKIP_GATEWAY=1 (shared) or KTI_ACC_SKIP_GATEWAY=1 skips the full-gateway test; the exit code then reflects only the
# remaining checks. The chain aggregator sets it, and also runs the gateway with
# KTI_SKIP_SUITES=1, so a chain pass runs no all-suite mirror leak check: run
# tests/test_kit_telemetry_isolation.sh directly for that.
set -uo pipefail
unset TITAN_SESSION_ID TELEMETRY_DIR
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
VAULT="$(cd "$HERE/../../.." && pwd -P)"
KIT="${KIT_ROOT:-$HOME/AI_Workflow/claude-agent-kit}"
REAL="$VAULT/04_Logs/Telemetry"
snap() {
  shasum "$VAULT/.scripts/emit_telemetry.sh" "$VAULT/.scripts/telemetry_start.sh" \
    "$VAULT/tests/test_kit_telemetry_isolation.sh" "$VAULT/tests/test_chain_consolidation.sh" \
    "$VAULT/tests/test_pm_reviewer_single_pass.sh" "$KIT"/tests/test_*.sh 2>/dev/null | shasum
}
before="$(snap)"
rc=0
for t in "$HERE"/test_*.sh; do
  n="$(basename "$t")"
  case "$n" in test_dod3_*)
    if [ "${ACC_SKIP_GATEWAY:-0}" = 1 ] || [ "${KTI_ACC_SKIP_GATEWAY:-0}" = 1 ]; then echo "SKIP $n (gateway skip env)"; continue; fi ;;
  esac
  if bash "$t" >/dev/null 2>"$HERE/.last_err"; then echo "PASS $n"
  else echo "FAIL $n"; cat "$HERE/.last_err"; rc=1; fi
done
rm -f "$HERE/.last_err"
if grep -lqF 'acc_kti_' "$REAL"/*.jsonl "$REAL/.write_failures.log" 2>/dev/null \
   || ls -A "$REAL/.timers" 2>/dev/null | grep -q 'acc_kti_'; then
  echo "FAIL acceptance sentinel found in real telemetry"; rc=1
else echo "PASS real telemetry has no acceptance sentinel"; fi
[ "$(snap)" = "$before" ] && echo "PASS vault scripts / gateways / kit suites untouched" || { echo "FAIL real vault or kit file changed"; rc=1; }
exit $rc

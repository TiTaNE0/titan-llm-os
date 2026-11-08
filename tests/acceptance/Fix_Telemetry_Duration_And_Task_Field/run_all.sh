#!/usr/bin/env bash
# Runs every acceptance test for Fix_Telemetry_Duration_And_Task_Field, then
# DoD 4: proves none of them touched the real telemetry file or timers.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
VAULT="$(cd "$HERE/../../.." && pwd -P)"
REAL="$VAULT/04_Logs/Telemetry"
rc=0
for t in "$HERE"/test_*.sh; do
  if bash "$t" >/dev/null 2>"$HERE/.last_err"; then echo "PASS $(basename "$t")"
  else echo "FAIL $(basename "$t")"; cat "$HERE/.last_err"; rc=1; fi
done
rm -f "$HERE/.last_err"
# Sentinels (acc_tdtf_, plus fixture task names) must never appear in real files.
if grep -lq 'acc_tdtf_\|"task":"Alpha"\|"task":"Beta Task"\|"task":"E2E"' "$REAL"/*.jsonl "$REAL/.write_failures.log" 2>/dev/null; then
  echo "FAIL DoD4: acceptance sentinel found in real telemetry"; rc=1
else echo "PASS DoD4 real telemetry untouched"; fi
if ls "$REAL/.timers" 2>/dev/null | grep -q 'acc_tdtf_\|E2E\|Wiki_Task'; then
  echo "FAIL DoD4: acceptance timer left in real .timers"; rc=1
else echo "PASS DoD4 no real timers"; fi
exit $rc

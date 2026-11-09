#!/usr/bin/env bash
# Acceptance suite for Telemetry_Task_Report_CSV_Quoting.
set -uo pipefail
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
rc=0
for t in "$D"/test_*.sh; do
  echo "== $(basename "$t")"
  bash "$t" || rc=1
done
[ "$rc" -eq 0 ] && echo "ALL PASS" || echo "SOME FAILED"
exit "$rc"

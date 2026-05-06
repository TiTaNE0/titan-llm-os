#!/usr/bin/env bash
# metrics_aggregate.sh — aggregate Telemetry JSONL into a CSV report.
#
# Usage:
#   metrics_aggregate.sh [day|week|month]
#
# Default period: week (rolling 7-day window ending today).
# Output: 04_Logs/Telemetry/reports/<period>_<YYYY-MM-DD>.csv + console table.
# Requires: jq, python3.

set -uo pipefail

PERIOD="${1:-week}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

START_MS=$(python3 -c 'import time; print(int(time.time()*1000))')

TODAY="$(date -u +"%Y-%m-%d")"

case "$PERIOD" in
  day)
    WINDOW_START="$TODAY"
    ;;
  week)
    WINDOW_START="$(python3 -c 'import datetime; print((datetime.date.today() - datetime.timedelta(days=6)).isoformat())')"
    ;;
  month)
    WINDOW_START="$(python3 -c 'import datetime; print((datetime.date.today() - datetime.timedelta(days=29)).isoformat())')"
    ;;
  *)
    echo "ERROR: period must be one of: day, week, month (got: $PERIOD)" >&2
    "$SCRIPT_DIR/emit_telemetry.sh" metrics error 0 E2 "${PERSONA:-unknown}"
    exit 1
    ;;
esac

REPORT_DIR="$VAULT_DIR/04_Logs/Telemetry/reports"
REPORT="$REPORT_DIR/${PERIOD}_${TODAY}.csv"
mkdir -p "$REPORT_DIR"

TELEMETRY=$(cat "$VAULT_DIR/04_Logs/Telemetry/"*.jsonl 2>/dev/null | grep -v '^$' || true)

{
  echo "macro,count,success,errors,success_rate,avg_ms"
  if [ -n "$TELEMETRY" ]; then
    echo "$TELEMETRY" | jq -s -r --arg start "$WINDOW_START" --arg end "$TODAY" '
      [.[] | select(.ts[0:10] >= $start and .ts[0:10] <= $end)]
      | group_by(.macro)
      | map({
          macro: .[0].macro,
          count: length,
          success: ([.[] | select(.status=="success")] | length),
          errors:  ([.[] | select(.status=="error")] | length),
          avg_ms:  ((map(.duration_ms) | add) / length | floor)
        })
      | sort_by(-.count)
      | .[]
      | "\(.macro),\(.count),\(.success),\(.errors),\((.success/.count*100)|floor)%,\(.avg_ms)"
    '
  fi
} > "$REPORT"

END_MS=$(python3 -c 'import time; print(int(time.time()*1000))')
DURATION=$((END_MS - START_MS))

echo ""
echo "=== /metrics $PERIOD (window: $WINDOW_START → $TODAY) ==="
if [ "$(wc -l < "$REPORT")" -le 1 ]; then
  echo "(no telemetry data found in window)"
else
  column -t -s, "$REPORT"
fi
echo ""
echo "Report:   $REPORT"
echo "Duration: ${DURATION}ms"

"$SCRIPT_DIR/emit_telemetry.sh" metrics success "$DURATION" null "${PERSONA:-Executioner}"

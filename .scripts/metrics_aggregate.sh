#!/usr/bin/env bash
# metrics_aggregate.sh — aggregate Telemetry JSONL into a CSV report.
#
# Usage:
#   metrics_aggregate.sh [day|week|month] [--breakdown error_class]
#
# Default period: week (rolling 7-day window ending today).
# Output: 04_Logs/Telemetry/reports/<period>_<YYYY-MM-DD>.csv + console table.
#         --breakdown mode: <period>_<YYYY-MM-DD>_by_error_class.csv (separate file).
# Requires: jq, python3.
#
# Env overrides (for tests):
#   TELEMETRY_DIR   override the telemetry directory (default: <vault>/04_Logs/Telemetry)

set -uo pipefail

PERIOD=""
BREAKDOWN=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --breakdown)
      BREAKDOWN="$2"
      shift 2
      ;;
    day|week|month)
      PERIOD="$1"
      shift
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      echo "Usage: $(basename "$0") [day|week|month] [--breakdown error_class]" >&2
      exit 1
      ;;
  esac
done

PERIOD="${PERIOD:-week}"
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

# TELEMETRY_DIR env override (for tests; default: <vault>/04_Logs/Telemetry)
TELEMETRY_DIR="${TELEMETRY_DIR:-$VAULT_DIR/04_Logs/Telemetry}"
REPORT_DIR="$TELEMETRY_DIR/reports"
REPORT="$REPORT_DIR/${PERIOD}_${TODAY}.csv"
mkdir -p "$REPORT_DIR"

TELEMETRY=$(cat "$TELEMETRY_DIR/"*.jsonl 2>/dev/null | grep -v '^$' || true)

if [[ -n "$BREAKDOWN" ]]; then
  # Breakdown mode: only process known breakdown dimensions.
  if [[ "$BREAKDOWN" != "error_class" ]]; then
    echo "ERROR: unknown breakdown dimension '$BREAKDOWN' (allowed: error_class)" >&2
    exit 1
  fi

  BREAKDOWN_REPORT="$REPORT_DIR/${PERIOD}_${TODAY}_by_error_class.csv"

  {
    echo "macro,error_class,count"
    if [ -n "$TELEMETRY" ]; then
      echo "$TELEMETRY" | jq -s -r --arg start "$WINDOW_START" --arg end "$TODAY" '
        [.[] | select(.ts[0:10] >= $start and .ts[0:10] <= $end and .status=="error")]
        | group_by([.macro, (.error_class // "null")])
        | map({
            macro: .[0].macro,
            error_class: (.[0].error_class // "null"),
            count: length
          })
        | sort_by(-.count)
        | .[]
        | "\(.macro),\(.error_class),\(.count)"
      '
    fi
  } > "$BREAKDOWN_REPORT"

  END_MS=$(python3 -c 'import time; print(int(time.time()*1000))')
  DURATION=$((END_MS - START_MS))

  echo ""
  echo "=== /metrics $PERIOD --breakdown error_class (window: $WINDOW_START → $TODAY) ==="
  if [ "$(wc -l < "$BREAKDOWN_REPORT")" -le 1 ]; then
    echo "(no error telemetry data found in window)"
  else
    column -t -s, "$BREAKDOWN_REPORT"
  fi
  echo ""
  echo "Breakdown report: $BREAKDOWN_REPORT"
  echo "Duration: ${DURATION}ms"

  "$SCRIPT_DIR/emit_telemetry.sh" metrics success "$DURATION" null "${PERSONA:-Executioner}"
  exit 0
fi

# Default mode: aggregate by macro.
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

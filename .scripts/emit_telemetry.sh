#!/usr/bin/env bash
# emit_telemetry.sh — append a telemetry record to the current month's JSONL file.
#
# Usage:
#   emit_telemetry.sh <macro> <status> [duration_ms] [error_class] [persona]
#
# Args:
#   macro         Required. e.g. "metrics", "close_task"
#   status        Required. "success" | "error"
#   duration_ms   Optional. Integer milliseconds. Default: 0
#   error_class   Optional. "E1".."E5" or "null". Default: null
#   persona       Optional. "Executioner" | "Architect" | etc. Default: unknown
#
# Output: appends one JSONL line to 04_Logs/Telemetry/<YYYY-MM>.jsonl
# Exit: always 0 (telemetry is best-effort, must never block a macro).

set -uo pipefail

MACRO="${1:-unknown}"
STATUS="${2:-unknown}"
DURATION_MS="${3:-0}"
ERROR_CLASS="${4:-null}"
PERSONA="${5:-unknown}"

# Resolve vault root (script lives in <vault>/.scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
MONTH="$(date -u +"%Y-%m")"
TELEMETRY_DIR="$VAULT_DIR/04_Logs/Telemetry"
TELEMETRY_FILE="$TELEMETRY_DIR/${MONTH}.jsonl"

mkdir -p "$TELEMETRY_DIR"

# JSON-encode error_class (string or null)
if [ "$ERROR_CLASS" = "null" ] || [ -z "$ERROR_CLASS" ]; then
  ERR_FIELD="null"
else
  ERR_FIELD="\"$ERROR_CLASS\""
fi

printf '{"ts":"%s","macro":"%s","status":"%s","duration_ms":%s,"error_class":%s,"persona":"%s"}\n' \
  "$TS" "$MACRO" "$STATUS" "$DURATION_MS" "$ERR_FIELD" "$PERSONA" \
  >> "$TELEMETRY_FILE" 2>/dev/null || true

exit 0

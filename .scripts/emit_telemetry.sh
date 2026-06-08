#!/usr/bin/env bash
# emit_telemetry.sh — append a telemetry record to the current month's JSONL file.
#
# Usage:
#   emit_telemetry.sh <macro> <status> [duration_ms] [error_class] [persona] [task]
#
# Args:
#   macro         Required. e.g. "metrics", "close_task"
#   status        Required. "success" | "error"
#   duration_ms   Optional. Integer milliseconds. Default: 0
#   error_class   Optional. "E1".."E5" or "null". Default: null
#   persona       Optional. "Executioner" | "Architect" | etc. Default: unknown
#   task          Optional. Task identity for per-task attestation. Default: null
#
# Output: appends one JSONL line to 04_Logs/Telemetry/<YYYY-MM>.jsonl
# Write failures: recorded to 04_Logs/Telemetry/.write_failures.log (best-effort
#   sentinel) so a dropped record is observable. Exit stays 0 — telemetry must
#   never block a macro (some callers, e.g. metrics_aggregate.sh, invoke bare).

set -uo pipefail

MACRO="${1:-unknown}"
STATUS="${2:-unknown}"
DURATION_MS="${3:-0}"
ERROR_CLASS="${4:-null}"
PERSONA="${5:-unknown}"
TASK="${6:-null}"

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

# JSON-encode task (string or null)
if [ "$TASK" = "null" ] || [ -z "$TASK" ]; then
  TASK_FIELD="null"
else
  TASK_FIELD="\"$TASK\""
fi

if printf '{"ts":"%s","macro":"%s","status":"%s","duration_ms":%s,"error_class":%s,"persona":"%s","task":%s}\n' \
  "$TS" "$MACRO" "$STATUS" "$DURATION_MS" "$ERR_FIELD" "$PERSONA" "$TASK_FIELD" \
  >> "$TELEMETRY_FILE" 2>/dev/null; then
  exit 0
fi

# Write failed — record a best-effort sentinel so the drop is observable, exit 0.
printf '%s\t%s\t%s\twrite_fail\n' "$TS" "$MACRO" "$PERSONA" \
  >> "$TELEMETRY_DIR/.write_failures.log" 2>/dev/null || true
exit 0

#!/usr/bin/env bash
# emit_telemetry.sh — append a telemetry record to the current month's JSONL file.
#
# Usage:
#   emit_telemetry.sh <macro> <status> [duration_ms] [error_class] [persona] [task]
#
# Args:
#   macro         Required. e.g. "metrics", "close_task"
#   status        Required. "success" | "error"
#   duration_ms   Optional. Integer milliseconds, or "auto" (now minus the start
#                 written by telemetry_start.sh for the same macro+task; the timer
#                 is consumed). Values outside [0, 86400000] are clamped to 0 and
#                 logged as clamp-duration. Default: 0
#   error_class   Optional. "E1".."E5" or "null". Default: null
#   persona       Optional. "Executioner" | "Architect" | etc. Default: unknown
#   task          Optional. Task identity for per-task attestation. A [[...]]
#                 wrapper is stripped. Default: null
#
# Output: appends one JSONL line to 04_Logs/Telemetry/<YYYY-MM>.jsonl
# Write failures: recorded to 04_Logs/Telemetry/.write_failures.log (best-effort
#   sentinel) so a dropped record is observable. Exit stays 0 — telemetry must
#   never block a macro (some callers, e.g. metrics_aggregate.sh, invoke bare).
# Env: TELEMETRY_DIR overrides the telemetry directory (default: <vault>/04_Logs/Telemetry); tests use it to isolate rows.

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
TELEMETRY_DIR="${TELEMETRY_DIR:-$VAULT_DIR/04_Logs/Telemetry}"
TELEMETRY_FILE="$TELEMETRY_DIR/${MONTH}.jsonl"

mkdir -p "$TELEMETRY_DIR"

# Best-effort diagnostic line; never blocks, never exits.
note() {
  printf '%s\tnote\t%s\n' "$TS" "$1" \
    >> "$TELEMETRY_DIR/.write_failures.log" 2>/dev/null || true
}

# Reject malformed calls — never write corrupt JSONL (see 2026-06.jsonl:556).
# Exit stays 0: telemetry must never block a macro.
reject() {
  printf '%s\treject\t%s\n' "$TS" "$1" \
    >> "$TELEMETRY_DIR/.write_failures.log" 2>/dev/null || true
  exit 0
}
[ "$#" -ge 2 ] && [ "$#" -le 6 ] || reject "bad-arg-count:$#"
for a in "$@"; do case "$a" in --*) reject "flag-style-arg:$a";; esac; done

# Task: strip a [[...]] wrapper first so [[Foo]] and Foo share a timer key.
case "$TASK" in '[['*']]') TASK="${TASK#\[\[}"; TASK="${TASK%\]\]}";; esac
[ "$TASK" = "null" ] && TASK=""

# Timer key — must stay identical to telemetry_start.sh.
key() {
  local k
  k="$(printf '%s' "$1" | LC_ALL=C tr -c 'A-Za-z0-9_.-' '_')"
  [ -n "$k" ] || k="_"
  printf '%s' "$k"
}

if [ "$DURATION_MS" = "auto" ]; then
  TIMER_FILE="$TELEMETRY_DIR/.timers/$(key "$MACRO")__$(key "$TASK").tmp"
  START_MS="$(head -n 1 "$TIMER_FILE" 2>/dev/null || true)"
  rm -f "$TIMER_FILE" 2>/dev/null || true
  case "$START_MS" in
    ''|*[!0-9]*) note "missing-timer:$TIMER_FILE"; DURATION_MS=0 ;;
    *)
      if [ "${#START_MS}" -gt 14 ]; then
        note "missing-timer:$TIMER_FILE"; DURATION_MS=0
      else
        DURATION_MS="$(( $(date +%s) * 1000 - 10#$START_MS ))"
      fi ;;
  esac
fi

# Duration: accept optional leading '-', clamp to [0, 86400000] without
# arithmetic on unbounded digit strings.
RAW_DURATION="$DURATION_MS"
DIGITS="${DURATION_MS#-}"
case "$DIGITS" in ''|*[!0-9]*) reject "non-numeric-duration:$DURATION_MS";; esac
DIGITS="${DIGITS#"${DIGITS%%[!0]*}"}"
[ -n "$DIGITS" ] || DIGITS=0
if [ "$DURATION_MS" != "${DURATION_MS#-}" ] && [ "$DIGITS" != 0 ]; then
  note "clamp-duration:$RAW_DURATION"; DURATION_MS=0
elif [ "${#DIGITS}" -gt 8 ] || [ "$DIGITS" -gt 86400000 ]; then
  note "clamp-duration:$RAW_DURATION"; DURATION_MS=0
else
  DURATION_MS="$DIGITS"
fi

# JSON-encode error_class (string or null)
if [ "$ERROR_CLASS" = "null" ] || [ -z "$ERROR_CLASS" ]; then
  ERR_FIELD="null"
else
  ERR_FIELD="\"$ERROR_CLASS\""
fi

# JSON-encode task (string or null); control chars would corrupt the line.
case "$TASK" in
  '') TASK_FIELD="null" ;;
  *[[:cntrl:]]*) note "invalid-task"; TASK_FIELD="null" ;;
  *)
    TASK="${TASK//\\/\\\\}"
    TASK="${TASK//\"/\\\"}"
    TASK_FIELD="\"$TASK\""
    ;;
esac

if printf '{"ts":"%s","macro":"%s","status":"%s","duration_ms":%s,"error_class":%s,"persona":"%s","task":%s}\n' \
  "$TS" "$MACRO" "$STATUS" "$DURATION_MS" "$ERR_FIELD" "$PERSONA" "$TASK_FIELD" \
  >> "$TELEMETRY_FILE" 2>/dev/null; then
  exit 0
fi

# Write failed — record a best-effort sentinel so the drop is observable, exit 0.
printf '%s\t%s\t%s\twrite_fail\n' "$TS" "$MACRO" "$PERSONA" \
  >> "$TELEMETRY_DIR/.write_failures.log" 2>/dev/null || true
exit 0

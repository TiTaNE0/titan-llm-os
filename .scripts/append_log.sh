#!/usr/bin/env bash
# append_log.sh
#
# Appends a single-line entry to 04_Logs/<date>.md, auto-creating the file.
# Backs /close_task macro step 6 and any macro that wants a dated log line.
#
# Contract: Tool_Registry.md § Subagent Engine Atoms § append_log
# Idempotent: No (always appends - explicit in contract).
# Persona Gate: Any (no enforcement block; SOURCE_PERSONA is passed through to
#   telemetry as an unverified caller-claim). This is the only close-task atom
#   that is not Executioner-gated - logging is an operational side-effect that
#   Synthesizer/Architect macros may legitimately want.
# Telemetry: MANDATORY per Composition Rule 3.
#
# Exit codes:
#   0  success
#   1  missing required arg (E1)
#   2  log write failure (E2)
#   3  malformed --date (E3)

set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") --date <YYYY-MM-DD> --entry <text> --source-persona <name>

Required:
  --date <YYYY-MM-DD>        Log date (target file is 04_Logs/<date>.md)
  --entry <text>             Single-line entry to append
  --source-persona <name>    Caller-claimed persona (recorded in telemetry; not verified)

Exit codes:
  0  success
  1  missing required arg (E1)
  2  log write failure (E2)
  3  malformed --date (E3)
EOF
}

DATE=""
ENTRY=""
SOURCE_PERSONA=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --date)           DATE="$2"; shift 2 ;;
    --entry)          ENTRY="$2"; shift 2 ;;
    --source-persona) SOURCE_PERSONA="$2"; shift 2 ;;
    -h|--help)        usage; exit 0 ;;
    *)                echo "Unknown arg: $1" >&2; usage >&2; exit 1 ;;
  esac
done

START_TS_MS=$(($(date +%s) * 1000))
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

emit_err() {
  local end=$(($(date +%s) * 1000))
  "$SCRIPT_DIR/emit_telemetry.sh" append_log error $((end - START_TS_MS)) "$1" "${SOURCE_PERSONA:-unknown}" 2>/dev/null || true
}

if [[ -z "$DATE" || -z "$ENTRY" || -z "$SOURCE_PERSONA" ]]; then
  echo "E1: missing required arg" >&2; usage >&2; emit_err E1; exit 1
fi

if [[ ! "$DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "E3: malformed --date '$DATE' (expected YYYY-MM-DD)" >&2; emit_err E3; exit 3
fi

# Gate is "Any" - no enforcement block.

VAULT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$VAULT_DIR/04_Logs"
LOG_FILE="$LOG_DIR/${DATE}.md"

if ! mkdir -p "$LOG_DIR"; then
  echo "E2: cannot create log directory: $LOG_DIR" >&2; emit_err E2; exit 2
fi

if ! printf '%s\n' "$ENTRY" >> "$LOG_FILE"; then
  echo "E2: failed to append to $LOG_FILE" >&2; emit_err E2; exit 2
fi

END_TS_MS=$(($(date +%s) * 1000))
"$SCRIPT_DIR/emit_telemetry.sh" append_log success $((END_TS_MS - START_TS_MS)) null "$SOURCE_PERSONA" 2>/dev/null || true

exit 0

#!/usr/bin/env bash
# set_task_status.sh
#
# Atomic YAML status field flip for task .md files (frontmatter-only mutation).
# Persona-origin-guarded via persona_check.sh. Body markdown is never touched -
# spec text that mentions `status: in_progress` in prose stays intact.
#
# Contract: Tool_Registry.md § Subagent Engine Atoms § set_task_status
# Idempotent: Yes - re-run with same --from-status after success yields E3
#             (current status no longer matches from). Same observable end-state,
#             but loud rather than silent.
# Persona Gate: Executioner (enforced via persona_check.sh).
# Telemetry: MANDATORY per Composition Rule 3.
#
# Exit codes:
#   0  success
#   1  task_path missing OR mv failure (E1)
#   3  current YAML status != from_status, OR invalid status enum, OR missing args (E3)
#   4  source_persona != Executioner OR live persona != Executioner (E4)

set -euo pipefail

ALLOWED_STATUSES="todo in_progress done blocked delegated"

usage() {
  cat <<EOF
Usage: $(basename "$0") --task-path <abs> --from-status <enum> --to-status <enum> --source-persona <name>

Required:
  --task-path <abs>          Absolute path to task .md
  --from-status <enum>       Current YAML status (must match for transition to fire)
  --to-status <enum>         Target YAML status
  --source-persona <name>    Caller-claimed persona (must be Executioner)

Allowed status values:
  $ALLOWED_STATUSES

Exit codes:
  0  success
  1  task_path missing OR mv failure (E1)
  3  current status != from_status, OR invalid enum, OR missing args (E3)
  4  persona mismatch or wrong persona (E4)
EOF
}

TASK_PATH=""
FROM_STATUS=""
TO_STATUS=""
SOURCE_PERSONA=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --task-path)      TASK_PATH="$2"; shift 2 ;;
    --from-status)    FROM_STATUS="$2"; shift 2 ;;
    --to-status)      TO_STATUS="$2"; shift 2 ;;
    --source-persona) SOURCE_PERSONA="$2"; shift 2 ;;
    -h|--help)        usage; exit 0 ;;
    *)                echo "Unknown arg: $1" >&2; usage >&2; exit 3 ;;
  esac
done

START_TS_MS=$(($(date +%s) * 1000))
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

emit_err() {
  local end=$(($(date +%s) * 1000))
  "$SCRIPT_DIR/emit_telemetry.sh" set_task_status error $((end - START_TS_MS)) "$1" "${SOURCE_PERSONA:-unknown}" 2>/dev/null || true
}

if [[ -z "$TASK_PATH" || -z "$FROM_STATUS" || -z "$TO_STATUS" || -z "$SOURCE_PERSONA" ]]; then
  echo "E3: missing required arg" >&2; usage >&2; emit_err E3; exit 3
fi

validate_status() {
  local s="$1"
  for allowed in $ALLOWED_STATUSES; do
    [[ "$s" == "$allowed" ]] && return 0
  done
  return 1
}

if ! validate_status "$FROM_STATUS"; then
  echo "E3: invalid --from-status '$FROM_STATUS' (allowed: $ALLOWED_STATUSES)" >&2; emit_err E3; exit 3
fi
if ! validate_status "$TO_STATUS"; then
  echo "E3: invalid --to-status '$TO_STATUS' (allowed: $ALLOWED_STATUSES)" >&2; emit_err E3; exit 3
fi

if [[ ! -f "$TASK_PATH" ]]; then
  echo "E1: task file not found: $TASK_PATH" >&2; emit_err E1; exit 1
fi

# ============================================================================
# ENFORCEMENT BLOCK (persona-origin guard, Composition Rule 5)
# ============================================================================

if [[ "$SOURCE_PERSONA" != "Executioner" ]]; then
  echo "E4: source_persona must be 'Executioner'; got '$SOURCE_PERSONA'" >&2
  emit_err E4
  exit 4
fi

if ! "$SCRIPT_DIR/persona_check.sh" "Executioner"; then
  echo "E4: set_task_status requires Executioner persona; persona_check failed (see above)" >&2
  emit_err E4
  exit 4
fi

# ============================================================================

# Read current YAML status from frontmatter (first --- to second ---).
CURRENT_STATUS="$(awk '
  /^---$/ { c++; if (c == 2) exit; next }
  c == 1 && /^status:/ {
    sub(/^status:[[:space:]]*/, "")
    sub(/[[:space:]]*$/, "")
    print
    exit
  }
' "$TASK_PATH")"

if [[ "$CURRENT_STATUS" != "$FROM_STATUS" ]]; then
  echo "E3: current YAML status is '$CURRENT_STATUS', expected '$FROM_STATUS'" >&2
  emit_err E3
  exit 3
fi

# Atomic transform: rewrite the YAML status line in the frontmatter ONLY.
# Body markdown (which may contain prose like `status: in_progress`) is preserved.
TMP_FILE="$(mktemp "$TASK_PATH.XXXXXX")"
trap 'rm -f "$TMP_FILE"' EXIT

awk -v from="$FROM_STATUS" -v to="$TO_STATUS" '
  /^---$/ {
    c++
    print
    if (c >= 2) in_yaml = 0
    else in_yaml = 1
    next
  }
  in_yaml && $0 ~ "^status:[[:space:]]*" from "[[:space:]]*$" {
    print "status: " to
    next
  }
  { print }
' "$TASK_PATH" > "$TMP_FILE"

if ! mv "$TMP_FILE" "$TASK_PATH"; then
  echo "E1: failed to install updated task file" >&2
  emit_err E1
  exit 1
fi
trap - EXIT

END_TS_MS=$(($(date +%s) * 1000))
"$SCRIPT_DIR/emit_telemetry.sh" set_task_status success $((END_TS_MS - START_TS_MS)) null "$SOURCE_PERSONA" 2>/dev/null || true

exit 0

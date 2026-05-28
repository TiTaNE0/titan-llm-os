#!/usr/bin/env bash
# update_kanban.sh
#
# Atomic kanban move: removes a task-link line from one section and inserts it
# at the top of another section, in a *_Board.md file. Persona-origin-guarded
# via persona_check.sh.
#
# Contract: Tool_Registry.md § Subagent Engine Atoms § update_kanban
#   (firmed 2026-05-28 by Phase 2; original Phase 0 entry was contract-only.)
# Idempotent: Yes (no-op if task already in --to and not in --from).
# Persona Gate: Executioner (Phase 2 only; Synthesizer support is Phase 3).
# Telemetry: MANDATORY per Composition Rule 3.
#
# Match semantics:
#   - Section headers match exactly `## <column>` (e.g., `## Todo`, `## In Progress`).
#   - Task line is identified by literal substring containing --task-link (e.g.,
#     `[[TaskName]]`). Caller must pass the exact wikilink form present in the
#     board. For raw [[Name]] tasks (Phase 2 default), pass [[Name]]. For
#     pipe-suffixed entries like [[Name|Name (Archived)]], pass that exact form
#     (Phase 3 concern only).
#
# Exit codes:
#   0  success (move performed, OR idempotent no-op)
#   1  --board file missing OR mv failure (E1)
#   3  task not found in --from section, OR invalid/missing args (E3)
#   4  source_persona != Executioner OR live persona != Executioner (E4)

set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") --board <path> --task-link <[[Name]]> --from <column> --to <column> --source-persona <name>

Required:
  --board <path>             Absolute path to *_Board.md
  --task-link <[[Name]]>     Wikilink literal substring to find in --from section
  --from <column>            Source column header text (e.g., Todo, "In Progress")
  --to <column>              Target column header text
  --source-persona <name>    Caller-claimed persona (must be Executioner; Phase 2 scope)

Exit codes:
  0  success
  1  board file missing OR mv failure (E1)
  3  task not in --from section, OR invalid args (E3)
  4  persona mismatch or wrong persona (E4)
EOF
}

BOARD=""
TASK_LINK=""
FROM=""
TO=""
SOURCE_PERSONA=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --board)          BOARD="$2"; shift 2 ;;
    --task-link)      TASK_LINK="$2"; shift 2 ;;
    --from)           FROM="$2"; shift 2 ;;
    --to)             TO="$2"; shift 2 ;;
    --source-persona) SOURCE_PERSONA="$2"; shift 2 ;;
    -h|--help)        usage; exit 0 ;;
    *)                echo "Unknown arg: $1" >&2; usage >&2; exit 3 ;;
  esac
done

START_TS_MS=$(($(date +%s) * 1000))
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

emit_err() {
  local end=$(($(date +%s) * 1000))
  "$SCRIPT_DIR/emit_telemetry.sh" update_kanban error $((end - START_TS_MS)) "$1" "${SOURCE_PERSONA:-unknown}" 2>/dev/null || true
}

if [[ -z "$BOARD" || -z "$TASK_LINK" || -z "$FROM" || -z "$TO" || -z "$SOURCE_PERSONA" ]]; then
  echo "E3: missing required arg" >&2
  usage >&2
  emit_err E3
  exit 3
fi

if [[ ! -f "$BOARD" ]]; then
  echo "E1: board file not found: $BOARD" >&2
  emit_err E1
  exit 1
fi

# ============================================================================
# ENFORCEMENT BLOCK (persona-origin guard, Composition Rule 5)
# ============================================================================

# Half 1: source_persona arg must be Executioner (Phase 2 scope).
if [[ "$SOURCE_PERSONA" != "Executioner" ]]; then
  echo "E4: source_persona must be 'Executioner' (Phase 2 scope; Synthesizer support deferred to Phase 3); got '$SOURCE_PERSONA'" >&2
  emit_err E4
  exit 4
fi

# Half 2: live session persona must be Executioner.
if ! "$SCRIPT_DIR/persona_check.sh" "Executioner"; then
  echo "E4: update_kanban requires Executioner persona; persona_check failed (see above)" >&2
  emit_err E4
  exit 4
fi

# ============================================================================

# Pass 1: locate the task-line in the FROM section. Capture it for re-insertion.
TASK_LINE_CONTENT="$(awk -v from="$FROM" -v link="$TASK_LINK" '
  BEGIN { in_from = 0 }
  /^## / {
    in_from = ($0 == "## " from)
    next
  }
  in_from && index($0, link) > 0 {
    print $0
    exit
  }
' "$BOARD")"

if [[ -z "$TASK_LINE_CONTENT" ]]; then
  # Idempotency check: is the task already in TO? If yes, no-op success.
  TO_LINE_CONTENT="$(awk -v to="$TO" -v link="$TASK_LINK" '
    BEGIN { in_to = 0 }
    /^## / {
      in_to = ($0 == "## " to)
      next
    }
    in_to && index($0, link) > 0 {
      print $0
      exit
    }
  ' "$BOARD")"
  if [[ -n "$TO_LINE_CONTENT" ]]; then
    END_TS_MS=$(($(date +%s) * 1000))
    "$SCRIPT_DIR/emit_telemetry.sh" update_kanban success $((END_TS_MS - START_TS_MS)) null "$SOURCE_PERSONA" 2>/dev/null || true
    exit 0
  fi
  echo "E3: task '$TASK_LINK' not found in section '$FROM' on board $BOARD" >&2
  emit_err E3
  exit 3
fi

# Pass 2: write new board with line removed from FROM, inserted at top of TO.
TMP_FILE="$(mktemp "$BOARD.XXXXXX")"
trap 'rm -f "$TMP_FILE"' EXIT

awk -v from="$FROM" -v to="$TO" -v link="$TASK_LINK" -v task_line="$TASK_LINE_CONTENT" '
  BEGIN { in_from = 0; in_to = 0; just_entered_to = 0 }
  /^## / {
    in_from = ($0 == "## " from)
    in_to = ($0 == "## " to)
    just_entered_to = in_to
    print
    next
  }
  in_from && index($0, link) > 0 {
    next   # skip - remove from FROM
  }
  just_entered_to {
    print task_line   # insert at top of TO
    just_entered_to = 0
    print
    next
  }
  { print }
' "$BOARD" > "$TMP_FILE"

if ! mv "$TMP_FILE" "$BOARD"; then
  echo "E1: failed to install updated board" >&2
  emit_err E1
  exit 1
fi
trap - EXIT

END_TS_MS=$(($(date +%s) * 1000))
"$SCRIPT_DIR/emit_telemetry.sh" update_kanban success $((END_TS_MS - START_TS_MS)) null "$SOURCE_PERSONA" 2>/dev/null || true

exit 0

#!/usr/bin/env bash
# create_task.sh
#
# Atom: scaffold a new task .md from 00_Templates/Task_Template.md into
# 02_Tasks/<project>/<title>.md with filled YAML frontmatter. Write-once.
# Persona-origin-guarded via persona_check.sh. The four agent-populated sections
# (research_notes, spec, validator_report, verification_output) are left
# present-and-empty by construction — the template ships them as blockquote+anchor,
# and this atom copies the template verbatim, substituting only YAML + title.
#
# Contract: Tool_Registry.md § create_task
# Idempotent: No (write-once; second create with same title → E3 collision,
#             checked across BOTH 02_Tasks/ and 99_Archive/ so closed-then-recreated
#             titles still collide — wiki-links require global basename uniqueness).
# Persona Gate: Executioner (enforced via persona_check.sh, not declaration alone).
# Telemetry: MANDATORY per Composition Rule 3.
#
# Priority enum note: the Tool_Registry contract text reads enum[low,med,high],
# but the Task_Template default, the /new_task macro (priority=medium), and every
# existing task file use low|medium|high. This atom honors the de-facto enum
# (low|medium|high); the `med` typo in the contract should be fixed via /graduate.
#
# Exit codes:
#   0  success
#   1  project passport missing in 01_Projects/ (E1)
#   3  missing/invalid args OR title collision in 02_Tasks/ or 99_Archive/ (E3)
#   4  source_persona != Executioner OR live persona != Executioner (E4)

set -euo pipefail

ALLOWED_PRIORITIES="low medium high"

usage() {
  cat <<EOF
Usage: $(basename "$0") --title <name> --project <name> --priority <enum> --source-persona <name>

Required:
  --title <name>             Task title (also the .md basename; must be globally unique)
  --project <name>           Project key — must have a passport at 01_Projects/<name>.md
  --priority <enum>          $ALLOWED_PRIORITIES
  --source-persona <name>    Caller-claimed persona (must be Executioner)

Exit codes:
  0  success
  1  project passport missing in 01_Projects/ (E1)
  3  missing/invalid args OR title collision in 02_Tasks/ or 99_Archive/ (E3)
  4  persona mismatch or wrong persona (E4)
EOF
}

TITLE=""
PROJECT=""
PRIORITY=""
SOURCE_PERSONA=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --title)          TITLE="$2"; shift 2 ;;
    --project)        PROJECT="$2"; shift 2 ;;
    --priority)       PRIORITY="$2"; shift 2 ;;
    --source-persona) SOURCE_PERSONA="$2"; shift 2 ;;
    -h|--help)        usage; exit 0 ;;
    *)                echo "Unknown arg: $1" >&2; usage >&2; exit 3 ;;
  esac
done

START_TS_MS=$(($(date +%s) * 1000))
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
VAULT_DIR="$(dirname "$SCRIPT_DIR")"

emit_err() {
  local end=$(($(date +%s) * 1000))
  "$SCRIPT_DIR/emit_telemetry.sh" create_task error $((end - START_TS_MS)) "$1" "${SOURCE_PERSONA:-unknown}" 2>/dev/null || true
}

if [[ -z "$TITLE" || -z "$PROJECT" || -z "$PRIORITY" || -z "$SOURCE_PERSONA" ]]; then
  echo "E3: missing required arg" >&2; usage >&2; emit_err E3; exit 3
fi

validate_priority() {
  local p="$1"
  for allowed in $ALLOWED_PRIORITIES; do
    [[ "$p" == "$allowed" ]] && return 0
  done
  return 1
}

if ! validate_priority "$PRIORITY"; then
  echo "E3: invalid --priority '$PRIORITY' (allowed: $ALLOWED_PRIORITIES)" >&2; emit_err E3; exit 3
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
  echo "E4: create_task requires Executioner persona; persona_check failed (see above)" >&2
  emit_err E4
  exit 4
fi

# ============================================================================

# Pre-condition: project passport must exist (E1 — do NOT auto-create).
PASSPORT="$VAULT_DIR/01_Projects/$PROJECT.md"
if [[ ! -f "$PASSPORT" ]]; then
  echo "E1: project passport not found at 01_Projects/$PROJECT.md — create the project first" >&2
  emit_err E1
  exit 1
fi

# Pre-condition: title must be globally unique across live AND archived tasks.
# Wiki-links resolve by basename, so a collision anywhere is a hard refusal.
COLLISION="$(find "$VAULT_DIR/02_Tasks" "$VAULT_DIR/99_Archive/Tasks" -name "$TITLE.md" 2>/dev/null | head -1 || true)"
if [[ -n "$COLLISION" ]]; then
  echo "E3: task title '$TITLE' collides with existing file: $COLLISION" >&2
  emit_err E3
  exit 3
fi

TEMPLATE="$VAULT_DIR/00_Templates/Task_Template.md"
if [[ ! -f "$TEMPLATE" ]]; then
  echo "E1: task template not found at 00_Templates/Task_Template.md" >&2
  emit_err E1
  exit 1
fi

TASK_DIR="$VAULT_DIR/02_Tasks/$PROJECT"
mkdir -p "$TASK_DIR"
DEST="$TASK_DIR/$TITLE.md"

TODAY="$(date +%F)"

# Atomic write: render into a temp file in the destination dir, then rename.
# Substitute only YAML frontmatter fields + the title header. The four
# agent-populated section bodies are copied verbatim (blockquote+anchor =
# present-and-empty per grep_section.sh semantics).
TMP_FILE="$(mktemp "$TASK_DIR/.create_task.XXXXXX")"
trap 'rm -f "$TMP_FILE"' EXIT

sed \
  -e "s|^project: \[\[Project_Name\]\]|project: [[$PROJECT]]|" \
  -e "s|^priority: medium|priority: $PRIORITY|" \
  -e "s|^created: {{date}}|created: $TODAY|" \
  -e "s|^type: task.*|type: task|" \
  -e "s|{{title}}|$TITLE|g" \
  "$TEMPLATE" > "$TMP_FILE"

if ! mv "$TMP_FILE" "$DEST"; then
  echo "E1: failed to install task file at $DEST" >&2
  emit_err E1
  exit 1
fi
trap - EXIT

END_TS_MS=$(($(date +%s) * 1000))
"$SCRIPT_DIR/emit_telemetry.sh" create_task success $((END_TS_MS - START_TS_MS)) null "$SOURCE_PERSONA" 2>/dev/null || true

echo "02_Tasks/$PROJECT/$TITLE.md"
exit 0

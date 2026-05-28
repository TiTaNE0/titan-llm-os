#!/usr/bin/env bash
# write_task_section.sh
#
# Persona-gated mutator for /execute_task macro-owned task sections.
# The ONLY sanctioned writer for the four anchor-marked sections in task .md files:
#   research_notes, spec, validator_report, verification_output
#
# Enforcement (load-bearing - this is half of the persona-origin guard story):
#   1. source_persona arg must be "Executioner" (per spec step 3 + step 4 collapse)
#   2. Live session persona must be "Executioner" - verified by CALLING persona_check.sh.
#      Refusing to write if persona_check exits non-zero is the Phase 2 enforcement
#      contract. The two halves connect HERE.
#
# Contract: Tool_Registry.md § Subagent Engine Atoms § write_task_section
# Idempotent: No (overwrite=true replaces; default refuses on populated section)
# Persona Gate: Executioner (enforced via persona_check.sh exit code, NOT declaration alone)
# Telemetry: MANDATORY per Composition Rule 3; emit_telemetry.sh per Rule 1 carve-out
#
# Exit codes:
#   0  success
#   1  task_path or content_file missing (E1)
#   3  section anchor not found OR section already populated (E3)
#   4  source_persona != Executioner OR live persona != Executioner (E4)

set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") --task-path <abs> --section <enum> --source-persona <name> --content-file <abs> [--overwrite]

Required:
  --task-path <abs>          Absolute path to task .md
  --section <enum>           research_notes | spec | validator_report | verification_output
  --source-persona <name>    Caller-claimed persona (must be Executioner; verified against live state)
  --content-file <abs>       Absolute path to file containing markdown content to inject

Optional:
  --overwrite                Allow overwriting an already-populated section

Exit codes:
  0  success
  1  task_path or content_file missing (E1)
  3  section anchor not found OR section already populated (E3)
  4  source_persona != Executioner OR live persona != Executioner (E4)
EOF
}

TASK_PATH=""
SECTION=""
SOURCE_PERSONA=""
CONTENT_FILE=""
OVERWRITE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --task-path)      TASK_PATH="$2"; shift 2 ;;
    --section)        SECTION="$2"; shift 2 ;;
    --source-persona) SOURCE_PERSONA="$2"; shift 2 ;;
    --content-file)   CONTENT_FILE="$2"; shift 2 ;;
    --overwrite)      OVERWRITE=1; shift ;;
    -h|--help)        usage; exit 0 ;;
    *)                echo "Unknown arg: $1" >&2; usage >&2; exit 1 ;;
  esac
done

START_TS_MS=$(($(date +%s) * 1000))
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

emit_err() {
  local end=$(($(date +%s) * 1000))
  "$SCRIPT_DIR/emit_telemetry.sh" write_task_section error $((end - START_TS_MS)) "$1" "${SOURCE_PERSONA:-unknown}" 2>/dev/null || true
}

if [[ -z "$TASK_PATH" || -z "$SECTION" || -z "$SOURCE_PERSONA" || -z "$CONTENT_FILE" ]]; then
  echo "E1: missing required arg" >&2
  usage >&2
  emit_err E1
  exit 1
fi

case "$SECTION" in
  research_notes|spec|validator_report|verification_output) ;;
  *) echo "E3: invalid section '$SECTION'" >&2; emit_err E3; exit 3 ;;
esac

if [[ ! -f "$TASK_PATH" ]]; then
  echo "E1: task file not found: $TASK_PATH" >&2; emit_err E1; exit 1
fi

if [[ ! -f "$CONTENT_FILE" ]]; then
  echo "E1: content file not found: $CONTENT_FILE" >&2; emit_err E1; exit 1
fi

# ============================================================================
# ENFORCEMENT BLOCK (persona-origin guard, Composition Rule 5)
# This is where the two halves of the guard connect.
# ============================================================================

# Half 1: source_persona arg must be Executioner.
if [[ "$SOURCE_PERSONA" != "Executioner" ]]; then
  echo "E4: source_persona must be 'Executioner'; got '$SOURCE_PERSONA'" >&2
  emit_err E4
  exit 4
fi

# Half 2: live session persona must be Executioner - VERIFIED BY CALLING persona_check.sh.
# Refusing to write if this check fails is the load-bearing enforcement contract.
# A subagent cannot fake its way past this by supplying --source-persona=Executioner,
# because persona_check reads from .session_state.json which only the handshake writes.
if ! "$SCRIPT_DIR/persona_check.sh" "Executioner"; then
  echo "E4: write_task_section requires Executioner persona; persona_check failed (see above)" >&2
  emit_err E4
  exit 4
fi

# ============================================================================
# END ENFORCEMENT BLOCK. From here, live persona == Executioner is guaranteed.
# ============================================================================

# Step 5: locate anchor comment line.
ANCHOR="<!-- write_task_section section=$SECTION -->"
ANCHOR_LINE="$(grep -nF "$ANCHOR" "$TASK_PATH" | head -1 | cut -d: -f1 || true)"

if [[ -z "$ANCHOR_LINE" ]]; then
  echo "E3: section anchor not found in $TASK_PATH for section '$SECTION'" >&2
  emit_err E3
  exit 3
fi

# Determine END_LINE: line before next `## ` header, or EOF.
END_LINE="$(awk -v start="$ANCHOR_LINE" 'NR > start && /^## / { print NR-1; exit }' "$TASK_PATH")"
if [[ -z "$END_LINE" ]]; then
  END_LINE="$(wc -l < "$TASK_PATH" | tr -d ' ')"
fi

# Step 6: check empty (same semantics as grep_section.sh empty mode).
HAS_CONTENT=0
if awk -v start="$ANCHOR_LINE" -v end="$END_LINE" '
    NR <= start { next }
    NR > end { exit }
    {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      sub(/[[:space:]]+$/, "", line)
      if (line == "") next
      if (line ~ /^>/) next
      if (line ~ /^<!--/) next
      has = 1
      exit
    }
    END { exit !has }
  ' "$TASK_PATH"; then
  HAS_CONTENT=1
fi

if [[ "$HAS_CONTENT" -eq 1 && "$OVERWRITE" -ne 1 ]]; then
  echo "E3: section '$SECTION' is already populated; pass --overwrite to replace" >&2
  emit_err E3
  exit 3
fi

# Step 7: atomic replace of body lines (ANCHOR_LINE+1 .. END_LINE) with content.
TMP_FILE="$(mktemp "$TASK_PATH.XXXXXX")"
trap 'rm -f "$TMP_FILE"' EXIT

{
  sed -n "1,${ANCHOR_LINE}p" "$TASK_PATH"
  echo
  cat "$CONTENT_FILE"
  echo
  sed -n "$((END_LINE + 1)),\$p" "$TASK_PATH"
} > "$TMP_FILE"

if ! mv "$TMP_FILE" "$TASK_PATH"; then
  echo "E1: failed to install updated task file" >&2
  emit_err E1
  exit 1
fi
trap - EXIT

# Step 8: success telemetry.
END_TS_MS=$(($(date +%s) * 1000))
"$SCRIPT_DIR/emit_telemetry.sh" write_task_section success $((END_TS_MS - START_TS_MS)) null "$SOURCE_PERSONA" 2>/dev/null || true

exit 0

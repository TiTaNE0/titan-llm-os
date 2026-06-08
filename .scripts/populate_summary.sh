#!/usr/bin/env bash
# populate_summary.sh
#
# Persona-gated writer for the `## 🏁 COMPLETION SUMMARY` section of a task .md.
# Backs /close_task macro step 3. Unlike write_task_section.sh, this section has
# NO `<!-- write_task_section section=... -->` anchor - it is located by HEADER TEXT
# (emoji-tolerant). The caller renders the four-field block (technical_meat,
# deviations, debt, proof) into --content-file; this atom is dumb about shape.
#
# Contract: Tool_Registry.md § Subagent Engine Atoms § populate_summary
# Idempotent: No (default refuses on populated section; --overwrite replaces).
# Persona Gate: Executioner (enforced via persona_check.sh exit code).
# Telemetry: MANDATORY per Composition Rule 3.
#
# "Empty" semantics: the section is considered unpopulated (safe to fill without
# --overwrite) when every body line is blank, a blockquote (>), an HTML comment,
# OR a skeleton bullet `- **<Label>:**` whose value is empty or a parenthetical
# hint (starts with `(`). Any other content marks it populated.
#
# Exit codes:
#   0  success
#   1  missing required arg, task/content file missing, OR mv failure (E1)
#   3  COMPLETION SUMMARY header not found OR section already populated (E3)
#   4  source_persona != Executioner OR live persona != Executioner (E4)

set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") --task-path <abs> --source-persona <name> --content-file <abs> [--overwrite]

Required:
  --task-path <abs>          Absolute path to task .md
  --source-persona <name>    Caller-claimed persona (must be Executioner; verified against live state)
  --content-file <abs>       Absolute path to file with the rendered four-field block

Optional:
  --overwrite                Allow overwriting an already-populated section

Exit codes:
  0  success
  1  missing arg, task/content file missing, OR mv failure (E1)
  3  header not found OR section already populated (E3)
  4  persona mismatch or wrong persona (E4)
EOF
}

TASK_PATH=""
SOURCE_PERSONA=""
CONTENT_FILE=""
OVERWRITE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --task-path)      TASK_PATH="$2"; shift 2 ;;
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
  "$SCRIPT_DIR/emit_telemetry.sh" populate_summary error $((end - START_TS_MS)) "$1" "${SOURCE_PERSONA:-unknown}" 2>/dev/null || true
}

if [[ -z "$TASK_PATH" || -z "$SOURCE_PERSONA" || -z "$CONTENT_FILE" ]]; then
  echo "E1: missing required arg" >&2; usage >&2; emit_err E1; exit 1
fi

if [[ ! -f "$TASK_PATH" ]]; then
  echo "E1: task file not found: $TASK_PATH" >&2; emit_err E1; exit 1
fi

if [[ ! -f "$CONTENT_FILE" ]]; then
  echo "E1: content file not found: $CONTENT_FILE" >&2; emit_err E1; exit 1
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
  echo "E4: populate_summary requires Executioner persona; persona_check failed (see above)" >&2
  emit_err E4
  exit 4
fi

# ============================================================================

# Locate COMPLETION SUMMARY header by text (emoji-tolerant).
HEADER_LINE="$(grep -nE '^##[[:space:]].*COMPLETION SUMMARY' "$TASK_PATH" | head -1 | cut -d: -f1 || true)"

if [[ -z "$HEADER_LINE" ]]; then
  echo "E3: COMPLETION SUMMARY header not found in $TASK_PATH" >&2
  emit_err E3
  exit 3
fi

# Determine END_LINE: line before next `## ` header, or EOF.
END_LINE="$(awk -v start="$HEADER_LINE" 'NR > start && /^## / { print NR-1; exit }' "$TASK_PATH")"
if [[ -z "$END_LINE" ]]; then
  END_LINE="$(wc -l < "$TASK_PATH" | tr -d ' ')"
fi

# Populated check (see "Empty" semantics in header).
HAS_CONTENT=0
if awk -v start="$HEADER_LINE" -v end="$END_LINE" '
    NR <= start { next }
    NR > end { exit }
    {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      sub(/[[:space:]]+$/, "", line)
      if (line == "") next
      if (line ~ /^>/) next
      if (line ~ /^<!--/) next
      if (line ~ /^- \*\*[^*]+:\*\*/) {
        val = line
        sub(/^- \*\*[^*]+:\*\*[[:space:]]*/, "", val)
        if (val == "") next
        if (val ~ /^\(/) next
        has = 1; exit
      }
      has = 1; exit
    }
    END { exit !has }
  ' "$TASK_PATH"; then
  HAS_CONTENT=1
fi

if [[ "$HAS_CONTENT" -eq 1 && "$OVERWRITE" -ne 1 ]]; then
  echo "E3: COMPLETION SUMMARY is already populated; pass --overwrite to replace" >&2
  emit_err E3
  exit 3
fi

# Atomic replace of body lines (HEADER_LINE+1 .. END_LINE) with content.
TMP_FILE="$(mktemp "$TASK_PATH.XXXXXX")"
trap 'rm -f "$TMP_FILE"' EXIT

{
  sed -n "1,${HEADER_LINE}p" "$TASK_PATH"
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

END_TS_MS=$(($(date +%s) * 1000))
"$SCRIPT_DIR/emit_telemetry.sh" populate_summary success $((END_TS_MS - START_TS_MS)) null "$SOURCE_PERSONA" 2>/dev/null || true

exit 0

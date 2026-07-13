#!/usr/bin/env bash
# author_contract.sh
#
# Guarded writer for a task's HEADER contract sections — Declarative Objective,
# Definition of Done, Verification Gateway — located by header text (emoji-tolerant).
# Completes the population half of Task_Contract_Population_And_Guard: `create_task
# --objective` seeds the objective at CREATION; this authors any of the three header
# sections on an EXISTING task THROUGH a guarded script, so the guarded-script
# invariant holds (no inline .md Edit, which the harness blocks).
#
# Contract: Tool_Registry.md § author_contract (registered 2026-06-17 via /graduate).
# Persona Gate: Executioner (source-persona arg + persona_check, like write_task_section).
# Idempotent: No. Refuses an already-authored section unless --overwrite.
# Telemetry: MANDATORY.
#
# Exit codes:
#   0  success
#   1  task or content file missing, OR mv failure (E1)
#   3  missing/invalid args, section header not found, OR already authored without --overwrite (E3)
#   4  source_persona != Executioner OR live persona != Executioner (E4)

set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") --task-path <abs> --section <objective|dod|gateway> \\
                        --content-file <abs> --source-persona <name> [--overwrite] \\
                        [--provenance <human|inbox_intake>]

Sections (located by header text):
  objective  → ## 📋 Declarative Objective
  dod        → ## 🎯 Definition of Done
  gateway    → ## 🧪 Verification Gateway

--provenance: when section=gateway, stamps gateway_provenance in the frontmatter.
  human        (default) — contract was authored interactively by a human.
  inbox_intake — contract originated from autonomous 00_Inbox intake.
  Absent/empty defaults to human (non-breaking for existing tasks).

Exit codes: 0 ok; 1 file missing/mv fail (E1); 3 args/header-missing/already-authored (E3); 4 persona (E4)
EOF
}

TASK_PATH=""; SECTION=""; CONTENT_FILE=""; SOURCE_PERSONA=""; OVERWRITE=0; PROVENANCE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --task-path)      TASK_PATH="$2";      shift 2 ;;
    --section)        SECTION="$2";        shift 2 ;;
    --content-file)   CONTENT_FILE="$2";   shift 2 ;;
    --source-persona) SOURCE_PERSONA="$2"; shift 2 ;;
    --overwrite)      OVERWRITE=1;         shift ;;
    --provenance)     PROVENANCE="$2";     shift 2 ;;
    -h|--help)        usage; exit 0 ;;
    *)                echo "E3: unknown arg: $1" >&2; usage >&2; exit 3 ;;
  esac
done

START_TS_MS=$(($(date +%s) * 1000))
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
emit_err() { local e=$(($(date +%s) * 1000)); "$SCRIPT_DIR/emit_telemetry.sh" author_contract error $((e - START_TS_MS)) "$1" "${SOURCE_PERSONA:-unknown}" 2>/dev/null || true; }

if [[ -z "$TASK_PATH" || -z "$SECTION" || -z "$CONTENT_FILE" || -z "$SOURCE_PERSONA" ]]; then
  echo "E3: missing required arg" >&2; usage >&2; emit_err E3; exit 3
fi

# Validate --provenance value (empty is fine, treated as human)
case "${PROVENANCE}" in
  ""|human|inbox_intake) ;;
  *) echo "E3: invalid --provenance '${PROVENANCE}' (human|inbox_intake)" >&2; emit_err E3; exit 3 ;;
esac

case "$SECTION" in
  objective) HDR_TEXT="Declarative Objective"; PLACEHOLDER="- [ ] (What we want to achieve)" ;;
  dod)       HDR_TEXT="Definition of Done";    PLACEHOLDER="- [ ] (Success criteria)" ;;
  gateway)   HDR_TEXT="Verification Gateway";  PLACEHOLDER="- [ ] **Test Command:** (Command to run)" ;;
  *) echo "E3: invalid --section '$SECTION' (objective|dod|gateway)" >&2; emit_err E3; exit 3 ;;
esac

[[ -f "$TASK_PATH" ]]    || { echo "E1: task file not found: $TASK_PATH" >&2; emit_err E1; exit 1; }
[[ -f "$CONTENT_FILE" ]] || { echo "E1: content file not found: $CONTENT_FILE" >&2; emit_err E1; exit 1; }

# Persona-origin guard (same pattern as write_task_section / set_task_status).
if [[ "$SOURCE_PERSONA" != "Executioner" ]]; then
  echo "E4: source_persona must be 'Executioner'; got '$SOURCE_PERSONA'" >&2; emit_err E4; exit 4
fi
if ! "$SCRIPT_DIR/persona_check.sh" "Executioner"; then
  echo "E4: author_contract requires Executioner persona; persona_check failed" >&2; emit_err E4; exit 4
fi

# Locate the section header line (starts with "## " and contains the section text).
HDR_LINE="$(awk -v t="$HDR_TEXT" 'index($0,"## ")==1 && index($0,t){print NR; exit}' "$TASK_PATH")"
if [[ -z "$HDR_LINE" ]]; then
  echo "E3: section header for '$SECTION' (## ... $HDR_TEXT) not found in $TASK_PATH" >&2; emit_err E3; exit 3
fi
# End of section body = line before the next "## " header, or EOF.
END_LINE="$(awk -v s="$HDR_LINE" 'NR>s && index($0,"## ")==1 {print NR-1; exit}' "$TASK_PATH")"
[[ -z "$END_LINE" ]] && END_LINE="$(wc -l < "$TASK_PATH" | tr -d ' ')"

# Refuse to clobber an already-authored section: it is "unauthored" only while the
# verbatim placeholder line is still present in the body.
if ! sed -n "$((HDR_LINE + 1)),${END_LINE}p" "$TASK_PATH" | grep -qxF -- "$PLACEHOLDER"; then
  if [[ "$OVERWRITE" -ne 1 ]]; then
    echo "E3: § $HDR_TEXT is already authored; pass --overwrite to replace" >&2; emit_err E3; exit 3
  fi
fi

# Atomic replace of the body (HDR_LINE+1 .. END_LINE) with the content file.
TMP_FILE="$(mktemp "$TASK_PATH.XXXXXX")"
trap 'rm -f "$TMP_FILE"' EXIT
{
  sed -n "1,${HDR_LINE}p" "$TASK_PATH"
  echo
  cat "$CONTENT_FILE"
  echo
  sed -n "$((END_LINE + 1)),\$p" "$TASK_PATH"
} > "$TMP_FILE"

if ! mv "$TMP_FILE" "$TASK_PATH"; then
  echo "E1: failed to install updated task file" >&2; emit_err E1; exit 1
fi
trap - EXIT

# When authoring the gateway section, upsert gateway_provenance into frontmatter.
# Atomic: awk rewrite → temp file → mv. Crash between this mv and the one above
# degrades to missing stamp (treated as human at read time — never more permissive
# than intended under orchestration since the stamp only tightens).
if [[ "$SECTION" == "gateway" ]]; then
  STAMP_VAL="${PROVENANCE:-human}"
  STAMP_TMP="$(mktemp "$TASK_PATH.XXXXXX")"
  trap 'rm -f "$STAMP_TMP"' EXIT
  awk -v prov="$STAMP_VAL" '
    BEGIN { c=0; done=0 }
    /^---$/ {
      c++
      if (c==2 && !done) {
        print "gateway_provenance: " prov
        done=1
      }
      print; next
    }
    c==1 && /^gateway_provenance:/ {
      print "gateway_provenance: " prov
      done=1
      next
    }
    { print }
  ' "$TASK_PATH" > "$STAMP_TMP"
  if ! mv "$STAMP_TMP" "$TASK_PATH"; then
    echo "E1: failed to install frontmatter stamp" >&2; emit_err E1; exit 1
  fi
  trap - EXIT
fi

END_TS_MS=$(($(date +%s) * 1000))
"$SCRIPT_DIR/emit_telemetry.sh" author_contract success $((END_TS_MS - START_TS_MS)) null "$SOURCE_PERSONA" 2>/dev/null || true
echo "authored § $HDR_TEXT in $(basename "$TASK_PATH")"
exit 0

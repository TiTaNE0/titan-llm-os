#!/usr/bin/env bash
# archive_file.sh
#
# Persona-gated file move for /close_task macro step 4 (task .md -> 99_Archive/).
# Uses `git mv` when the source's directory is inside a git work-tree (so history
# follows the move); falls back to plain `mv` otherwise. Refuses to clobber an
# existing destination (E2) and refuses to create the destination parent dir
# (E1 if missing) - both are loud-not-silent guards matching the existing atoms.
#
# Contract: Tool_Registry.md § Subagent Engine Atoms § archive_file
# Idempotent: No (repeat call -> E1 source missing or E2 dest exists).
# Persona Gate: Executioner (enforced via persona_check.sh exit code).
# Telemetry: MANDATORY per Composition Rule 3.
#
# Exit codes:
#   0  success
#   1  missing required arg, source missing, dest parent dir missing, OR move failure (E1)
#   2  destination already exists (E2)
#   4  source_persona != Executioner OR live persona != Executioner (E4)

set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") --source <abs> --dest <abs> --source-persona <name>

Required:
  --source <abs>             Absolute path to file being archived
  --dest <abs>               Absolute destination path (parent dir must already exist)
  --source-persona <name>    Caller-claimed persona (must be Executioner)

Exit codes:
  0  success
  1  missing arg, source missing, dest parent missing, OR move failure (E1)
  2  destination already exists (E2)
  4  persona mismatch or wrong persona (E4)
EOF
}

SOURCE=""
DEST=""
SOURCE_PERSONA=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source)         SOURCE="$2"; shift 2 ;;
    --dest)           DEST="$2"; shift 2 ;;
    --source-persona) SOURCE_PERSONA="$2"; shift 2 ;;
    -h|--help)        usage; exit 0 ;;
    *)                echo "Unknown arg: $1" >&2; usage >&2; exit 1 ;;
  esac
done

START_TS_MS=$(($(date +%s) * 1000))
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

emit_err() {
  local end=$(($(date +%s) * 1000))
  "$SCRIPT_DIR/emit_telemetry.sh" archive_file error $((end - START_TS_MS)) "$1" "${SOURCE_PERSONA:-unknown}" 2>/dev/null || true
}

if [[ -z "$SOURCE" || -z "$DEST" || -z "$SOURCE_PERSONA" ]]; then
  echo "E1: missing required arg" >&2; usage >&2; emit_err E1; exit 1
fi

if [[ ! -f "$SOURCE" ]]; then
  echo "E1: source file not found: $SOURCE" >&2; emit_err E1; exit 1
fi

if [[ ! -d "$(dirname "$DEST")" ]]; then
  echo "E1: destination parent directory does not exist: $(dirname "$DEST")" >&2; emit_err E1; exit 1
fi

if [[ -e "$DEST" ]]; then
  echo "E2: destination already exists: $DEST" >&2; emit_err E2; exit 2
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
  echo "E4: archive_file requires Executioner persona; persona_check failed (see above)" >&2
  emit_err E4
  exit 4
fi

# ============================================================================

# git mv when inside a work-tree (history follows); plain mv otherwise.
if git -C "$(dirname "$SOURCE")" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  MOVE_OK=0
  git -C "$(dirname "$SOURCE")" mv "$SOURCE" "$DEST" >/dev/null 2>&1 && MOVE_OK=1
  if [[ "$MOVE_OK" -ne 1 ]]; then
    # git mv can refuse (e.g. dest outside the same repo); fall back to plain mv.
    mv "$SOURCE" "$DEST" || { echo "E1: move failed: $SOURCE -> $DEST" >&2; emit_err E1; exit 1; }
  fi
else
  mv "$SOURCE" "$DEST" || { echo "E1: move failed: $SOURCE -> $DEST" >&2; emit_err E1; exit 1; }
fi

END_TS_MS=$(($(date +%s) * 1000))
"$SCRIPT_DIR/emit_telemetry.sh" archive_file success $((END_TS_MS - START_TS_MS)) null "$SOURCE_PERSONA" 2>/dev/null || true

exit 0

#!/usr/bin/env bash
# resolve_attention.sh
#
# Resolve-side atom for the Needs_Attention.md queue. Finds the first unchecked
# entry matching task+state+run_id triple, flips `- [ ]` to `- [x]`, and appends
# resolution metadata. Mirrors queue_attention.sh's structure: atomic temp-file
# rewrite, persona gate via persona_check.sh, mandatory emit_telemetry.sh call.
#
# Entry line (after resolution):
#   - [x] [[<task>]] | state: <state> | ... | resolved: <class> | resolved_at: <ISO8601Z> [| note: <text>]
#
# Idempotent: if a CHECKED entry with the same task+state+run_id already exists,
#             exit 0 (no-op). Prevents double-accounting.
# Persona Gate: Executioner (source-persona arg + persona_check.sh).
# Telemetry: MANDATORY per Composition Rule 3.
#
# Exit codes:
#   0  success (including idempotent no-op)
#   1  queue file missing OR write failure (E1)
#   3  missing/invalid args OR no matching entry found (E3)
#   4  source_persona != Executioner OR live persona != Executioner (E4)

set -euo pipefail

ALLOWED_RESOLUTIONS="fixed_code fixed_spec fixed_brief fixed_brain wont_fix duplicate promoted"

usage() {
  cat <<EOF
Usage: $(basename "$0") --task <[[Name]]|Name> --state <enum> --run-id <id> \\
                        --resolution <class> --source-persona <name> [--note <text>] [--queue-file <path>]

Required:
  --task <name>             Task to resolve (wiki-link or bare name; matched as [[Name]])
  --state <enum>            State the entry was queued under
  --run-id <id>             Run ID of the entry to resolve
  --resolution <class>      $ALLOWED_RESOLUTIONS
  --source-persona <name>   Caller-claimed persona (must be Executioner)

Optional:
  --note <text>             Single-line note appended after resolved_at (no newlines)
  --queue-file <path>       Override queue file (default: <vault>/Needs_Attention.md). For tests.

Exit codes:
  0  success (incl. idempotent no-op)
  1  queue file missing OR write failure (E1)
  3  missing/invalid args OR no match (E3)
  4  persona mismatch or wrong persona (E4)
EOF
}

TASK=""
STATE=""
RUN_ID=""
RESOLUTION=""
SOURCE_PERSONA=""
NOTE=""
QUEUE_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --task)           TASK="$2"; shift 2 ;;
    --state)          STATE="$2"; shift 2 ;;
    --run-id)         RUN_ID="$2"; shift 2 ;;
    --resolution)     RESOLUTION="$2"; shift 2 ;;
    --source-persona) SOURCE_PERSONA="$2"; shift 2 ;;
    --note)           NOTE="$2"; shift 2 ;;
    --queue-file)     QUEUE_FILE="$2"; shift 2 ;;
    -h|--help)        usage; exit 0 ;;
    *)                echo "E3: unknown arg: $1" >&2; usage >&2; exit 3 ;;
  esac
done

START_TS_MS=$(($(date +%s) * 1000))
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
VAULT_DIR="$(dirname "$SCRIPT_DIR")"

emit_err() {
  local end=$(($(date +%s) * 1000))
  "$SCRIPT_DIR/emit_telemetry.sh" resolve_attention error $((end - START_TS_MS)) "$1" "${SOURCE_PERSONA:-unknown}" 2>/dev/null || true
}

if [[ -z "$TASK" || -z "$STATE" || -z "$RUN_ID" || -z "$RESOLUTION" || -z "$SOURCE_PERSONA" ]]; then
  echo "E3: missing required arg" >&2; usage >&2; emit_err E3; exit 3
fi

in_set() { local v="$1"; shift; for a in "$@"; do [[ "$v" == "$a" ]] && return 0; done; return 1; }

if ! in_set "$RESOLUTION" $ALLOWED_RESOLUTIONS; then
  echo "E3: invalid --resolution '$RESOLUTION' (allowed: $ALLOWED_RESOLUTIONS)" >&2; emit_err E3; exit 3
fi

# note must be single-line (the entry is one line; a newline would corrupt the queue).
if [[ "$NOTE" == *$'\n'* ]]; then
  echo "E3: --note must be single-line" >&2; emit_err E3; exit 3
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
  echo "E4: resolve_attention requires Executioner persona; persona_check failed (see above)" >&2
  emit_err E4
  exit 4
fi

# ============================================================================

# Normalize task to a bare name, then always match [[Name]].
TASK_NAME="${TASK#[[}"
TASK_NAME="${TASK_NAME%]]}"

QUEUE="${QUEUE_FILE:-$VAULT_DIR/Needs_Attention.md}"
QUEUE_DIR="$(dirname "$QUEUE")"

if [[ ! -f "$QUEUE" ]]; then
  echo "E1: queue file not found: $QUEUE" >&2; emit_err E1; exit 1
fi

ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Build the resolution suffix to append.
RESOLUTION_SUFFIX="| resolved: $RESOLUTION | resolved_at: $ISO"
if [[ -n "$NOTE" ]]; then
  RESOLUTION_SUFFIX="$RESOLUTION_SUFFIX | note: $NOTE"
fi

# ============================================================================
# IDEMPOTENCY CHECK: if a CHECKED entry already matches task+state+run_id, no-op.
# ============================================================================
if awk '/^## Open/{f=1; next} f' "$QUEUE" \
     | grep '^- \[x\]' \
     | grep -F "[[$TASK_NAME]]" \
     | grep -F "state: $STATE " \
     | grep -qF "run_id: $RUN_ID "; then
  echo "no-op: entry already resolved for [[$TASK_NAME]] / $STATE / run $RUN_ID"
  END_TS_MS=$(($(date +%s) * 1000))
  "$SCRIPT_DIR/emit_telemetry.sh" resolve_attention success $((END_TS_MS - START_TS_MS)) null "$SOURCE_PERSONA" 2>/dev/null || true
  exit 0
fi

# ============================================================================
# MATCH CHECK: verify an unchecked entry exists before rewriting.
# ============================================================================
if ! awk '/^## Open/{f=1; next} f' "$QUEUE" \
       | grep '^- \[ \]' \
       | grep -F "[[$TASK_NAME]]" \
       | grep -F "state: $STATE " \
       | grep -qF "run_id: $RUN_ID "; then
  echo "E3: no open entry found for [[$TASK_NAME]] / state: $STATE / run_id: $RUN_ID" >&2
  emit_err E3
  exit 3
fi

# ============================================================================
# ATOMIC REWRITE: flip first matching unchecked entry under ## Open.
# ============================================================================
TMP_FILE="$(mktemp "$QUEUE_DIR/.resolve_attention.XXXXXX")"
trap 'rm -f "$TMP_FILE"' EXIT

# awk rewrites the first unchecked matching line; all others pass through.
awk \
  -v task="[[$TASK_NAME]]" \
  -v state_pat="state: $STATE " \
  -v runid_pat="run_id: $RUN_ID " \
  -v suffix=" $RESOLUTION_SUFFIX" \
  'BEGIN { in_open=0; done=0 }
   /^## Open/ { in_open=1 }
   in_open && /^## / && !/^## Open/ { in_open=0 }
   in_open && !done && /^- \[ \]/ &&
     index($0, task) && index($0, state_pat) && index($0, runid_pat) {
       sub(/^- \[ \]/, "- [x]")
       $0 = $0 suffix
       done=1
   }
   { print }' "$QUEUE" > "$TMP_FILE"

if ! mv "$TMP_FILE" "$QUEUE"; then
  echo "E1: failed to install queue file at $QUEUE" >&2; emit_err E1; exit 1
fi
trap - EXIT

END_TS_MS=$(($(date +%s) * 1000))
"$SCRIPT_DIR/emit_telemetry.sh" resolve_attention success $((END_TS_MS - START_TS_MS)) null "$SOURCE_PERSONA" 2>/dev/null || true

echo "resolved: [[$TASK_NAME]] / $STATE / run $RUN_ID -> $RESOLUTION"
exit 0

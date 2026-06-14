#!/usr/bin/env bash
# queue_attention.sh
#
# Async escalation atom (Orchestrator A3). Appends one entry to the Needs_Attention.md
# queue at the vault root: the autonomous loop / PM reviewer / failure panel record an
# escalation here and keep going, instead of halting the whole run. Humans are
# on-the-loop. Seeds the queue from 00_Templates/Needs_Attention_Template.md if absent.
#
# Entry line (under ## Open):
#   - [ ] [[<task>]] | state: <state> | source: <source> | run: <run_id> | at: <ISO> | reason: <reason>
#
# Contract: Tool_Registry.md § queue_attention (registration deferred to the Phase B
#           /graduate session per Orchestrator A3 — Brain file not edited here).
# Idempotent: Yes, by design — no-op if an UNCHECKED entry with the same
#             task+state+run_id already exists. A resolved (checked) entry does not
#             block a fresh re-escalation of the same event.
# Persona Gate: Executioner (the loop runs as Executioner; `source` is a data field,
#               not the executor). Enforced via persona_check.sh.
# Telemetry: MANDATORY per Composition Rule 3.
#
# Exit codes:
#   0  success (including idempotent no-op)
#   1  queue parent dir missing OR write failure (E1)
#   3  missing/invalid args (E3)
#   4  source_persona != Executioner OR live persona != Executioner (E4)

set -euo pipefail

ALLOWED_STATES="spec_gate close_gate retries_exhausted no_progress orphaned_lock panel_escalate"
ALLOWED_SOURCES="orchestrator pm_reviewer failure_panel"

usage() {
  cat <<EOF
Usage: $(basename "$0") --task <[[Name]]|Name> --state <enum> --source <enum> \\
                        --run-id <id> --reason <text> --source-persona <name> [--queue-file <path>]

Required:
  --task <name>             Blocked task (wiki-link or bare name; rendered as [[Name]])
  --state <enum>            $ALLOWED_STATES
  --source <enum>           $ALLOWED_SOURCES
  --run-id <id>             Run that raised the escalation (use 'null' if outside a run)
  --reason <text>           Free-text reason (may contain any punctuation)
  --source-persona <name>   Caller-claimed persona (must be Executioner)

Optional:
  --queue-file <path>       Override queue file (default: <vault>/Needs_Attention.md). For tests.

Exit codes:
  0  success (incl. idempotent no-op)
  1  queue parent dir missing OR write failure (E1)
  3  missing/invalid args (E3)
  4  persona mismatch or wrong persona (E4)
EOF
}

TASK=""
STATE=""
SOURCE=""
RUN_ID=""
REASON=""
SOURCE_PERSONA=""
QUEUE_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --task)           TASK="$2"; shift 2 ;;
    --state)          STATE="$2"; shift 2 ;;
    --source)         SOURCE="$2"; shift 2 ;;
    --run-id)         RUN_ID="$2"; shift 2 ;;
    --reason)         REASON="$2"; shift 2 ;;
    --source-persona) SOURCE_PERSONA="$2"; shift 2 ;;
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
  "$SCRIPT_DIR/emit_telemetry.sh" queue_attention error $((end - START_TS_MS)) "$1" "${SOURCE_PERSONA:-unknown}" 2>/dev/null || true
}

if [[ -z "$TASK" || -z "$STATE" || -z "$SOURCE" || -z "$RUN_ID" || -z "$REASON" || -z "$SOURCE_PERSONA" ]]; then
  echo "E3: missing required arg" >&2; usage >&2; emit_err E3; exit 3
fi

in_set() { local v="$1"; shift; for a in "$@"; do [[ "$v" == "$a" ]] && return 0; done; return 1; }

if ! in_set "$STATE" $ALLOWED_STATES; then
  echo "E3: invalid --state '$STATE' (allowed: $ALLOWED_STATES)" >&2; emit_err E3; exit 3
fi
if ! in_set "$SOURCE" $ALLOWED_SOURCES; then
  echo "E3: invalid --source '$SOURCE' (allowed: $ALLOWED_SOURCES)" >&2; emit_err E3; exit 3
fi

# reason must be single-line (the entry is one line; a newline would corrupt the queue).
if [[ "$REASON" == *$'\n'* ]]; then
  echo "E3: --reason must be single-line" >&2; emit_err E3; exit 3
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
  echo "E4: queue_attention requires Executioner persona; persona_check failed (see above)" >&2
  emit_err E4
  exit 4
fi

# ============================================================================

# Normalize task to a bare name, then always render [[Name]].
TASK_NAME="${TASK#[[}"
TASK_NAME="${TASK_NAME%]]}"

QUEUE="${QUEUE_FILE:-$VAULT_DIR/Needs_Attention.md}"
TEMPLATE="$VAULT_DIR/00_Templates/Needs_Attention_Template.md"
QUEUE_DIR="$(dirname "$QUEUE")"

if [[ ! -d "$QUEUE_DIR" ]]; then
  echo "E1: queue parent directory does not exist: $QUEUE_DIR" >&2; emit_err E1; exit 1
fi

ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
ENTRY="- [ ] [[$TASK_NAME]] | state: $STATE | source: $SOURCE | run: $RUN_ID | at: $ISO | reason: $REASON"

# Idempotency: no-op if an UNCHECKED entry already exists for this task+state+run_id.
# Scope to the body under `## Open` so the schema example in the template header
# (which also starts with `- [ ]`) is never mistaken for a live entry.
if [[ -f "$QUEUE" ]]; then
  if awk '/^## Open/{f=1; next} f' "$QUEUE" \
       | grep '^- \[ \]' \
       | grep -F "[[$TASK_NAME]]" \
       | grep -F "state: $STATE " \
       | grep -qF "run: $RUN_ID "; then
    echo "no-op: open escalation already queued for [[$TASK_NAME]] / $STATE / run $RUN_ID"
    END_TS_MS=$(($(date +%s) * 1000))
    "$SCRIPT_DIR/emit_telemetry.sh" queue_attention success $((END_TS_MS - START_TS_MS)) null "$SOURCE_PERSONA" 2>/dev/null || true
    exit 0
  fi
fi

# Atomic append: build full new content in a temp file, then rename.
TMP_FILE="$(mktemp "$QUEUE_DIR/.needs_attention.XXXXXX")"
trap 'rm -f "$TMP_FILE"' EXIT

if [[ -f "$QUEUE" ]]; then
  cat "$QUEUE" > "$TMP_FILE"
elif [[ -f "$TEMPLATE" ]]; then
  cat "$TEMPLATE" > "$TMP_FILE"
else
  printf '# Needs Attention\n\n## Open\n' > "$TMP_FILE"
fi
printf '%s\n' "$ENTRY" >> "$TMP_FILE"

if ! mv "$TMP_FILE" "$QUEUE"; then
  echo "E1: failed to install queue file at $QUEUE" >&2; emit_err E1; exit 1
fi
trap - EXIT

END_TS_MS=$(($(date +%s) * 1000))
"$SCRIPT_DIR/emit_telemetry.sh" queue_attention success $((END_TS_MS - START_TS_MS)) null "$SOURCE_PERSONA" 2>/dev/null || true

echo "queued: $ENTRY"
exit 0

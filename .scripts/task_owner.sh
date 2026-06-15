#!/usr/bin/env bash
# task_owner.sh
#
# Orchestrator run-ownership marker (C4, PRD §6). Stamps/reads `orchestrator_run_id`
# in a task's YAML frontmatter. The run stamps every task it starts; on boot the
# Orchestrator may RESUME tasks it owns (status in_progress + matching run id), while
# an in_progress task carrying a DEAD run id is orphaned and gets queued (never
# force-flipped). This atom is the stamp/read half; stale_lock_scan.sh finds orphans.
#
# Set (default): insert or replace `orchestrator_run_id: <id>` in frontmatter, atomic.
# --get: print the current value (empty if unstamped).
#
# Contract: Tool_Registry.md § task_owner (registration deferred to Phase C /graduate).
# Persona Gate: Executioner (02_Tasks YAML mutation; rides with the dispatched tick).
# Telemetry: MANDATORY on set (write tool). --get is read-only (no telemetry).
#
# Exit codes:
#   0  ok
#   1  task file missing OR write failure (E1)
#   3  missing args (E3)
#   4  source_persona != Executioner OR live persona != Executioner (E4)

set -euo pipefail

usage() { echo "Usage: $(basename "$0") --task-path <abs> [--run-id <id> --source-persona <name>] [--get]"; }

TASK_PATH=""; RUN_ID=""; SOURCE_PERSONA=""; GET=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --task-path)      TASK_PATH="$2"; shift 2 ;;
    --run-id)         RUN_ID="$2"; shift 2 ;;
    --source-persona) SOURCE_PERSONA="$2"; shift 2 ;;
    --get)            GET=1; shift ;;
    -h|--help)        usage; exit 0 ;;
    *)                echo "E3: unknown arg: $1" >&2; usage >&2; exit 3 ;;
  esac
done

[[ -z "$TASK_PATH" ]] && { echo "E3: --task-path required" >&2; usage >&2; exit 3; }
[[ -f "$TASK_PATH" ]] || { echo "E1: task not found: $TASK_PATH" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
START_TS_MS=$(($(date +%s) * 1000))

yaml_get() {
  awk '/^---$/{c++; if(c==2)exit; next}
       c==1 && /^orchestrator_run_id:/{sub(/^orchestrator_run_id:[[:space:]]*/,""); sub(/[[:space:]]*$/,""); print; exit}' "$TASK_PATH"
}

if [[ "$GET" -eq 1 ]]; then
  yaml_get
  exit 0
fi

# Set mode.
[[ -z "$RUN_ID" || -z "$SOURCE_PERSONA" ]] && { echo "E3: --run-id and --source-persona required to set" >&2; exit 3; }

emit_err() {
  local end=$(($(date +%s) * 1000))
  "$SCRIPT_DIR/emit_telemetry.sh" task_owner error $((end - START_TS_MS)) "$1" "${SOURCE_PERSONA:-unknown}" 2>/dev/null || true
}

if [[ "$SOURCE_PERSONA" != "Executioner" ]]; then
  echo "E4: source_persona must be 'Executioner'; got '$SOURCE_PERSONA'" >&2; emit_err E4; exit 4
fi
if ! "$SCRIPT_DIR/persona_check.sh" "Executioner"; then
  echo "E4: task_owner requires Executioner persona; persona_check failed" >&2; emit_err E4; exit 4
fi

TMP="$(mktemp "$TASK_PATH.XXXXXX")"
trap 'rm -f "$TMP"' EXIT
awk -v rid="$RUN_ID" '
  /^---$/ {
    c++
    if (c == 2 && !done) { print "orchestrator_run_id: " rid; done=1 }
    print
    next
  }
  (c == 1) && /^orchestrator_run_id:/ { print "orchestrator_run_id: " rid; done=1; next }
  { print }
' "$TASK_PATH" > "$TMP"

if ! mv "$TMP" "$TASK_PATH"; then
  echo "E1: failed to write $TASK_PATH" >&2; emit_err E1; exit 1
fi
trap - EXIT

END_TS_MS=$(($(date +%s) * 1000))
"$SCRIPT_DIR/emit_telemetry.sh" task_owner success $((END_TS_MS - START_TS_MS)) null "$SOURCE_PERSONA" 2>/dev/null || true
echo "stamped orchestrator_run_id=$RUN_ID"
exit 0

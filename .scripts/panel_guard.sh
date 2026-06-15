#!/usr/bin/env bash
# panel_guard.sh
#
# Enforces "the failure panel convenes at most ONCE per task per run" (C3, PRD §4.3).
# The panel spends tokens exactly when things are failing, so it must not loop. First
# convene for a (task, run) -> exit 0 (panel MAY convene). Any later convene for the
# same pair -> exit 3 (already spent its one shot -> caller must ESCALATE, not re-panel).
#
# Contract: Tool_Registry.md § panel_guard (registration deferred to Phase C /graduate).
# Persona Gate: any (operational guard). Telemetry: none.
#
# Exit codes:
#   0  may convene (recorded)
#   2  invalid args (E2)
#   3  already convened for this task+run (do not re-panel; escalate)

set -euo pipefail

usage() { echo "Usage: $(basename "$0") --task <name> --run-id <id> [--state-file <path>]"; }

TASK=""; RUN_ID=""; STATE_FILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --task)       TASK="$2"; shift 2 ;;
    --run-id)     RUN_ID="$2"; shift 2 ;;
    --state-file) STATE_FILE="$2"; shift 2 ;;
    -h|--help)    usage; exit 0 ;;
    *)            echo "E2: unknown arg: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -z "$TASK" || -z "$RUN_ID" ]] && { echo "E2: --task and --run-id required" >&2; usage >&2; exit 2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
VAULT_DIR="$(dirname "$SCRIPT_DIR")"
SAFE_RID="${RUN_ID//[^A-Za-z0-9._-]/_}"
STATE_FILE="${STATE_FILE:-$VAULT_DIR/04_Logs/Orchestrator/.panel_convened.$SAFE_RID}"

mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || { echo "E2: cannot create state dir" >&2; exit 2; }

if [[ -f "$STATE_FILE" ]] && grep -qxF "$TASK" "$STATE_FILE"; then
  echo "already-convened: $TASK (run $RUN_ID) — escalate, do not re-panel" >&2
  exit 3
fi

printf '%s\n' "$TASK" >> "$STATE_FILE"
echo "may-convene: $TASK (run $RUN_ID)"
exit 0

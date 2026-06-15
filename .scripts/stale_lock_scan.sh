#!/usr/bin/env bash
# stale_lock_scan.sh
#
# Orphan detector for the Orchestrator (C4, PRD §6). An in_progress, non-epic task
# whose `orchestrator_run_id` is set AND != the live run id is an orphan from a dead
# run — it blocks the project's fetch and must be reconciled. Prints orphan basenames
# (one per line); the tick queues each via queue_attention(orphaned_lock) and NEVER
# force-flips the status (mirrors the /close_task E3 do-not-force rule).
#
# An UNSTAMPED in_progress task is NOT an orphan — it was human-started, not the
# Orchestrator's to reconcile. A task with the live run id is resumable, not orphaned.
#
# Contract: Tool_Registry.md § stale_lock_scan (registration deferred to Phase C /graduate).
# Read-only. Persona Gate: any. Telemetry: none.
#
# Exit codes:
#   0  scan completed (orphans, if any, printed to stdout)
#   2  invalid args / tasks dir missing (E2)

set -euo pipefail

usage() { echo "Usage: $(basename "$0") --project <name> --live-run-id <id> [--tasks-dir <path>]"; }

PROJECT=""; LIVE=""; TASKS_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)     PROJECT="$2"; shift 2 ;;
    --live-run-id) LIVE="$2"; shift 2 ;;
    --tasks-dir)   TASKS_DIR="$2"; shift 2 ;;
    -h|--help)     usage; exit 0 ;;
    *)             echo "E2: unknown arg: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -z "$PROJECT" || -z "$LIVE" ]] && { echo "E2: --project and --live-run-id required" >&2; usage >&2; exit 2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
VAULT_DIR="$(dirname "$SCRIPT_DIR")"
TASKS_DIR="${TASKS_DIR:-$VAULT_DIR/02_Tasks/$PROJECT}"
[[ -d "$TASKS_DIR" ]] || { echo "E2: tasks dir not found: $TASKS_DIR" >&2; exit 2; }

yaml() { # file key
  awk -v k="$2" '/^---$/{c++; if(c==2)exit; next}
                 c==1 && $0 ~ "^" k ":"{sub("^" k ":[[:space:]]*",""); sub(/[[:space:]]*$/,""); print; exit}' "$1"
}

for f in "$TASKS_DIR"/*.md; do
  [[ -e "$f" ]] || continue
  [[ "$(yaml "$f" status)" == "in_progress" ]] || continue
  [[ "$(yaml "$f" type)" == "epic" ]] && continue
  rid="$(yaml "$f" orchestrator_run_id)"
  if [[ -n "$rid" && "$rid" != "$LIVE" ]]; then
    basename "$f" .md
  fi
done
exit 0

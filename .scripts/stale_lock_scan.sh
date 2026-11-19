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
# --route mode: instead of listing orphans, print ONE tab-separated verdict for the
# host project's lock holder (first non-epic in_progress task, same glob order as
# in_progress_lock.sh; if ANY holder is unstamped the verdict is human) so the tick can decide resume vs stop before it fetches:
#   free                              no holder
#   human<TAB><H>                     holder has no orchestrator_run_id (human-owned)
#   escalated<TAB><H><TAB><state>     queue has an open (unchecked) entry for [[H]] whose
#                                     state is not orphaned_lock (only lines after `## Open`)
#   resume<TAB><H><TAB><owner_run_id> otherwise (stamped live or dead)
# Tab-separated because task names may contain spaces. Still read-only, no telemetry.
#
# Contract: Tool_Registry.md § stale_lock_scan (registration deferred to Phase C /graduate).
# Read-only. Persona Gate: any. Telemetry: none.
#
# Exit codes:
#   0  scan completed (orphans, or the --route verdict, printed to stdout)
#   2  invalid args / tasks dir missing (E2)

set -euo pipefail

usage() { echo "Usage: $(basename "$0") --project <name> --live-run-id <id> [--tasks-dir <path>] [--route [--queue-file <path>]]"; }

PROJECT=""; LIVE=""; TASKS_DIR=""; ROUTE=0; QUEUE_FILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)     PROJECT="$2"; shift 2 ;;
    --live-run-id) LIVE="$2"; shift 2 ;;
    --tasks-dir)   TASKS_DIR="$2"; shift 2 ;;
    --route)       ROUTE=1; shift ;;
    --queue-file)  QUEUE_FILE="$2"; shift 2 ;;
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

if [[ "$ROUTE" -eq 1 ]]; then
  QUEUE="${QUEUE_FILE:-$VAULT_DIR/Needs_Attention.md}"
  holders=(); T=$'\t'
  for f in "$TASKS_DIR"/*.md; do
    [[ -e "$f" ]] || continue
    [[ "$(yaml "$f" status)" == "in_progress" ]] || continue
    [[ "$(yaml "$f" type)" == "epic" ]] && continue
    rid="$(yaml "$f" orchestrator_run_id)"
    if [[ -z "$rid" ]]; then
      # Any unstamped holder is human-owned and wins over stamped ones.
      printf 'human\t%s\n' "$(basename "$f" .md)"; exit 0
    fi
    holders+=("$(basename "$f" .md)$T$rid")
  done
  [[ ${#holders[@]} -gt 0 ]] || { printf 'free\n'; exit 0; }
  if [[ -f "$QUEUE" ]]; then
    for h in "${holders[@]}"; do
      name="${h%%"$T"*}"
      # Anchored at line start and literal (index; name via ENVIRON so backslashes
      # survive), first `| state:` token after the task link, so a reason that
      # mentions [[H]] or `| state: x ` cannot spoof it.
      state="$(PRE="- [ ] [[$name]] | state: " awk '/^## Open/{f=1; next}
        f {pre=ENVIRON["PRE"]} f && index($0, pre)==1 {rest=substr($0, length(pre)+1); sub(/ .*/, "", rest);
          if (rest != "orphaned_lock") {print rest; exit}}' "$QUEUE")"
      if [[ -n "$state" ]]; then
        printf 'escalated\t%s\t%s\n' "$name" "$state"; exit 0
      fi
    done
  fi
  holder="${holders[0]%%"$T"*}"; hrid="${holders[0]#*"$T"}"
  printf 'resume\t%s\t%s\n' "$holder" "$hrid"; exit 0
fi

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

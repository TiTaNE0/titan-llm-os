#!/usr/bin/env bash
# write_failure.sh — graceful-failure report for a halted pipeline run (FIX 2c).
# Writes <run-dir>/FAILURE.md: which node failed, why, what completed before it
# (PRESERVED), and how to resume. Called by await_chain.sh on an infra block/timeout,
# and available to a worker's own error path when it can still run a command.
#
# Usage:
#   write_failure.sh --run-dir <abs> --node <name> --reason <text> \
#     [--board <slug>] [--task <id>] [--detail <text>]
# Exit: 0 written · 2 usage error
set -euo pipefail

RUN_DIR=""; NODE=""; REASON=""; BOARD=""; TASK=""; DETAIL=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-dir) RUN_DIR="$2"; shift 2 ;;
    --node)    NODE="$2"; shift 2 ;;
    --reason)  REASON="$2"; shift 2 ;;
    --board)   BOARD="$2"; shift 2 ;;
    --task)    TASK="$2"; shift 2 ;;
    --detail)  DETAIL="$2"; shift 2 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *)         echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$RUN_DIR" && -n "$NODE" && -n "$REASON" ]] || { echo "E2: --run-dir, --node, --reason required" >&2; exit 2; }
[[ -d "$RUN_DIR" ]] || { echo "E2: run-dir not found: $RUN_DIR" >&2; exit 2; }

OUT="$RUN_DIR/FAILURE.md"

# Completed step outputs already on disk — preserved; paid tokens are never lost.
completed=()
for f in "$RUN_DIR"/[0-9][0-9]_*.md; do
  [[ -e "$f" ]] || continue
  completed+=("$(basename "$f")")
done

{
  echo "# RUN FAILED — $NODE"
  echo
  echo "- status: HALTED (chain stopped cleanly at the failed node; downstream did not run)"
  echo "- failed_node: $NODE"
  echo "- reason: $REASON"
  [[ -n "$DETAIL" ]] && echo "- detail: $DETAIL"
  [[ -n "$TASK" ]]   && echo "- failed_task: $TASK"
  [[ -n "$BOARD" ]]  && echo "- board: $BOARD"
  echo "- when: $(date '+%Y-%m-%d %H:%M:%S %z')"
  echo "- run_dir: $RUN_DIR"
  echo
  echo "## Completed before failure (PRESERVED — do not re-run, tokens already spent)"
  if [[ ${#completed[@]} -eq 0 ]]; then
    echo "- (none — failed at or before the first node)"
  else
    for c in "${completed[@]}"; do echo "- $c"; done
  fi
  echo
  echo "## To resume"
  echo "- Inspect the failed node's worker log + the preserved outputs above."
  echo "- Fix the cause (reason: $REASON), then rebuild the DAG from the failed node forward."
  echo "- The preserved outputs above are valid inputs; only the failed node onward needs re-dispatch."
} > "$OUT"

echo "wrote $OUT (failed_node=$NODE reason=$REASON completed=${#completed[@]})"
exit 0

#!/usr/bin/env bash
# telemetry_task_report.sh — per-task agent time vs wall-clock from telemetry.
#
# Usage: telemetry_task_report.sh [--task <name>]
# Reads ${TELEMETRY_DIR:-<vault>/04_Logs/Telemetry}/*.jsonl (malformed lines
# skipped). Read-only; writes no files and emits no telemetry.
# CSV: task,rows,agent_ms,wall_ms,excluded
#   agent_ms = sum of plausible invoke_* durations
#   wall_ms  = max(ts) - min(ts - duration) over plausible rows
#   excluded = rows with implausible duration ([0, 86400000] required)
# Exit: 0 ok, 1 bad usage, 2 jq missing.

set -uo pipefail

usage() { echo "usage: telemetry_task_report.sh [--task <name>]" >&2; exit 1; }

ONLY=""
case "$#" in
  0) ;;
  2) [ "$1" = "--task" ] || usage; ONLY="$2" ;;
  *) usage ;;
esac

command -v jq >/dev/null 2>&1 || { echo "jq required" >&2; exit 2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIR="${TELEMETRY_DIR:-$SCRIPT_DIR/../04_Logs/Telemetry}"

OUT="$(
  for f in "$DIR"/*.jsonl; do [ -f "$f" ] && cat "$f"; done 2>/dev/null \
  | jq -R -c 'fromjson?' \
  | jq -s -r --arg only "$ONLY" '
    def plausible: (.duration_ms | type) == "number" and .duration_ms >= 0 and .duration_ms <= 86400000;
    def tsms: try ((.ts | fromdateiso8601) * 1000) catch null;
    [ .[] | select(type == "object" and (.task | type) == "string")
          | select($only == "" or .task == $only) ]
    | group_by(.task)
    | map(
        . as $rows
        | [ $rows[] | select(plausible) ] as $ok
        | [ $ok[] | . + {t: tsms} | select(.t != null) ] as $timed
        | ( [ $rows[0].task,
            ($rows | length),
            ([ $ok[] | select(.macro | startswith("invoke_")) | .duration_ms ] | add // 0),
            (if ($timed | length) == 0 then 0
             else (([ $timed[].t ] | max) - ([ $timed[] | .t - .duration_ms ] | min)) end),
            (($rows | length) - ($ok | length)) ] | map(tostring) | join(","))
      )
    | .[]
  ' 2>/dev/null
)"

if [ -z "$OUT" ]; then
  echo "(no task-attributed telemetry)"
else
  echo "task,rows,agent_ms,wall_ms,excluded"
  printf '%s\n' "$OUT"
fi
exit 0

#!/usr/bin/env bash
# telemetry_task_report.sh — per-task agent time vs wall-clock from telemetry.
#
# Usage: telemetry_task_report.sh [--task <name> [--since <ISO-UTC>]]
# Reads ${TELEMETRY_DIR:-<vault>/04_Logs/Telemetry}/*.jsonl (malformed lines
# skipped). Read-only; writes no files and emits no telemetry.
# CSV: task,rows,agent_ms,wall_ms,excluded (fields RFC 4180-quoted when needed)
#   agent_ms = sum of plausible invoke_* durations
#   wall_ms  = max(ts) - min(ts - duration) over plausible rows
#   excluded = rows with implausible duration ([0, 86400000] required)
# --since <YYYY-MM-DDTHH:MM:SSZ> (requires --task): instead of the CSV prints exactly
#   agent_time_ms: <sum of plausible duration_ms>
#   zero_duration_rows: <counted rows with duration_ms == 0>
# over rows for the task whose macro is invoke_* or spec_gate and ts >= since.
# Exit: 0 ok, 1 bad usage, 2 jq missing, 3 no rows in --since mode.

set -uo pipefail

usage() { echo "usage: telemetry_task_report.sh [--task <name> [--since <ISO-UTC>]]" >&2; exit 1; }

ONLY=""; SINCE=""; HAVE_TASK=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --task)  [ "$#" -ge 2 ] || usage; ONLY="$2"; HAVE_TASK=1; shift 2 ;;
    --since) [ "$#" -ge 2 ] || usage; SINCE="$2"; shift 2 ;;
    *) usage ;;
  esac
done
if [ -n "$SINCE" ]; then
  [ "$HAVE_TASK" = 1 ] || usage
  printf '%s' "$SINCE" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' || usage
fi

command -v jq >/dev/null 2>&1 || { echo "jq required" >&2; exit 2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIR="${TELEMETRY_DIR:-$SCRIPT_DIR/../04_Logs/Telemetry}"

if [ -n "$SINCE" ]; then
  SOUT="$(
    for f in "$DIR"/*.jsonl; do [ -f "$f" ] && cat "$f"; done 2>/dev/null \
    | jq -R -c 'fromjson?' \
    | jq -s -r --arg only "$ONLY" --arg since "$SINCE" '
      [ .[] | select(type == "object" and .task == $only
                     and (.macro | type) == "string"
                     and ((.macro | startswith("invoke_")) or .macro == "spec_gate")
                     and (.ts | type) == "string" and .ts >= $since) ] as $rows
      | if ($rows | length) == 0 then empty
        else
          [ $rows[] | select((.duration_ms | type) == "number" and .duration_ms >= 0 and .duration_ms <= 86400000) ] as $ok
          | "agent_time_ms: \([ $ok[].duration_ms ] | add // 0)",
            "zero_duration_rows: \([ $rows[] | select(.duration_ms == 0) ] | length)"
        end
    ' 2>/dev/null
  )"
  if [ -z "$SOUT" ]; then
    echo "no telemetry rows for $ONLY since $SINCE" >&2
    exit 3
  fi
  printf '%s\n' "$SOUT"
  exit 0
fi

OUT="$(
  for f in "$DIR"/*.jsonl; do [ -f "$f" ] && cat "$f"; done 2>/dev/null \
  | jq -R -c 'fromjson?' \
  | jq -s -r --arg only "$ONLY" '
    def plausible: (.duration_ms | type) == "number" and .duration_ms >= 0 and .duration_ms <= 86400000;
    def csvq: if test("[,\"\\n\\r]") then "\"" + gsub("\""; "\"\"") + "\"" else . end;
    def tsms: try ((.ts | fromdateiso8601) * 1000) catch null;
    [ .[] | select(type == "object" and (.task | type) == "string")
          | select($only == "" or .task == $only) ]
    | group_by(.task)
    | map(
        . as $rows
        | [ $rows[] | select(plausible) ] as $ok
        | [ $ok[] | . + {t: tsms} | select(.t != null) ] as $timed
        | ( [ ($rows[0].task | csvq),
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

#!/usr/bin/env bash
# cli_stub.sh — offline stand-in for grok, agy and the daily-log script in the v3.2 tests.
#
# Every call is appended to $STUB_DIR/cli_calls.log. The role is read from the arguments:
#   --source-persona present      daily log (append_log.sh): arguments go to $STUB_DIR/alarm_args.log
#   first argument "models"       agy models: prints the rung names given in $STUB_AGY_MODELS (|-separated)
#   --model NAME present          agy probe: counted in agy.count; a NAME listed in $STUB_AGY_DEAD fails,
#                                 any other answers with a fenced json block
#   anything else                 grok: counted in grok.count; STUB_GROK=ok (default) answers with a
#                                 fenced json block, dead exits 1, balance prints the 402 answer
set -uo pipefail
D="${STUB_DIR:?cli_stub: STUB_DIR not set}"
mkdir -p "$D"
printf '%s\n' "$*" >> "$D/cli_calls.log"
bump() { local n; n=$(cat "$D/$1" 2>/dev/null || echo 0); echo $((n+1)) > "$D/$1"; }
fenced() { printf 'Here you go.\n```json\n{"probe": "ok"}\n```\n'; }
args=("$@")
for a in "${args[@]}"; do
  if [ "$a" = "--source-persona" ]; then printf '%s\n' "$*" >> "$D/alarm_args.log"; exit 0; fi
done
if [ "${1:-}" = "models" ]; then
  IFS='|' read -ra M <<<"${STUB_AGY_MODELS:-}"; for m in "${M[@]}"; do echo "$m"; done; exit 0
fi
for ((i=0; i<${#args[@]}; i++)); do
  if [ "${args[i]}" = "--model" ]; then
    name="${args[i+1]:-}"; bump agy.count
    IFS='|' read -ra DEAD <<<"${STUB_AGY_DEAD:-}"
    for d in "${DEAD[@]}"; do [ "$d" = "$name" ] && { echo "error: model $name unavailable" >&2; exit 1; }; done
    fenced; exit 0
  fi
done
bump grok.count
case "${STUB_GROK:-ok}" in
  ok) fenced ;;
  dead) echo "grok: connection refused" >&2; exit 1 ;;
  balance) echo "Error: 402 Payment Required: Grok Build usage balance exhausted"; exit 1 ;;
esac
exit 0

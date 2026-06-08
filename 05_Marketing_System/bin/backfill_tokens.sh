#!/usr/bin/env bash
# backfill_tokens.sh — write REAL per-step token counts into a trace file (closes the §11 cost gap).
#
# The kanban worker for a step runs as a Hermes session whose token usage is recorded in that
# profile's state.db. This script: task_id -> kanban run's worker_session_id + profile ->
# state.db (input_tokens/output_tokens) -> overwrites the `tokens_in/out: 0` placeholders in the
# step's trace file. Run AFTER the step completes (the session totals are final only then).
#
# Usage: backfill_tokens.sh --trace <abs trace .md> --task <task_id> [--board <slug>]
# Exit 0 always (cost instrumentation must never halt a run). Prints what it wrote.
#
# NOTE: a node that itself spawns nested `-z` sub-calls (e.g. the debate node running
# debate_loop.sh) accrues most of its tokens in those CHILD sessions; this captures the
# worker session only. Single-session nodes (scout/strategist/creator/gatekeeper/judge/producer
# reasoning) are captured exactly.
set -uo pipefail

TRACE=""; TASK=""; BOARD="intuiscale"; PB="$HOME/.hermes/profiles"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --trace) TRACE="$2"; shift 2 ;;
    --task)  TASK="$2"; shift 2 ;;
    --board) BOARD="$2"; shift 2 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "unknown: $1" >&2; exit 2 ;;
  esac
done
[[ -f "$TRACE" && -n "$TASK" ]] || { echo "E2: --trace <file> --task <id> required" >&2; exit 0; }

J="$(hermes kanban --board "$BOARD" runs "$TASK" --json 2>/dev/null)"
read SID PROF < <(printf '%s' "$J" | python3 -c "
import json,sys
try: r=[x for x in json.load(sys.stdin) if x.get('outcome')=='completed']
except Exception: r=[]
print((r[0]['metadata'].get('worker_session_id','') if r else ''),(r[0].get('profile','') if r else ''))
" 2>/dev/null)
[[ -n "${SID:-}" && -n "${PROF:-}" ]] || { echo "backfill: no completed session for $TASK (skip)" >&2; exit 0; }

DB="$PB/$PROF/state.db"
TOKS="$(sqlite3 "$DB" "SELECT input_tokens, output_tokens FROM sessions WHERE id='$SID';" 2>/dev/null)"
TIN="${TOKS%%|*}"; TOUT="${TOKS##*|}"
[[ -n "${TIN:-}" && "$TIN" != "$TOUT" || -n "${TIN:-}" ]] || { echo "backfill: no tokens for $SID (skip)" >&2; exit 0; }
[[ -n "${TIN:-}" ]] || { echo "backfill: empty token row for $SID (skip)" >&2; exit 0; }

perl -pi -e "s/^(- tokens_in:)[ \t]*0[ \t]*\$/\$1 $TIN/; s/^(- tokens_out:)[ \t]*0[ \t]*\$/\$1 $TOUT/" "$TRACE"
echo "backfilled $(basename "$TRACE"): tokens_in=$TIN tokens_out=$TOUT  ($PROF / $SID)"
exit 0

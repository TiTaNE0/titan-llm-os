#!/usr/bin/env bash
# gatekeeper_decide.sh — Viability Gatekeeper gate that ENFORCES the kill (PRD §8.8; closes GAP-2).
#
# PASS (score >= threshold): print PASS, exit 0 — chain continues to the debate loop.
# KILL (score <  threshold): append a DECISIONS kill row AND block the named downstream
#   kanban tasks so the expensive steps (debate/judge/producer) never spawn. exit 10.
#   This is the 40-70% cost lever: a killed concept must not reach frontier tokens.
#
# Usage:
#   gatekeeper_decide.sh --score <0..1> [--threshold 0.55] \
#     --decisions <abs DECISIONS.md> [--concept <text>] [--run <run_id>] \
#     [--board <slug>] [--block <taskid>]...
#
# Product-agnostic: campaign/board/downstream are all passed in.
# Exit: 0 pass · 10 kill (downstream blocked) · 2 usage error
set -euo pipefail

SCORE=""; THRESHOLD="0.55"; DECISIONS=""; CONCEPT="concept"; RUN="-"; BOARD=""
BLOCK_IDS=()
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --score)     SCORE="$2"; shift 2 ;;
    --threshold) THRESHOLD="$2"; shift 2 ;;
    --decisions) DECISIONS="$2"; shift 2 ;;
    --concept)   CONCEPT="$2"; shift 2 ;;
    --run)       RUN="$2"; shift 2 ;;
    --board)     BOARD="$2"; shift 2 ;;
    --block)     BLOCK_IDS+=("$2"); shift 2 ;;
    -h|--help)   sed -n '2,20p' "$0"; exit 0 ;;
    *)           echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$SCORE" && -n "$DECISIONS" ]] || { echo "E2: --score and --decisions required" >&2; exit 2; }

# Float compare (awk): pass when score >= threshold.
pass=$(awk -v s="$SCORE" -v t="$THRESHOLD" 'BEGIN { print (s+0 >= t+0) ? 1 : 0 }')

if [[ "$pass" == "1" ]]; then
  echo "PASS [gatekeeper]: score=$SCORE >= threshold=$THRESHOLD — enter debate loop"
  exit 0
fi

# ---- KILL path: log + enforce by blocking downstream ----
"$SCRIPT_DIR/safe_append.sh" --file "$DECISIONS" \
  --entry "| $RUN | $(date +%F) | $CONCEPT | killed | gatekeeper | score below $THRESHOLD | $SCORE |" \
  >/dev/null 2>&1 || echo "warn: DECISIONS append failed" >&2

blocked=()
for id in "${BLOCK_IDS[@]:-}"; do
  [[ -z "$id" ]] && continue
  if [[ -n "$BOARD" ]]; then
    if hermes kanban --board "$BOARD" block "$id" "gatekeeper kill: score $SCORE < $THRESHOLD" >/dev/null 2>&1; then
      blocked+=("$id")
    fi
  fi
done

echo "KILL [gatekeeper]: score=$SCORE < threshold=$THRESHOLD — DECISIONS logged; blocked downstream: ${blocked[*]:-none}"
exit 10

#!/usr/bin/env bash
set -euo pipefail

# gate.sh — numeric gate for Gatekeeper viability and Judge scores.
# PASS when score >= threshold; otherwise KILL/LOOP.
# Float comparison via awk. Exit 0 = PASS, exit 10 = below threshold.

usage() {
  cat <<'EOF'
Usage: gate.sh --score <0..1> --threshold <0..1> --label <text>

Compare a 0..1 score against a 0..1 threshold and print the decision line.

Exit codes:
  0   score >= threshold (PASS)
  10  score <  threshold (KILL / LOOP)
  2   usage / invalid number
EOF
}

SCORE=""
THRESHOLD=""
LABEL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --score)     SCORE="${2:-}"; shift 2 ;;
    --threshold) THRESHOLD="${2:-}"; shift 2 ;;
    --label)     LABEL="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [ -z "$SCORE" ] || [ -z "$THRESHOLD" ] || [ -z "$LABEL" ]; then
  echo "error: --score, --threshold and --label are required" >&2
  usage >&2
  exit 2
fi

is_num() { printf '%s' "$1" | grep -Eq '^[0-9]+(\.[0-9]+)?$'; }
if ! is_num "$SCORE" || ! is_num "$THRESHOLD"; then
  echo "error: --score and --threshold must be numbers in [0,1]" >&2
  exit 2
fi
if awk -v s="$SCORE" 'BEGIN{exit !(s<0||s>1)}'; then
  echo "error: --score out of range [0,1]: $SCORE" >&2; exit 2
fi
if awk -v t="$THRESHOLD" 'BEGIN{exit !(t<0||t>1)}'; then
  echo "error: --threshold out of range [0,1]: $THRESHOLD" >&2; exit 2
fi

if awk -v s="$SCORE" -v t="$THRESHOLD" 'BEGIN{exit !(s>=t)}'; then
  echo "PASS [$LABEL]: score=$SCORE >= threshold=$THRESHOLD"
  exit 0
else
  echo "KILL/LOOP [$LABEL]: score=$SCORE < threshold=$THRESHOLD"
  exit 10
fi

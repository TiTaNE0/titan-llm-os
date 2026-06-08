#!/usr/bin/env bash
set -euo pipefail

# break_check.sh — Scout verdict gate (human gate #1).
# ALIGNED/DRIFT continue; BREAK halts the pipeline + signals operator notify.
# Exit 0 = continue, exit 20 = BREAK (skill HALTs + notifies on 20).

usage() {
  cat <<'EOF'
Usage: break_check.sh --verdict <ALIGNED|DRIFT|BREAK>

Gate the pipeline on the Scout trend verdict.

Exit codes:
  0   ALIGNED or DRIFT (continue)
  20  BREAK (HALT + notify operator — human gate #1)
  2   usage / invalid verdict
EOF
}

VERDICT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --verdict) VERDICT="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [ -z "$VERDICT" ]; then
  echo "error: --verdict is required" >&2
  usage >&2
  exit 2
fi

# Normalize to uppercase for comparison.
V="$(printf '%s' "$VERDICT" | tr '[:lower:]' '[:upper:]')"

case "$V" in
  ALIGNED|DRIFT)
    echo "CONTINUE: verdict=$V"
    exit 0
    ;;
  BREAK)
    echo "BREAK: verdict=$V — HALT pipeline + notify operator (human gate #1)"
    exit 20
    ;;
  *)
    echo "error: invalid verdict '$VERDICT' (expected ALIGNED|DRIFT|BREAK)" >&2
    exit 2
    ;;
esac

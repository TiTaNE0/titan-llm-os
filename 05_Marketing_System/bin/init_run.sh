#!/usr/bin/env bash
# init_run.sh — allocate the next per-run trace folder for a marketing campaign.
# Usage: init_run.sh --campaign <abs campaign dir>
# Prints the absolute run-dir path on stdout (and NOTHING else). PRD §11.
# Product-agnostic: the campaign dir is passed in; framework lives elsewhere.
set -euo pipefail

CAMPAIGN=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --campaign) CAMPAIGN="$2"; shift 2 ;;
    -h|--help)  echo "Usage: $(basename "$0") --campaign <abs campaign dir>"; exit 0 ;;
    *)          echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

[ -n "$CAMPAIGN" ] || { echo "E2: --campaign <dir> required" >&2; exit 2; }
[ -d "$CAMPAIGN" ] || { echo "E2: campaign dir not found: $CAMPAIGN" >&2; exit 2; }

RUNS_DIR="${CAMPAIGN}/runs"
DATE="$(date +%Y-%m-%d)"
mkdir -p "${RUNS_DIR}"

# Highest existing NN for today, then increment. Empty runs/ => 01.
next=1
for d in "${RUNS_DIR}/${DATE}_run"[0-9][0-9]; do
  [ -d "$d" ] || continue
  nn="${d##*_run}"; nn="$((10#${nn}))"
  if [ "${nn}" -ge "${next}" ]; then next="$((nn + 1))"; fi
done

RUN_DIR="$(printf '%s/%s_run%02d' "${RUNS_DIR}" "${DATE}" "${next}")"
mkdir -p "${RUN_DIR}"
printf '%s\n' "${RUN_DIR}"

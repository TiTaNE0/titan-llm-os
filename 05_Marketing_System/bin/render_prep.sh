#!/usr/bin/env bash
# render_prep.sh — everything the image-gen agent needs BEFORE it generates:
# (1) render_manifest.json + GENERATE.md, then (2) the Remotion UI screenshots
# (in model-fuse mode these are GENERATION INPUTS the agent attaches as references).
# Run this, then point Antigravity / Gemini CLI at the run's GENERATE.md.
#
# Usage: render_prep.sh --draft <abs draft .md> --campaign <abs campaign dir> [--screen-mode model-fuse|python-warp]
# Exit: 0 success · non-zero on a failed stage
set -uo pipefail
BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

DRAFT=""; CAMPAIGN=""; SCREEN_MODE="model-fuse"; REMOTION="/Users/titane0/AI_Workflow/remotion"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --draft)       DRAFT="$2"; shift 2 ;;
    --campaign)    CAMPAIGN="$2"; shift 2 ;;
    --screen-mode) SCREEN_MODE="$2"; shift 2 ;;
    --remotion)    REMOTION="$2"; shift 2 ;;
    -h|--help)     sed -n '2,11p' "$0"; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done
[[ -n "$DRAFT" && -n "$CAMPAIGN" ]] || { echo "E2: --draft and --campaign required" >&2; exit 2; }

echo "== stage 0: manifest + GENERATE.md (screen-mode=$SCREEN_MODE) =="
OUT="$("$BIN/render_manifest.sh" --draft "$DRAFT" --campaign "$CAMPAIGN" --screen-mode "$SCREEN_MODE")"
MANIFEST="$(echo "$OUT" | sed -n 1p)"; GUIDE="$(echo "$OUT" | sed -n 2p)"
RUN_DIR="$(dirname "$MANIFEST")"
echo "  manifest: $MANIFEST"
echo "  runbook : $GUIDE"

echo "== stage 1: Remotion UI screenshots (generation inputs in model-fuse) =="
bash "$BIN/render_ui.sh" --run-dir "$RUN_DIR" --remotion "$REMOTION"

echo
echo "== prep done =="
echo "Next: point Antigravity / Gemini CLI at the runbook, then run render_run.sh:"
echo "  $GUIDE"
echo "  bash 05_Marketing_System/bin/render_run.sh --run-dir \"$RUN_DIR\""

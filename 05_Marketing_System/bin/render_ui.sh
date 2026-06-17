#!/usr/bin/env bash
# render_ui.sh — stage 2 of the render pipeline. For every manifest slide that
# carries a `ui` block, render that crisp UI screenshot with Remotion (props
# passed per slide; the composition is the generic render-kit one, never forked).
# Writes PNGs into the run's ui/ dir. Renders no photos, composites nothing.
#
# Usage: render_ui.sh --run-dir <abs run dir> [--remotion <abs remotion project>]
# Exit: 0 success · 2 usage · 3 remotion missing
set -euo pipefail

RUN_DIR=""; REMOTION="/Users/titane0/AI_Workflow/remotion"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-dir)  RUN_DIR="$2"; shift 2 ;;
    --remotion) REMOTION="$2"; shift 2 ;;
    -h|--help)  sed -n '2,9p' "$0"; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done
[[ -n "$RUN_DIR" ]] || { echo "E2: --run-dir required" >&2; exit 2; }
MANIFEST="$RUN_DIR/render_manifest.json"
[[ -f "$MANIFEST" ]] || { echo "E2: no render_manifest.json in $RUN_DIR (run render_manifest.sh first)" >&2; exit 2; }
[[ -d "$REMOTION/node_modules/remotion" ]] || { echo "E3: remotion project not found at $REMOTION" >&2; exit 3; }
command -v jq >/dev/null 2>&1 || { echo "E2: jq required" >&2; exit 2; }

mkdir -p "$RUN_DIR/ui"
ENTRY="src/index.ts"
LOG="$RUN_DIR/ui/.render_ui.log"
: > "$LOG"
count=0

# warm the Remotion bundle once (cold bundling inside the per-slide call is flaky);
# a warm bundle makes each `still` fast + reliable.
echo "Warming Remotion bundle..."
( cd "$REMOTION" && npx remotion compositions "$ENTRY" >>"$LOG" 2>&1 ) || echo "  (bundle warm step returned nonzero — continuing; see $LOG)" >&2

render_one(){ # $1=comp $2=propfile $3=out
  ( cd "$REMOTION" && npx remotion still "$ENTRY" "$1" "$3" --props="$2" --overwrite >>"$LOG" 2>&1 )
}

# iterate slides that have a ui block
while IFS=$'\t' read -r n comp text uifile; do
  [[ -n "$comp" ]] || continue
  out="$RUN_DIR/$uifile"
  propfile="$(mktemp -t remprops.XXXXXX.json)"
  jq -n --arg t "$text" '{ appName: "Recipes", title: "Tonight", text: $t }' > "$propfile"
  echo "Rendering UI slide $n ($comp) -> $uifile"
  render_one "$comp" "$propfile" "$out" || true
  if [[ ! -f "$out" ]]; then
    echo "  retry slide $n (bundle now warm)..."
    render_one "$comp" "$propfile" "$out" || true
  fi
  rm -f "$propfile"
  if [[ -f "$out" ]]; then
    count=$((count+1))
  else
    echo "  WARN: remotion still failed for slide $n — see $LOG (or run: cd $REMOTION && npx remotion still $ENTRY $comp <out> --props=...)" >&2
  fi
done < <(jq -r '.slides[] | select(.ui != null) | [(.n|tostring), .ui.component, .ui.text, .ui.file] | @tsv' "$MANIFEST")

echo "render_ui.sh: rendered $count UI screenshot(s) into $RUN_DIR/ui/"

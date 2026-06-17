#!/usr/bin/env bash
# render_run.sh — the post-generation step: fuse the generated base photos (assets/)
# into final captioned slides (composed/) + a contact sheet. Run AFTER the image-gen
# agent has produced assets/slide_<n>_base.png per the run's GENERATE.md.
#
# In model-fuse runs the UI is already painted into the photos, so this only burns
# captions. In python-warp runs it also chroma-keys + warps the Remotion UI (already
# in ui/ from render_prep.sh) onto the flat #FF00FF screens.
#
# Usage: render_run.sh --run-dir <abs run dir>
# Exit: 0 all composed · non-zero if a slide failed
set -uo pipefail
BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

RUN_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-dir) RUN_DIR="$2"; shift 2 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done
[[ -n "$RUN_DIR" ]] || { echo "E2: --run-dir required" >&2; exit 2; }
MANIFEST="$RUN_DIR/render_manifest.json"
[[ -f "$MANIFEST" ]] || { echo "E2: no render_manifest.json — run render_prep.sh first" >&2; exit 2; }

# preflight: warn about missing base photos (agent stage not complete)
missing="$(jq -r '.slides[] | .base.file' "$MANIFEST" | while read -r f; do [[ -f "$RUN_DIR/$f" ]] || echo "$f"; done)"
if [[ -n "$missing" ]]; then
  echo "WARNING: base photos missing (agent generation not complete):" >&2
  echo "$missing" | sed 's/^/  - /' >&2
fi

# python-warp runs need the UI screenshots present; remind if absent
if [[ "$(jq -r '.screen_mode' "$MANIFEST")" == "python-warp" ]]; then
  jq -r '.slides[] | select(.ui != null) | .ui.file' "$MANIFEST" | while read -r u; do
    [[ -f "$RUN_DIR/$u" ]] || echo "WARNING: python-warp needs $u — run render_prep.sh (or render_ui.sh) first" >&2
  done
fi

echo "== fuse (screen_mode=$(jq -r '.screen_mode' "$MANIFEST")) =="
python3 "$BIN/fuse_slides.py" --run-dir "$RUN_DIR"
rc=$?
echo "composed slides: $RUN_DIR/composed/"
exit $rc

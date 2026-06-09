#!/usr/bin/env bash
# render_asset.sh — render an aurora-frost HTML card to a ready-to-attach PNG.
#
# Prefers Playwright (tight element screenshot of .card, crisp @2x); falls back to
# headless Chrome/Chromium/Brave, then wkhtmltoimage; if none, prints a manual hint
# and exits 3 (graceful — the caller keeps the HTML and notes "open + screenshot").
#
# Usage: render_asset.sh <input.html> <output.png> [WxH]   (default 1200x1500)
set -uo pipefail

in="${1:?usage: render_asset.sh <input.html> <output.png> [WxH]}"
out="${2:?usage: render_asset.sh <input.html> <output.png> [WxH]}"
dims="${3:-1200x1500}"; W="${dims%x*}"; H="${dims#*x}"
abs_in="$(cd "$(dirname "$in")" && pwd)/$(basename "$in")"

# 1) Playwright (python) — element-tight screenshot of the card, lets fonts settle
if python3 -c "import playwright" >/dev/null 2>&1; then
  python3 - "$abs_in" "$out" "$W" "$H" 2>/dev/null <<'PY' && { echo "rendered (playwright): $out"; exit 0; }
import sys
from playwright.sync_api import sync_playwright
inp, out, w, h = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
with sync_playwright() as p:
    b = p.chromium.launch()
    pg = b.new_page(viewport={"width": w, "height": h}, device_scale_factor=2)
    pg.goto("file://" + inp)
    pg.wait_for_timeout(1500)            # let Geist / Instrument Serif load
    el = pg.query_selector("article.card") or pg.query_selector("body")
    (el or pg).screenshot(path=out)      # element crop = no stray background
    b.close()
PY
fi

# Past the Playwright path → any fallback below is full-page, NOT a tight .card crop. Warn loudly
# so a wrong crop is never silent (this is what bit the 9f run).
echo "render_asset.sh WARNING: Playwright unavailable — using a full-page fallback; the card is NOT tight-cropped. For the .card crop, install it once: pip install playwright --break-system-packages && python3 -m playwright install chromium" >&2

# 2) headless Chrome / Chromium / Brave (full viewport)
for c in google-chrome chromium chromium-browser \
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  "/Applications/Chromium.app/Contents/MacOS/Chromium" \
  "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"; do
  if command -v "$c" >/dev/null 2>&1 || [ -x "$c" ]; then
    "$c" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=2 \
      --virtual-time-budget=3000 --window-size="${W},${H}" \
      --screenshot="$out" "file://$abs_in" >/dev/null 2>&1 \
      && { echo "rendered (chrome): $out"; exit 0; }
  fi
done

# 3) wkhtmltoimage
if command -v wkhtmltoimage >/dev/null 2>&1; then
  wkhtmltoimage --width "$W" "$abs_in" "$out" >/dev/null 2>&1 \
    && { echo "rendered (wkhtmltoimage): $out"; exit 0; }
fi

# 4) nothing available
echo "render_asset.sh: no headless renderer found. Open '$abs_in' in a browser and screenshot the card, OR install one: pip install playwright && playwright install chromium (or install Google Chrome)." >&2
exit 3

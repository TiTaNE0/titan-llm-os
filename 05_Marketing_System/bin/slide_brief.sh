#!/usr/bin/env bash
# slide_brief.sh — emit the Path B generation brief from a Producer slideshow draft:
# one full-frame image per slide, all locked to a single ANCHOR reference image, with
# captions overlaid after. Ship-today route (no cutout, no compositor). Generates nothing.
# Path A (asset_prompt.sh -> visual_identity.json -> compositor) is the separate, preserved route.
#
# Usage: slide_brief.sh --draft <abs draft .md> --campaign <abs campaign dir>
# Exit: 0 success · 2 usage · 3 unsupported approach · 4 malformed draft
#
# Input: the Producer's `## Slide Brief` fenced-json block (anchor + clean per-slide scenes),
# plus slide_copy (captions) and `## Asset Inventory` template-method assets (UI/digit overlays).
# This script OWNS: shared look line (fused from scout SC_MODE/SC_COLOR), reference wiring,
# caption pairing, overlay notes. The Producer supplies anchor + rationale-free scenes only.
set -euo pipefail

DRAFT=""; CAMPAIGN=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --draft)    DRAFT="$2"; shift 2 ;;
    --campaign) CAMPAIGN="$2"; shift 2 ;;
    -h|--help)  sed -n '2,9p' "$0"; exit 0 ;;
    *)          echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done
[[ -n "$DRAFT" && -n "$CAMPAIGN" ]] || { echo "E2: --draft and --campaign required" >&2; exit 2; }
[[ -f "$DRAFT" ]] || { echo "E2: draft not found: $DRAFT" >&2; exit 2; }
[[ -d "$CAMPAIGN" ]] || { echo "E2: campaign dir not found: $CAMPAIGN" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "E2: jq required" >&2; exit 2; }

# ---- frontmatter: module -> approach · run -> run dir · piece_id, caption ----
fm(){ awk '/^---$/{c++; next} c==1{print} c==2{exit}' "$DRAFT"; }
MODULE="$(fm | grep -m1 '^module:' | sed 's/^module:[[:space:]]*//; s/[",'"'"' ]//g' || true)"
[[ -n "$MODULE" ]] || { echo "E2: draft has no module: frontmatter (usage)" >&2; exit 2; }
APPROACH="${MODULE##*__}"
case "$APPROACH" in
  faceless) : ;;
  ugc-ai-character) echo "ugc-ai-character route not built (§8.7)" >&2; exit 3 ;;
  *) echo "unknown approach: $APPROACH" >&2; exit 3 ;;
esac
RUN="$(fm | grep -m1 '^run:' | sed 's/^run:[[:space:]]*//; s/[",'"'"' ]//g' || true)"
PIECE="$(fm | grep -m1 '^piece_id:' | sed 's/^piece_id:[[:space:]]*//; s/[",'"'"' ]//g' || true)"
RUN_DIR="$CAMPAIGN/runs/$RUN"; [[ -d "$RUN_DIR" ]] || RUN_DIR="$CAMPAIGN"

# ---- parse the `## Slide Brief` fenced-json block (anchor + clean per-slide scenes) ----
brief_block(){ awk '
  /^## Slide Brief/{s=1; next}
  s && /^```json/{f=1; next}
  s && f && /^```/{exit}
  f{print}
' "$DRAFT"; }
BRIEF_JSON="$(brief_block)"
[[ -n "$BRIEF_JSON" ]] || { echo "E4: no '## Slide Brief' fenced-json block in draft" >&2; exit 4; }
echo "$BRIEF_JSON" | jq -e '
  (.anchor|type=="number") and (.slides|type=="object") and (.slides|length>0)
  and (.setting|type=="string") and ((.setting|length)>0)
  and ((.slides|keys) as $k | (.anchor|tostring) as $a | ($k|index($a)) != null)
' >/dev/null 2>&1 \
  || { echo "E4: Slide Brief invalid (need non-empty .setting [GLOBAL RULE], numeric .anchor that is one of .slides keys, non-empty .slides)" >&2; exit 4; }

# ---- Asset Inventory template-method assets -> UI/digit overlay notes (Path A data, reused) ----
asset_block(){ awk '
  /^## Asset Inventory/{s=1; next}
  s && /^```json/{f=1; next}
  s && f && /^```/{exit}
  f{print}
' "$DRAFT"; }
ASSET_JSON="$(asset_block || true)"

# ---- scout look tokens (native pattern LEADS) -> shared look line owned by this script ----
SCOUT="$RUN_DIR/00_scout.md"
vp(){ [[ -f "$SCOUT" ]] || return 0; grep -m1 "^- $1:" "$SCOUT" 2>/dev/null | sed "s/^- $1:[[:space:]]*//;s/[[:space:]]*\$//" || true; }
SC_MODE="$(vp mode | sed 's/ —.*//')";               [[ -n "$SC_MODE" ]]  || SC_MODE='real-photo phone-shot candid grain'
SC_COLOR="$(vp color_temperature | sed 's/ —.*//')"; [[ -n "$SC_COLOR" ]] || SC_COLOR='warm natural'
SHARED_LOOK="$SC_MODE, $SC_COLOR color, matte off-white tones, 9:16 vertical, no text, no words, no faces, no people visible"

ANCHOR="$(echo "$BRIEF_JSON" | jq -r '.anchor')"
SETTING="$(echo "$BRIEF_JSON" | jq -r '.setting')"
SLIDES="$(echo "$BRIEF_JSON" | jq -r '.slides | keys | map(tonumber) | sort | .[]')"
CAPTION="$(grep -m1 '^- caption:' "$DRAFT" | sed 's/^- caption:[[:space:]]*//' || true)"
DATE="$(date +%Y-%m-%d)"
SRC_REL="drafts/$(basename "$DRAFT")"
OUT="$RUN_DIR/08_generation_brief.md"

scene(){ echo "$BRIEF_JSON" | jq -r --arg n "$1" '.slides[$n]'; }
# self-contained, ready-to-paste prompt = scene + mandatory setting anchor + shared look (GLOBAL RULE)
prompt(){ printf '%s. Setting: %s %s' "$(scene "$1")" "$SETTING" "$SHARED_LOOK"; }
# caption N from the slide_copy numbered list (strip leading "  N. " and wrapping quotes)
cap(){ awk -v n="$1" '
  $0 ~ "^- slide_copy:"{f=1; next}
  f && /^- [a-z_]+:/{f=0}
  f && $0 ~ ("^[[:space:]]*"n"\\.")  { sub("^[[:space:]]*"n"\\.[[:space:]]*",""); sub(/^"/,""); sub(/"[[:space:]]*$/,""); print; exit }
' "$DRAFT"; }

{
  echo "---"
  echo "type: generation-brief"
  echo "path: Path B — full-slide, anchor-locked (ship-today; no compositor)"
  echo "draft: $SRC_REL"
  echo "campaign: Intuiscale"
  echo "anchor_slide: $ANCHOR"
  echo "generated_by: slide_brief.sh"
  echo "generated_at: $DATE"
  echo "note: >"
  echo "  Path A (atomic assets -> cutout -> compositor; visual_identity.json) is the separate"
  echo "  preserved route. This is Path B: each slide is one full image locked to the anchor"
  echo "  reference (slide $ANCHOR), captions overlaid after. No cutouts, no compositor."
  echo "---"
  echo
  echo "# Generation Brief — ${PIECE:-slideshow} (Path B)"
  echo
  echo "Each slide is one full-frame image. **Slide $ANCHOR is generated FIRST and becomes the anchor reference**; every other slide is generated with that image attached, so the world (room / object / hands) stays identical across the set."
  echo
  echo "## Generator requirement"
  echo "Use a generator that accepts an **input/reference image** (text-only will NOT hold consistency): Gemini 2.5 Flash Image (\"Nano Banana\"), Midjourney \`--cref\`/\`--sref\`, or Flux + IP-Adapter."
  echo
  echo "## How to use"
  echo "1. Generate **slide $ANCHOR** until you like it. Save it as \`anchor.png\`."
  echo "2. Generate every other slide with \`anchor.png\` attached as the reference."
  echo "3. No text inside any image (the look line forbids it)."
  echo "4. Overlay the captions (below) in any editor — lowercase, plain, lower third."
  echo
  echo "## Setting anchor (baked into every prompt below — do NOT drop it)"
  echo "$SETTING"
  echo
  echo "## Look (baked into every prompt below)"
  echo "\`$SHARED_LOOK\`"
  echo
  echo "## Prompts — self-contained, paste each verbatim (setting + look already included)"
  # anchor first, then the rest in slide order
  printf '\n**Slide %s — ANCHOR (generate FIRST, no reference)**\n%s\n' "$ANCHOR" "$(prompt "$ANCHOR")"
  for n in $SLIDES; do
    [[ "$n" = "$ANCHOR" ]] && continue
    printf '\n**Slide %s** (reference: anchor)\n%s\n' "$n" "$(prompt "$n")"
  done
  echo
  # ---- UI/digit overlays derived from Asset Inventory template-method assets ----
  if [[ -n "$ASSET_JSON" ]] && echo "$ASSET_JSON" | jq -e '[.assets[]|select(.method=="template")]|length>0' >/dev/null 2>&1; then
    echo "## Overlays (UI / digits — do NOT let the model draw these)"
    echo "$ASSET_JSON" | jq -r '.assets | to_entries[] | select(.value.method=="template")
      | "- slides \(.value.source_slides|tostring): overlay `\(.value.template)` as a UI element / screenshot (the model mangles digits — composite it, never generate it)."'
    echo
  fi
  echo "## Captions to overlay (verbatim)"
  for n in $SLIDES; do
    printf '%s. %s\n' "$n" "$(cap "$n")"
  done
  echo
  echo "## Caption (post)"
  echo "${CAPTION:-see draft envelope}"
} > "$OUT"

printf '%s\n' "$OUT"

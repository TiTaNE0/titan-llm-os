#!/usr/bin/env bash
# render_manifest.sh — turn a Producer slideshow draft into a machine-readable
# render package: render_manifest.json (the glue all render stages read) + a
# GENERATE.md runbook the image-gen agent (Antigravity / Gemini CLI) follows.
# Generates no pixels.
#
# SCREEN slides (a template UI atom + a phone object on the same slide) can be
# composited two ways, chosen by --screen-mode:
#   model-fuse  (default) : the Remotion UI screenshot is rendered FIRST and handed
#                           to the image model as a reference; the model paints it
#                           onto the phone screen while generating the scene (native
#                           perspective/glow). Python then only burns captions.
#   python-warp (fallback): the phone screen is generated as flat #FF00FF; Python
#                           chroma-keys + perspective-warps the crisp UI onto it.
#                           Use when the model garbles the on-screen text.
#
# Usage: render_manifest.sh --draft <abs draft .md> --campaign <abs campaign dir> [--screen-mode model-fuse|python-warp]
# Exit: 0 success · 2 usage · 4 malformed draft
set -euo pipefail

DRAFT=""; CAMPAIGN=""; SCREEN_MODE="model-fuse"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --draft)       DRAFT="$2"; shift 2 ;;
    --campaign)    CAMPAIGN="$2"; shift 2 ;;
    --screen-mode) SCREEN_MODE="$2"; shift 2 ;;
    -h|--help)     sed -n '2,22p' "$0"; exit 0 ;;
    *)             echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done
[[ -n "$DRAFT" && -n "$CAMPAIGN" ]] || { echo "E2: --draft and --campaign required" >&2; exit 2; }
[[ -f "$DRAFT" ]] || { echo "E2: draft not found: $DRAFT" >&2; exit 2; }
[[ -d "$CAMPAIGN" ]] || { echo "E2: campaign dir not found: $CAMPAIGN" >&2; exit 2; }
case "$SCREEN_MODE" in model-fuse|python-warp) : ;; *) echo "E2: --screen-mode must be model-fuse|python-warp" >&2; exit 2 ;; esac
command -v jq >/dev/null 2>&1 || { echo "E2: jq required" >&2; exit 2; }

fm(){ awk '/^---$/{c++; next} c==1{print} c==2{exit}' "$DRAFT"; }
fmval(){ fm | grep -m1 "^$1:" | sed "s/^$1:[[:space:]]*//; s/[\",' ]//g" || true; }
RUN="$(fmval run)"; PIECE="$(fmval piece_id)"
CAMP_NAME="$(fmval campaign)"; [[ -n "$CAMP_NAME" ]] || CAMP_NAME="$(basename "$CAMPAIGN")"
RUN_DIR="$CAMPAIGN/runs/$RUN"; [[ -d "$RUN_DIR" ]] || RUN_DIR="$CAMPAIGN"

block(){ awk -v h="$1" '
  $0 ~ ("^## " h){s=1; next}
  s && /^```json/{f=1; next}
  s && f && /^```/{exit}
  f{print}
' "$DRAFT"; }
BRIEF_JSON="$(block 'Slide Brief')"
ASSET_JSON="$(block 'Asset Inventory')"
[[ -n "$BRIEF_JSON" ]] || { echo "E4: no '## Slide Brief' json block" >&2; exit 4; }
[[ -n "$ASSET_JSON" ]] || { echo "E4: no '## Asset Inventory' json block" >&2; exit 4; }
echo "$BRIEF_JSON" | jq -e '(.anchor|type=="number") and (.slides|type=="object")' >/dev/null \
  || { echo "E4: Slide Brief invalid (need numeric .anchor, object .slides)" >&2; exit 4; }

ANCHOR="$(echo "$BRIEF_JSON" | jq -r '.anchor')"
SETTING="$(echo "$BRIEF_JSON" | jq -r '.setting')"

cap(){ awk -v n="$1" '
  $0 ~ "^- slide_copy:"{f=1; next}
  f && /^- [a-z_]+:/{f=0}
  f && $0 ~ ("^[[:space:]]*"n"\\.")  {
    sub("^[[:space:]]*"n"\\.[[:space:]]*","");
    gsub(/^\*+[[:space:]]*|[[:space:]]*\*+$/,"");
    if ($0 ~ /^".*"$/) { sub(/^"/,""); sub(/"$/,"") }
    print; exit
  }
' "$DRAFT"; }

# device-autocorrect realism: capitalize ONLY the standalone first-person pronoun
# ("i" -> "I") — no phone keyboard lets a bare "i" through, so lowercase "i" reads as
# fighting autocorrect and breaks the typed-on-a-phone illusion. The rest of the
# lowercase confessional voice is preserved. Applied to BOTH slide captions and the
# post caption here, so neither is ever hand-fixed downstream.
autocorrect(){ perl -pe 's/\bi\b/I/g'; }
POST_CAPTION="$(grep -m1 '^- caption:' "$DRAFT" | sed 's/^- caption:[[:space:]]*//' | autocorrect)"

ui_for_slide(){ # $1 = slide n -> "component<TAB>text" or empty
  echo "$ASSET_JSON" | jq -r --argjson n "$1" '
    .assets | to_entries[]
    | select(.value.method=="template")
    | select(.value.source_slides | index($n))
    | (.value.template // "") as $t
    | (if ($t|test("^recipe_overlay")) then "RecipeScreen"
       elif ($t|test("^imessage")) then "IMessageSlide"
       else "RecipeScreen" end) as $comp
    | ($t | capture("text=\"(?<x>[^\"]*)\"").x // "") as $txt
    | "\($comp)\t\($txt)"
  ' 2>/dev/null | head -1
}
has_pinkscreen(){ # $1 = slide n carries a pink-key (screen) object
  echo "$ASSET_JSON" | jq -e --argjson n "$1" '
    [.assets[] | select(.bg_type=="pink-key") | select(.source_slides | index($n))] | length > 0
  ' >/dev/null 2>&1
}

SLIDES="$(echo "$BRIEF_JSON" | jq -r '.slides | keys | map(tonumber) | sort | .[]')"
MANIFEST="$RUN_DIR/render_manifest.json"
GUIDE="$RUN_DIR/GENERATE.md"

is_screen(){ [[ -n "$(ui_for_slide "$1")" ]] && has_pinkscreen "$1"; }

SLIDE_OBJS="[]"
for n in $SLIDES; do
  scene="$(echo "$BRIEF_JSON" | jq -r --arg n "$n" '.slides[$n]')"
  caption="$(cap "$n" | autocorrect)"   # see autocorrect() — bare "i" -> "I"
  uiline="$(ui_for_slide "$n")"; ui_comp="${uiline%%	*}"; ui_text="${uiline#*	}"
  [[ "$uiline" == "$ui_comp" ]] && ui_text=""
  if is_screen "$n"; then mode="screen-overlay"; smode="$SCREEN_MODE"; else mode="photo-caption"; smode="none"; ui_comp=""; ui_text=""; fi
  obj="$(jq -n \
    --argjson n "$n" --arg mode "$mode" --arg smode "$smode" --arg scene "$scene" --arg caption "$caption" \
    --arg ui_comp "$ui_comp" --arg ui_text "$ui_text" \
    --arg base "assets/slide_${n}_base.png" \
    --arg uipng "ui/slide_${n}_ui.png" \
    --arg out "composed/slide_${n}.png" '
    ($smode=="python-warp") as $warp |
    {
      n: $n, fuse_mode: $mode, screen_mode: (if $mode=="screen-overlay" then $smode else null end),
      caption: $caption,
      base: {
        prompt: $scene, file: $base,
        pink_screen: ($mode=="screen-overlay" and $warp),
        ui_ref: (if ($mode=="screen-overlay" and ($warp|not)) then $uipng else null end)
      },
      ui: (if $ui_comp=="" then null else { component: $ui_comp, text: $ui_text, file: $uipng } end),
      out: $out
    }')"
  SLIDE_OBJS="$(jq -n --argjson arr "$SLIDE_OBJS" --argjson o "$obj" '$arr + [$o]')"
done

jq -n \
  --arg campaign "$CAMP_NAME" --arg run "$RUN" --arg piece "$PIECE" \
  --arg screen_mode "$SCREEN_MODE" \
  --argjson anchor "$ANCHOR" --arg setting "$SETTING" --arg post_caption "$POST_CAPTION" \
  --argjson slides "$SLIDE_OBJS" '
  {
    schema_version: 2, campaign: $campaign, run: $run, piece_id: $piece,
    screen_mode: $screen_mode, anchor_slide: $anchor, setting: $setting,
    post_caption: $post_caption,
    dirs: { assets: "assets", ui: "ui", composed: "composed" },
    slides: $slides
  }' > "$MANIFEST"

# ---- GENERATE.md — runbook the image-gen agent follows (mode-aware) ----
{
  echo "# GENERATE — ${PIECE:-slideshow} (${CAMP_NAME})"
  echo
  echo "Render package for run \`$RUN\`. Screen-compositing mode: **$SCREEN_MODE**."
  echo
  if [[ "$SCREEN_MODE" == "model-fuse" ]]; then
    echo "Flow: Remotion UI screenshots are rendered FIRST (already in \`ui/\`). You (the generation"
    echo "agent) generate each photo, and on SCREEN slides you **attach the matching \`ui/slide_<n>_ui.png\`"
    echo "as a reference image** and have the model paint it onto the phone screen. Python then only burns captions."
    echo
    echo "## AGENT INSTRUCTIONS — do exactly this"
    echo "1. Workspace = the vault root (the directory containing \`05_Marketing_System/\` and \`05_Content/\`)."
    echo "2. Confirm the UI screenshots exist in \`$RUN_DIR/ui/\` (rendered by \`render_prep.sh\`). If absent, run: \`bash 05_Marketing_System/bin/render_ui.sh --run-dir \"$RUN_DIR\"\` first."
    echo "3. Generate **slide $ANCHOR FIRST**; save to \`$RUN_DIR/assets/slide_${ANCHOR}_base.png\` (1080×1920). Attach it as a reference on every other slide so the world stays identical."
    echo "4. For each slide, generate the photo with your image model (Gemini 2.5 Flash Image / \"Nano Banana\") and save to its EXACT \`assets/slide_<n>_base.png\` path. If the tool writes to a temp store (e.g. \`~/.gemini/antigravity/brain/tempmediaStorage/\`), COPY it to that exact path + filename."
    echo "5. On each **SCREEN SLIDE** (flagged below): ATTACH \`ui/slide_<n>_ui.png\` as an additional reference image and instruct the model: *\"the phone on the counter displays exactly this app screen — render it on the phone's screen with correct perspective and scale, and integrate it like a real photographed device with ALL the usual physical screen artifacts: the screen is emissive (slightly brighter than ambient, soft glow spilling onto the bezel), the glass is glossy with subtle environment reflections and a faint glancing-angle sheen, brightness falls off naturally toward oblique angles, and the device sits in the scene's lighting (matching shadows, color cast). Glare and reflections must stay subtle and must NEVER obscure, wash out, or distort the UI; reproduce its text and numbers exactly, do not redraw or restyle them.\"* No magenta, no blank screen, no flat sticker-paste look."
    echo "6. When all six \`assets/slide_*_base.png\` exist, run \`bash 05_Marketing_System/bin/render_run.sh --run-dir \"$RUN_DIR\"\` and open \`composed/contact-sheet.png\`."
    echo "7. **Check the on-screen text** on slides with UI. If the model garbled the digits, re-run prep in the fidelity-safe fallback: \`bash 05_Marketing_System/bin/render_prep.sh --draft <draft> --campaign <campaign> --screen-mode python-warp\` (generate those screens as flat #FF00FF; Python warps the crisp UI on)."
  else
    echo "Flow (fallback): generate each photo with the phone SCREEN as flat #FF00FF; Python warps the crisp"
    echo "Remotion UI onto it in stage 3. Use this when the image model won't keep on-screen text legible."
    echo
    echo "## AGENT INSTRUCTIONS — do exactly this"
    echo "1. Workspace = the vault root (the directory containing \`05_Marketing_System/\` and \`05_Content/\`)."
    echo "2. Generate **slide $ANCHOR FIRST**; save to \`$RUN_DIR/assets/slide_${ANCHOR}_base.png\` (1080×1920). Attach it as a reference on every other slide."
    echo "3. Save each photo to its EXACT \`assets/slide_<n>_base.png\` path. If the tool writes to a temp store first, COPY it to that exact path + filename."
    echo "4. On each **SCREEN SLIDE** (flagged below): render the phone screen as a FLAT EVEN \`#FF00FF\` magenta rectangle — no glare, no UI, no text. (The crisp UI is composited on in stage 3.)"
    echo "5. When all six \`assets/slide_*_base.png\` exist, run \`bash 05_Marketing_System/bin/render_run.sh --run-dir \"$RUN_DIR\"\` and open \`composed/contact-sheet.png\`."
  fi
  echo
  echo "## Setting anchor — bake into every prompt"
  echo "$SETTING"
  echo
  echo "## Per-slide prompts"
  for n in $SLIDES; do
    echo
    echo "**Slide $n** → \`assets/slide_${n}_base.png\`"
    if is_screen "$n"; then
      if [[ "$SCREEN_MODE" == "model-fuse" ]]; then
        echo "> SCREEN SLIDE — also attach \`ui/slide_${n}_ui.png\` as a reference; the phone screen must display THAT exact app screen, text reproduced verbatim, integrated photoreal with the full physical treatment: perspective, emissive glow on the bezel, glossy glass with subtle scene reflections, natural brightness falloff, scene-consistent lighting/shadows. Glare never over the text; no flat sticker-paste look. Do not redraw the text."
      else
        echo "> SCREEN SLIDE — render the phone screen as a FLAT, EVEN \`#FF00FF\` magenta rectangle (no glare, no UI, no text). The recipe UI is composited in later."
      fi
    fi
    echo
    echo "$(echo "$BRIEF_JSON" | jq -r --arg n "$n" '.slides[$n]')"
  done
  echo
  echo "## Post caption (paste to TikTok — device-autocorrect already applied)"
  echo "$POST_CAPTION"
} > "$GUIDE"

printf '%s\n%s\n' "$MANIFEST" "$GUIDE"

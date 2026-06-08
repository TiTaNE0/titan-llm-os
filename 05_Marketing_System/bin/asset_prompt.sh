#!/usr/bin/env bash
# asset_prompt.sh — decompose a Producer slideshow draft into a reusable ASSET
# inventory + a generation-ready prompt per generatable asset; write
# visual_identity.json (declarations) + a run-dir trace; then STOP for review.
# Generates nothing, composites nothing, spends nothing. (Asset_Prompt_Step PRD v1.)
# Faceless route BUILT; ugc-ai-character route STUB (exit 3). Core pipeline unchanged.
#
# Usage: asset_prompt.sh --draft <abs draft .md> --campaign <abs campaign dir>
# Exit: 0 success (files written, STOP for review) · 2 usage · 3 unsupported approach · 4 malformed draft
#
# NOTE: the per-draft asset list is EMITTED by the Producer as a `## Asset Inventory`
# fenced-json block (producer_profiles.md); this script parses it, fuses each scene
# description with the scout SC_MODE/SC_COLOR, and feeds the proven merge — no hardcoded assets.
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

# ---- frontmatter: module -> approach (suffix after last __); run -> run dir ----
fm(){ awk '/^---$/{c++; next} c==1{print} c==2{exit}' "$DRAFT"; }
MODULE="$(fm | grep -m1 '^module:' | sed 's/^module:[[:space:]]*//; s/[",'"'"' ]//g' || true)"
[[ -n "$MODULE" ]] || { echo "E2: draft has no module: frontmatter (usage)" >&2; exit 2; }
APPROACH="${MODULE##*__}"
case "$APPROACH" in
  faceless) : ;;
  ugc-ai-character) echo "ugc-ai-character route not built (PRD §4 / §8.7 anti-premature-abstraction)" >&2; exit 3 ;;
  *) echo "unknown approach: $APPROACH" >&2; exit 3 ;;
esac
RUN="$(fm | grep -m1 '^run:' | sed 's/^run:[[:space:]]*//; s/[",'"'"' ]//g' || true)"
RUN_DIR="$CAMPAIGN/runs/$RUN"; [[ -d "$RUN_DIR" ]] || RUN_DIR="$CAMPAIGN"

# ---- extract the Producer's ## Asset Inventory fenced-JSON block (the per-draft asset list) ----
# The Producer emits the structured asset inventory as an additive section (producer_profiles.md);
# this replaces the old hardcoded run04 detection. Parse the fence, validate, feed the proven merge.
asset_block(){ awk '
  /^## Asset Inventory/{s=1; next}
  s && /^```json/{f=1; next}
  s && f && /^```/{exit}
  f{print}
' "$DRAFT"; }
ASSET_JSON="$(asset_block)"
[[ -n "$ASSET_JSON" ]] || { echo "E4: no '## Asset Inventory' fenced-json block in draft" >&2; exit 4; }
echo "$ASSET_JSON" | jq -e '.assets and (.assets|length>0)' >/dev/null 2>&1 \
  || { echo "E4: Asset Inventory block invalid or empty (.assets missing)" >&2; exit 4; }
# every asset must carry the required keys; generate-method also needs subject/composition/lighting; template needs template
echo "$ASSET_JSON" | jq -e '
  (.assets | to_entries | all(
    (.value | (.type and .method and .bg_type and .ref and (.source_slides|type=="array")))
    and (if .value.method=="generate" then (.value.subject and .value.composition and .value.lighting)
         elif .value.method=="template" then (.value.template != null)
         else true end)
  ))' >/dev/null 2>&1 \
  || { echo "E4: Asset Inventory has an asset missing required keys" >&2; exit 4; }

# ---- read BOTH look inputs: scouted visual pattern (LEADS, native feel) + project design (identity/accent, brand-second) ----
SCOUT="$RUN_DIR/00_scout.md"
vp(){ [[ -f "$SCOUT" ]] || return 0; grep -m1 "^- $1:" "$SCOUT" 2>/dev/null | sed "s/^- $1:[[:space:]]*//;s/[[:space:]]*\$//" || true; }
# renderable visual tokens only — strip any rationale tail after an em-dash ("— NOT illustrated…", "— reads as an ad…")
SC_MODE="$(vp mode | sed 's/ —.*//')";               [[ -n "$SC_MODE" ]]  || SC_MODE='real-photo phone-shot candid grain'
SC_COLOR="$(vp color_temperature | sed 's/ —.*//')"; [[ -n "$SC_COLOR" ]] || SC_COLOR='warm natural'
SC_AESTH="$(vp aesthetic)";          [[ -n "$SC_AESTH" ]] || SC_AESTH='lived-in, filmed-on-a-phone, anti-polished'  # trace/comments only — NOT in prompt strings
# project design accent (REAL — INTUISCALE DESIGN_SYSTEM V2.1 §0.5: AccentTerracotta = primary CTA / hero ring / branding mark).
ACCENT_HEX='#C85A3C (terracotta, light)'
ACCENT='#C85A3C (AccentTerracotta, light) / #D96E52 (dark warm) — primary CTA, hero ring, branding mark (DESIGN_SYSTEM V2.1 §0.5)'
# ---- RATIONALE (governs how prompts are authored; deliberately NOT emitted into the prompt strings) ----
#  * Native LEADS: prompts borrow the scouted niche grammar (real-photo, candid, warm) so the asset reads native.
#  * Brand SECOND / product-UI only: claymorphism/3D + the accent are reserved for product-UI moments (none in run04);
#    a brand-polished promo asset reads as an ad and loses (the formula-card failure mode) — so no brand 3D on these.
#  * BAN (pattern-from-many): prompts describe GENERIC, pattern-derived subjects only — NEVER reproduce a single
#    creator's actual image or framing. Enforced by authoring generic subjects here, not by any string in the prompt.
# Prompt strings below carry ONLY renderable visual tokens. `ref` drives JSON conditioning (which locked atom), not prompt text.
NEG='negatives: no faces, no people, no text, no numbers, no logos, no UI.'
# compose_prompt — FUSE the Producer's per-asset scene description (subject/composition/lighting/descriptor)
# with the scout SC_MODE/SC_COLOR this script reads, in TODAY's gen/bg grammar. The script owns the prompt
# string (the abstraction boundary); the Producer block carries only the scene description + structure.
# pink-key (object) -> "flat pink #FF00FF background"; full-bleed (background) -> "full-bleed environment".
# Implemented as a jq filter ($a = the parsed asset object) so the build handles a variable asset count.
COMPOSE_PROMPT='def compose_prompt($a):
  (if ($a.descriptor // "") == "" then "" else ", " + $a.descriptor end) as $d |
  (if $a.bg_type=="full-bleed" then "full-bleed environment" else "flat pink #FF00FF background" end) as $tail |
  $a.subject + ", " + $a.composition + ", " + $a.lighting + ", " + $SC_MODE + ", " + $SC_COLOR + " color"
    + $d + ", 9:16 vertical, " + $tail + ". " + $NEG ;'
# proposed locked atoms (refs) — seeded from project audience + the scouted lived-in look, FOR OPERATOR CONFIRMATION (never TBD)
SEED_HANDS='warm medium-tone international-student hands, natural and unretouched (operator confirm)'
SEED_APT='small lived-in first US apartment / dorm: off-white walls, warm window and lamp light, minimal, a moving box or two, campus-adjacent (operator confirm)'
SEED_JACKET='a plain mid-weight casual jacket, muted earth tone (olive or tan), slightly worn, unbranded (operator confirm)'

# ---- emit visual_identity.json (declarations only; refs SEEDED-proposed, not TBD) ----
VID="$CAMPAIGN/visual_identity.json"
DATE="$(date +%Y-%m-%d)"
SRC_REL="drafts/$(basename "$DRAFT")"
DK="$(basename "$DRAFT" .md)"   # draft key for the per-asset usage map
# build THIS run's contribution from the parsed Asset Inventory block (assets carry usage:{<draftkey>:[slides]}).
# generate-method: compose the prompt from description + scout tokens. template-method: copy `template` verbatim.
NEWJSON="$(printf '%s' "$ASSET_JSON" | jq \
  --arg date "$DATE" --arg src "$SRC_REL" --arg approach "$APPROACH" --arg dk "$DK" \
  --arg accent "$ACCENT" --arg sh "$SEED_HANDS" --arg sa "$SEED_APT" --arg sj "$SEED_JACKET" \
  --arg SC_MODE "$SC_MODE" --arg SC_COLOR "$SC_COLOR" --arg NEG "$NEG" "
$COMPOSE_PROMPT"'
{
  schema_version: 2, campaign: "Intuiscale", source_drafts: [$src], approach: $approach,
  generated_at: $date, review_status: "proposed — operator confirm refs/accent before any generation",
  consistency: "SCAFFOLDED, NOT yet ACTIVE — all seeds null + no reference images locked. Cross-slide/cross-slideshow consistency activates only when the first generation locks each atom seed + reference image. This step = prompts clean and ready, NOT consistency achieved.",
  look_inputs: { scouted_pattern_leads: "00_scout.md § Winning visual pattern (native feel)", project_design: "CANON + DESIGN_SYSTEM (matte off-white, terracotta accent, claymorphism = product-UI only)" },
  palette: { bg: "#F9F9F9", surface: "#F1E8DD", text: "#000000", accent: $accent, card_temperature_peach: "#F6D7C6", card_weight_sage: "#D7E0D2", source: "INTUISCALE DESIGN_SYSTEM V2.1 §0.5" },
  refs: { hands_skin_tone: $sh, apartment: $sa, jacket: $sj },
  assets: ( .assets | to_entries | map(
    .key as $id | .value as $a |
    { ($id):
      ( { type:$a.type, method:$a.method, bg_type:$a.bg_type, ref:$a.ref, seed:null,
          source_slides:$a.source_slides, usage:{($dk):$a.source_slides} }
        + (if $a.method=="template"
           then { template:$a.template }
           else { prompt: compose_prompt($a) } end) )
    }
  ) | add )
}')"

# ACCUMULATE into the per-project library — NEVER overwrite. Existing identity (palette/refs/review_status) + asset
# DEFINITIONS win (locked atoms are reused, not regenerated); the new draft only ADDS assets + accumulates per-id usage.
if [[ -f "$VID" ]]; then
  jq -n --argjson N "$NEWJSON" --slurpfile Earr "$VID" '
    ($Earr[0]) as $E |
    {
      schema_version: 2, campaign: $N.campaign, approach: $N.approach, generated_at: $N.generated_at,
      review_status: ($E.review_status // $N.review_status),
      consistency: $N.consistency,
      look_inputs: $N.look_inputs,
      source_drafts: ((($E.source_drafts // (if $E.source_draft then [$E.source_draft] else [] end)) + $N.source_drafts) | unique),
      palette: ($E.palette // $N.palette),
      refs: ($N.refs * ($E.refs // {})),
      assets: ( reduce ($N.assets | keys[]) as $k (($E.assets // {});
        if .[$k]
        then .[$k].usage = ((.[$k].usage // {}) + $N.assets[$k].usage) | .[$k].source_slides = $N.assets[$k].source_slides
        else . + {($k): $N.assets[$k]} end) )
    }' > "$VID.tmp" && mv "$VID.tmp" "$VID"
else
  printf '%s\n' "$NEWJSON" > "$VID"
fi

# ---- emit the human-readable review surface ----
TRACE="$RUN_DIR/07_asset_prompt.md"
{
  echo "# Asset-Prompt Step — review surface — $(basename "$DRAFT")"
  echo
  echo "- approach: \`$APPROACH\` (from module suffix) · generated: $DATE · status: **$(jq -r '.review_status' "$VID")**"
  echo "- declarations: \`$VID\` · assets dir (later, post-approval): \`$CAMPAIGN/assets/\`"
  echo "- **Look = scouted native pattern LEADS + Intuiscale identity SECOND.** Nothing generated/composited."
  echo "  - scouted pattern (native feel, from 00_scout.md): mode=\`$SC_MODE\` · color=\`$SC_COLOR\` · aesthetic=\`$SC_AESTH\`"
  echo "  - project design (brand-second, DESIGN_SYSTEM V2.1 §0.5): bg \`#F9F9F9\` / surface \`#F1E8DD\` + accent \`$ACCENT_HEX\`; matte ceramic, zero-gloss, warm (zero-blue); claymorphism/3D reserved for product-UI moments (none here)"
  echo "  - ban: pattern-from-many — NO single creator's image/framing reproduced."
  echo
  echo "| id | type | method | bg_type | source_slides | prompt / template |"
  echo "|----|------|--------|---------|---------------|-------------------|"
  jq -r '.assets | to_entries[] | "| \(.key) | \(.value.type) | \(.value.method) | \(.value.bg_type) | \(.value.source_slides|tostring) | \((.value.prompt // .value.template)|gsub("\n";" ")) |"' "$VID"
  echo
  echo "## Refs — the locked atoms (persist across this project's slideshows; status above)."
  jq -r '.refs | to_entries[] | "- \(.key): \(.value)"' "$VID"
  echo "- accent: $(jq -r '.palette.accent' "$VID")"
} > "$TRACE"

printf '%s\n%s\n' "$VID" "$TRACE"

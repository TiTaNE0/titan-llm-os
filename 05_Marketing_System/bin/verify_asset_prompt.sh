#!/usr/bin/env bash
# verify_asset_prompt.sh — acceptance for asset_prompt.sh (Asset_Prompt_Step PRD §8).
#
# STATELESS: runs entirely against mock fixtures in 05_Marketing_System/tests/fixtures/.
# Proves the parser/composer/accumulator work without referencing any live campaign,
# brand, or production run. To validate a real campaign, run asset_prompt.sh directly
# against its drafts and inspect the emitted visual_identity.json.
#
# Usage: verify_asset_prompt.sh            # default: run against bundled fixtures
#        verify_asset_prompt.sh --fixtures <dir>   # point to an alternate fixture dir
# Exit:  0 all pass · 1 a check failed · 2 usage
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
FIX_DEFAULT="$SCRIPT_DIR/../tests/fixtures"
FIX="$FIX_DEFAULT"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --fixtures) FIX="$2"; shift 2 ;;
    -h|--help)  sed -n '2,11p' "$0"; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done
[[ -d "$FIX" ]] || { echo "E2: fixtures dir not found: $FIX" >&2; exit 2; }

DRAFT_A="$FIX/mock_draft_faceless_a.md"
DRAFT_B="$FIX/mock_draft_faceless_b.md"
BRAND="$FIX/mock_brand_guidelines.json"
SCOUT="$FIX/mock_scout.md"
for f in "$DRAFT_A" "$DRAFT_B" "$BRAND" "$SCOUT"; do
  [[ -f "$f" ]] || { echo "E2: missing fixture: $f" >&2; exit 2; }
done

PASS=1; chk(){ if eval "$2"; then echo "  [PASS] $1"; else echo "  [FAIL] $1"; PASS=0; fi; }

# stamp a fresh sandbox campaign with the mock brand + a mock scout for the given run id
stamp_sandbox(){  # $1 run id -> echoes the sandbox dir on stdout
  local sb rid="$1"
  sb="$(mktemp -d)"
  cp "$BRAND" "$sb/brand_guidelines.json"
  mkdir -p "$sb/runs/$rid"
  cp "$SCOUT" "$sb/runs/$rid/00_scout.md"
  echo "$sb"
}

# run a single draft in a FRESH sandbox campaign; echoes the written visual_identity.json
run_draft_fresh(){  # $1 abs draft -> sandbox VID path on stdout
  local d="$1" sb rv
  rv="$(awk '/^---$/{c++;next} c==1 && /^run:/{sub(/^run:[[:space:]]*/,"");gsub(/[",'"'"' ]/,"");print;exit}' "$d")"
  sb="$(stamp_sandbox "$rv")"
  cp "$d" "$sb/sandbox_draft.md"
  "$SCRIPT_DIR/asset_prompt.sh" --draft "$sb/sandbox_draft.md" --campaign "$sb" >/dev/null 2>&1
  echo "$sb/visual_identity.json"
}

# ============================================================================
# T1–T8: core acceptance — shape, hygiene, brand wiring, no-side-effects
# ============================================================================
echo "=== run the step on mock fixture A (SANDBOXED — no live campaign touched) ==="
SBOX_A_DIR="$(stamp_sandbox mock_run_a)"
cp "$DRAFT_A" "$SBOX_A_DIR/sandbox_draft.md"
OUT="$("$SCRIPT_DIR/asset_prompt.sh" --draft "$SBOX_A_DIR/sandbox_draft.md" --campaign "$SBOX_A_DIR")"; RC=$?
VID="$(echo "$OUT" | sed -n 1p)"; TRACE="$(echo "$OUT" | sed -n 2p)"
echo "  rc=$RC  vid=$VID"

echo "=== T1–T8: shape, hygiene, brand wiring, sandbox-clean ==="
chk "T7  exit 0 on faceless run"                                  "[ $RC -eq 0 ]"
chk "T1  visual_identity.json is valid JSON"                      "jq empty '$VID' 2>/dev/null"
chk "T2  every asset has type/method/bg_type/source_slides (+prompt|template)" \
  "[ \"\$(jq '[.assets[] | select((.type and .method and .bg_type and .source_slides) and ((.method==\"generate\" and .prompt) or (.method==\"template\" and .template))|not)] | length' '$VID')\" = 0 ]"
chk "T5a every generate prompt has no-faces + no-text + no-logo + 9:16" \
  "[ \"\$(jq '[.assets[]|select(.method==\"generate\")|select((.prompt|test(\"no faces\")) and (.prompt|test(\"no text\")) and (.prompt|test(\"no logo\")) and (.prompt|test(\"9:16\"))|not)]|length' '$VID')\" = 0 ]"
chk "T5b every pink-key generate prompt specifies #FF00FF" \
  "[ \"\$(jq '[.assets[]|select(.method==\"generate\" and .bg_type==\"pink-key\")|select(.prompt|test(\"#FF00FF\")|not)]|length' '$VID')\" = 0 ]"
chk "T5c every full-bleed generate prompt is full-bleed, not pink-keyed" \
  "[ \"\$(jq '[.assets[]|select(.method==\"generate\" and .bg_type==\"full-bleed\")|select(.prompt|test(\"full-bleed\")|not)]|length' '$VID')\" = 0 ]"
chk "T8  campaign field == mock brand campaign"                   "[ \"\$(jq -r '.campaign' '$VID')\" = MockCampaign ]"
chk "T8  palette.bg sourced from brand_guidelines.json"           "[ \"\$(jq -r '.palette.bg' '$VID')\" = '#101010' ]"
chk "T8  palette.accent sourced from brand_guidelines.json"       "jq -e '.palette.accent | test(\"MockAccent\")' '$VID' >/dev/null"
chk "T8  refs sourced from brand_guidelines.json"                 "jq -e '.refs.mock_ref_a' '$VID' >/dev/null"
chk "T8  no Intuiscale / production identity leaks into output"   "[ \"\$(jq -r '.|tostring' '$VID' | grep -iE 'intuiscale|terracotta|#c85a3c|#f9f9f9' | wc -l | tr -d ' ')\" = 0 ]"
chk "T10 every generate prompt carries the scout mode token"      "[ \"\$(jq '[.assets[]|select(.method==\"generate\")|select(.prompt|test(\"mock-photo phone-shot\")|not)]|length' '$VID')\" = 0 ]"
chk "T11 prompts are HYGIENIC — no rationale/policy/ref text in the string" \
  "[ \"\$(jq '[.assets[]|select(.method==\"generate\")|select(.prompt|test(\"ad and loses|pattern-from-many|brand identity|ref:|brand-second\"))]|length' '$VID')\" = 0 ]"
chk "T7  no assets/ dir created (nothing rendered)"               "[ ! -d '$SBOX_A_DIR/assets' ]"
chk "T7  no image files written under campaign"                   "[ -z \"\$(find '$SBOX_A_DIR' -name '*.png' -o -name '*.jpg' 2>/dev/null)\" ]"

# ============================================================================
# T6: ugc-ai-character route is a STUB (registered, not built — exits 3, writes nothing)
# ============================================================================
echo "=== T6: ugc-ai-character route is a STUB ==="
TMPC="$(stamp_sandbox mock_run_a)"; TMPD="$TMPC/ugc_draft.md"
sed 's/^module:.*/module: tiktok__slideshow__ugc-ai-character/' "$DRAFT_A" > "$TMPD"
"$SCRIPT_DIR/asset_prompt.sh" --draft "$TMPD" --campaign "$TMPC" >/dev/null 2>&1; URC=$?
chk "T6  ugc route exits 3 (registered, not built)"               "[ $URC -eq 3 ]"
chk "T6  ugc route wrote no visual_identity.json"                 "[ ! -f '$TMPC/visual_identity.json' ]"
rm -rf "$TMPC"

# ============================================================================
# T9: missing module: frontmatter -> exit 2 (usage), writes nothing
# ============================================================================
echo "=== T9: missing module: frontmatter -> exit 2 ==="
TMPC2="$(stamp_sandbox mock_run_a)"; TMPD2="$TMPC2/nomod.md"
grep -v '^module:' "$DRAFT_A" > "$TMPD2"
"$SCRIPT_DIR/asset_prompt.sh" --draft "$TMPD2" --campaign "$TMPC2" >/dev/null 2>&1; NRC=$?
chk "T9  missing-module exits 2 (not 1 — guard fires under set -e)" "[ $NRC -eq 2 ]"
chk "T9  missing-module wrote no visual_identity.json"            "[ ! -f '$TMPC2/visual_identity.json' ]"
rm -rf "$TMPC2"

# ============================================================================
# T_BRAND_MISSING: no brand_guidelines.json -> exit 2 (graceful, actionable)
# ============================================================================
echo "=== T_BRAND_MISSING: no brand file -> exit 2 ==="
TMPC3="$(mktemp -d)"; mkdir -p "$TMPC3/runs/mock_run_a"; cp "$SCOUT" "$TMPC3/runs/mock_run_a/00_scout.md"; cp "$DRAFT_A" "$TMPC3/sandbox_draft.md"
"$SCRIPT_DIR/asset_prompt.sh" --draft "$TMPC3/sandbox_draft.md" --campaign "$TMPC3" >/dev/null 2>&1; BRC=$?
chk "T_BRAND_MISSING exits 2 (graceful, actionable)"              "[ $BRC -eq 2 ]"
chk "T_BRAND_MISSING wrote no visual_identity.json"               "[ ! -f '$TMPC3/visual_identity.json' ]"
rm -rf "$TMPC3"

# ============================================================================
# T_EXTRACT: both fixtures carry a parseable Asset Inventory block
# ============================================================================
echo "=== T_EXTRACT: both fixture drafts carry a parseable fenced Asset Inventory ==="
extract_ok(){ awk '/^## Asset Inventory/{s=1;next} s&&/^```json/{f=1;next} s&&f&&/^```/{exit} f' "$1" | jq -e '.assets and (.assets|length>0)' >/dev/null 2>&1; }
chk "T_EXTRACT fixture A has a parseable Asset Inventory block"   "extract_ok '$DRAFT_A'"
chk "T_EXTRACT fixture B has a parseable Asset Inventory block"   "extract_ok '$DRAFT_B'"

# ============================================================================
# T_PARSE_A: fixture A reproduces its declared mock atom set (ids + source_slides + method)
# ============================================================================
echo "=== T_PARSE_A: fixture A round-trips through asset_prompt.sh unchanged ==="
G1VID="$(run_draft_fresh "$DRAFT_A")"
G1IDS="$(jq -r '.assets|keys|sort|join(",")' "$G1VID" 2>/dev/null)"
G1EXP="mock_bg_01,mock_obj_01,mock_template_01"
chk "T_PARSE_A id-set matches fixture A inventory"                "[ \"$G1IDS\" = \"$G1EXP\" ]"
chk "T_PARSE_A mock_obj_01 source_slides == [1,3]"                "[ \"\$(jq -c '.assets.mock_obj_01.source_slides' '$G1VID')\" = '[1,3]' ]"
chk "T_PARSE_A mock_bg_01 method == generate, bg_type == full-bleed" \
  "[ \"\$(jq -r '.assets.mock_bg_01.method' '$G1VID')\" = generate ] && [ \"\$(jq -r '.assets.mock_bg_01.bg_type' '$G1VID')\" = full-bleed ]"
chk "T_PARSE_A mock_template_01.method == template & has .template" \
  "[ \"\$(jq -r '.assets.mock_template_01.method' '$G1VID')\" = template ] && jq -e '.assets.mock_template_01.template' '$G1VID' >/dev/null"
chk "T_PARSE_A composed prompts hygienic (no rationale/ref:)" \
  "[ \"\$(jq '[.assets[]|select(.method==\"generate\")|select(.prompt|test(\"ad and loses|pattern-from-many|ref:\"))]|length' '$G1VID')\" = 0 ]"
chk "T_PARSE_A every generate prompt carries 9:16 + scout mode + no faces" \
  "[ \"\$(jq '[.assets[]|select(.method==\"generate\")|select((.prompt|test(\"9:16\")) and (.prompt|test(\"mock-photo phone-shot\")) and (.prompt|test(\"no faces\"))|not)]|length' '$G1VID')\" = 0 ]"
rm -rf "$(dirname "$G1VID")"

# ============================================================================
# T_PARSE_B: fixture B reproduces its declared atom set (different ids)
# ============================================================================
echo "=== T_PARSE_B: fixture B round-trips with a different atom set ==="
G2VID="$(run_draft_fresh "$DRAFT_B")"
G2IDS="$(jq -r '.assets|keys|sort|join(",")' "$G2VID" 2>/dev/null)"
G2EXP="mock_obj_01,mock_obj_02"
chk "T_PARSE_B id-set matches fixture B inventory"                "[ \"$G2IDS\" = \"$G2EXP\" ]"
chk "T_PARSE_B mock_obj_02 prompt is distinct (not a clone of mock_obj_01)" \
  "[ \"\$(jq -r '.assets.mock_obj_02.prompt' '$G2VID')\" != \"\$(jq -r '.assets.mock_obj_01.prompt' '$G2VID')\" ]"
rm -rf "$(dirname "$G2VID")"

# ============================================================================
# T_ACCUM: A THEN B in ONE non-resetting sandbox — usage map accumulates, ids merge
# ============================================================================
echo "=== T_ACCUM: A THEN B accumulate into ONE visual_identity.json ==="
ABOX="$(stamp_sandbox mock_run_a)"
mkdir -p "$ABOX/runs/mock_run_b"; cp "$SCOUT" "$ABOX/runs/mock_run_b/00_scout.md"
for d in "$DRAFT_A" "$DRAFT_B"; do
  cp "$d" "$ABOX/$(basename "$d")"
  "$SCRIPT_DIR/asset_prompt.sh" --draft "$ABOX/$(basename "$d")" --campaign "$ABOX" >/dev/null 2>&1
done
AVID="$ABOX/visual_identity.json"
chk "T_ACCUM source_drafts contains BOTH fixture drafts" \
  "[ \"\$(jq '[.source_drafts[]|select(test(\"mock_draft_faceless_a\")or test(\"mock_draft_faceless_b\"))]|length' '$AVID')\" = 2 ]"
chk "T_ACCUM fixture A atoms preserved (mock_bg_01 still present)" \
  "jq -e '.assets.mock_bg_01' '$AVID' >/dev/null"
chk "T_ACCUM fixture B atoms added (mock_obj_02 present)" \
  "jq -e '.assets.mock_obj_02' '$AVID' >/dev/null"
chk "T_ACCUM shared id mock_obj_01 usage map spans BOTH drafts" \
  "[ \"\$(jq '.assets.mock_obj_01.usage|keys|length' '$AVID')\" -ge 2 ]"
rm -rf "$ABOX"

rm -rf "$SBOX_A_DIR"
echo "===== VERDICT: $([ $PASS -eq 1 ] && echo 'ALL PASS' || echo 'FAIL') ====="
[ $PASS -eq 1 ] && exit 0 || exit 1

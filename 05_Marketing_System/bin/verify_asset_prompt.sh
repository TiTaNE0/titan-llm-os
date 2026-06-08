#!/usr/bin/env bash
# verify_asset_prompt.sh — acceptance for asset_prompt.sh (Asset_Prompt_Step PRD §8).
# Runs the step on a faceless draft, then asserts T1-T8 with jq. Zero generation.
# Usage: verify_asset_prompt.sh --draft <abs> --campaign <abs>
# Exit: 0 all pass · 1 a check failed · 2 usage
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DRAFT=""; CAMPAIGN=""
while [[ $# -gt 0 ]]; do case "$1" in
  --draft) DRAFT="$2"; shift 2 ;; --campaign) CAMPAIGN="$2"; shift 2 ;;
  *) echo "Unknown arg: $1" >&2; exit 2 ;; esac; done
[[ -n "$DRAFT" && -n "$CAMPAIGN" ]] || { echo "E2: --draft and --campaign required" >&2; exit 2; }

PASS=1; chk(){ if eval "$2"; then echo "  [PASS] $1"; else echo "  [FAIL] $1"; PASS=0; fi; }

echo "=== run the step (faceless, SANDBOXED — live campaign untouched) ==="
SBOX="$(mktemp -d)"
RUNV="$(awk '/^---$/{c++;next} c==1 && /^run:/{sub(/^run:[[:space:]]*/,"");gsub(/[",'"'"' ]/,"");print;exit}' "$DRAFT")"
mkdir -p "$SBOX/runs/$RUNV"; cp "$DRAFT" "$SBOX/sandbox_draft.md"
OUT="$("$SCRIPT_DIR/asset_prompt.sh" --draft "$SBOX/sandbox_draft.md" --campaign "$SBOX")"; RC=$?
VID="$(echo "$OUT" | sed -n 1p)"; TRACE="$(echo "$OUT" | sed -n 2p)"
echo "  rc=$RC  vid=$VID"

echo "=== assertions ==="
chk "T7  exit 0 on faceless run"                        "[ $RC -eq 0 ]"
chk "T1  visual_identity.json is valid JSON"            "jq empty '$VID' 2>/dev/null"
chk "T2  every asset has type/method/bg_type/source_slides (+prompt|template)" \
  "[ \"\$(jq '[.assets[] | select((.type and .method and .bg_type and .source_slides) and ((.method==\"generate\" and .prompt) or (.method==\"template\" and .template) or (.method==\"screenshot\"))|not)] | length' '$VID')\" = 0 ]"
chk "T3  jacket_01 appears once, source_slides == [2,6]" "[ \"\$(jq -c '.assets.jacket_01.source_slides' '$VID')\" = '[2,6]' ]"
chk "T3  coat_rack_01 once, multi-slide source_slides"   "[ \"\$(jq '.assets.coat_rack_01.source_slides|length' '$VID')\" -ge 2 ]"
chk "T4  weather_widget.method == template"              "[ \"\$(jq -r '.assets.weather_widget.method' '$VID')\" = template ]"
chk "T4  no generate asset id contains 'widget'"         "[ \"\$(jq '[.assets|to_entries[]|select(.value.method==\"generate\" and (.key|test(\"widget\")))]|length' '$VID')\" = 0 ]"
chk "T5a every generate prompt has no-faces + no-text + no-logo + 9:16" \
  "[ \"\$(jq '[.assets[]|select(.method==\"generate\")|select((.prompt|test(\"no faces\")) and (.prompt|test(\"no text\")) and (.prompt|test(\"no logo\")) and (.prompt|test(\"9:16\"))|not)]|length' '$VID')\" = 0 ]"
chk "T5b every pink-key (object) generate prompt specifies #FF00FF" \
  "[ \"\$(jq '[.assets[]|select(.method==\"generate\" and .bg_type==\"pink-key\")|select(.prompt|test(\"#FF00FF\")|not)]|length' '$VID')\" = 0 ]"
chk "T5c every full-bleed (background) generate prompt is full-bleed, not pink-keyed" \
  "[ \"\$(jq '[.assets[]|select(.method==\"generate\" and .bg_type==\"full-bleed\")|select(.prompt|test(\"full-bleed\")|not)]|length' '$VID')\" = 0 ]"
chk "T8  palette.bg == #F9F9F9 (design-system BackgroundPrimary)"  "[ \"\$(jq -r '.palette.bg' '$VID')\" = '#F9F9F9' ]"
chk "T8  refs SEEDED-proposed (none left as TBD)"        "[ \"\$(jq '[.refs[]|select(test(\"TBD\"))]|length' '$VID')\" = 0 ]"
chk "T8  palette.accent is real terracotta #C85A3C (coral placeholder gone)" "jq -e '.palette.accent|(test(\"#C85A3C\")) and (test(\"#FF6B4A\")|not)' '$VID' >/dev/null"
chk "T10 every generate prompt carries the native mode token (real-photo)" \
  "[ \"\$(jq '[.assets[]|select(.method==\"generate\")|select(.prompt|test(\"real-photo\")|not)]|length' '$VID')\" = 0 ]"
chk "T11 prompts are HYGIENIC — no rationale/policy/ref text in the string" \
  "[ \"\$(jq '[.assets[]|select(.method==\"generate\")|select(.prompt|test(\"ad and loses|pattern-from-many|Intuiscale identity|claymorphism|ref:|brand-second\"))]|length' '$VID')\" = 0 ]"
chk "T11 no generate prompt contains a literal 'ref:' token" \
  "[ \"\$(jq '[.assets[]|select(.method==\"generate\")|select(.prompt|test(\"ref:\"))]|length' '$VID')\" = 0 ]"
chk "T7  no assets/ dir created (nothing rendered)"      "[ ! -d '$SBOX/assets' ]"
chk "T7  no image files written under campaign"          "[ -z \"\$(find '$SBOX' -name '*.png' -o -name '*.jpg' 2>/dev/null)\" ]"

echo "=== T6: ugc-ai-character route is a STUB (exit 3, writes nothing) ==="
TMPC="$(mktemp -d)"; mkdir -p "$TMPC/runs"; TMPD="$TMPC/ugc_draft.md"
sed 's/^module:.*/module: tiktok__slideshow__ugc-ai-character/' "$DRAFT" > "$TMPD"
"$SCRIPT_DIR/asset_prompt.sh" --draft "$TMPD" --campaign "$TMPC" >/dev/null 2>&1; URC=$?
chk "T6  ugc route exits 3 (registered, not built)"      "[ $URC -eq 3 ]"
chk "T6  ugc route wrote no visual_identity.json"        "[ ! -f '$TMPC/visual_identity.json' ]"
rm -rf "$TMPC"

echo "=== T9: missing module: frontmatter -> exit 2 (usage), writes nothing ==="
TMPC2="$(mktemp -d)"; mkdir -p "$TMPC2/runs"; TMPD2="$TMPC2/nomod.md"
grep -v '^module:' "$DRAFT" > "$TMPD2"
"$SCRIPT_DIR/asset_prompt.sh" --draft "$TMPD2" --campaign "$TMPC2" >/dev/null 2>&1; NRC=$?
chk "T9  missing-module exits 2 (not 1 — guard fires under set -e)" "[ $NRC -eq 2 ]"
chk "T9  missing-module wrote no visual_identity.json"  "[ ! -f '$TMPC2/visual_identity.json' ]"
rm -rf "$TMPC2"

# ---- per-draft extraction gates (Generalize_Asset_Decomposition) ----
DRAFTDIR="$(cd "$(dirname "$DRAFT")" && pwd -P)"
RUN04="$DRAFTDIR/run04_tiktok_slideshow_faceless.md"
RUN05="$DRAFTDIR/run05_tiktok_slideshow_faceless.md"

# run a single draft in a FRESH sandbox campaign; echoes the written VID path
run_draft_fresh(){  # $1 abs draft -> sandbox VID path on stdout
  local d="$1" sb rv
  sb="$(mktemp -d)"
  rv="$(awk '/^---$/{c++;next} c==1 && /^run:/{sub(/^run:[[:space:]]*/,"");gsub(/[",'"'"' ]/,"");print;exit}' "$d")"
  mkdir -p "$sb/runs/$rv"; cp "$d" "$sb/sandbox_draft.md"
  "$SCRIPT_DIR/asset_prompt.sh" --draft "$sb/sandbox_draft.md" --campaign "$sb" >/dev/null 2>&1
  echo "$sb/visual_identity.json"
}

echo "=== T_EXTRACT: both drafts carry a parseable fenced Asset Inventory block ==="
extract_ok(){ awk '/^## Asset Inventory/{s=1;next} s&&/^```json/{f=1;next} s&&f&&/^```/{exit} f' "$1" | jq -e '.assets and (.assets|length>0)' >/dev/null 2>&1; }
chk "T_EXTRACT run04 has a parseable Asset Inventory block" "extract_ok '$RUN04'"
chk "T_EXTRACT run05 has a parseable Asset Inventory block" "extract_ok '$RUN05'"

echo "=== T_GATE1: run04 reproduces the CONFIRMED atom set (ids+source_slides+method) ==="
G1VID="$(run_draft_fresh "$RUN04")"
G1IDS="$(jq -r '.assets|keys|sort|join(",")' "$G1VID" 2>/dev/null)"
G1EXP="coat_rack_01,doorway_bg_01,forearm_goosebump_01,jacket_01,phone_empty_01,street_bg_01,weather_widget,window_bg_01"
if [ "$G1IDS" != "$G1EXP" ]; then echo "  RECONCILE: run04 id-set drift — got [$G1IDS] expected [$G1EXP] (FIX THE PRODUCER BLOCK, never the confirmed visual_identity.json)"; fi
chk "T_GATE1 run04 id-set == confirmed 8 atoms"          "[ \"$G1IDS\" = \"$G1EXP\" ]"
chk "T_GATE1 phone_empty_01 source_slides == [1]"        "[ \"\$(jq -c '.assets.phone_empty_01.source_slides' '$G1VID')\" = '[1]' ]"
chk "T_GATE1 weather_widget.method == template & [1]"    "[ \"\$(jq -r '.assets.weather_widget.method' '$G1VID')\" = template ] && [ \"\$(jq -c '.assets.weather_widget.source_slides' '$G1VID')\" = '[1]' ]"
chk "T_GATE1 coat_rack_01 source_slides == [1,2,6]"      "[ \"\$(jq -c '.assets.coat_rack_01.source_slides' '$G1VID')\" = '[1,2,6]' ]"
chk "T_GATE1 jacket_01 source_slides == [2,6]"           "[ \"\$(jq -c '.assets.jacket_01.source_slides' '$G1VID')\" = '[2,6]' ]"
chk "T_GATE1 forearm_goosebump_01 source_slides == [3,4]" "[ \"\$(jq -c '.assets.forearm_goosebump_01.source_slides' '$G1VID')\" = '[3,4]' ]"
chk "T_GATE1 doorway_bg_01 source_slides == [1,2,6]"     "[ \"\$(jq -c '.assets.doorway_bg_01.source_slides' '$G1VID')\" = '[1,2,6]' ]"
chk "T_GATE1 street_bg_01 source_slides == [3,4]"        "[ \"\$(jq -c '.assets.street_bg_01.source_slides' '$G1VID')\" = '[3,4]' ]"
chk "T_GATE1 window_bg_01 source_slides == [5]"          "[ \"\$(jq -c '.assets.window_bg_01.source_slides' '$G1VID')\" = '[5]' ]"
chk "T_GATE1 composed prompts hygienic (no rationale/ref:)" \
  "[ \"\$(jq '[.assets[]|select(.method==\"generate\")|select(.prompt|test(\"ad and loses|pattern-from-many|claymorphism|ref:\"))]|length' '$G1VID')\" = 0 ]"
chk "T_GATE1 every generate prompt carries 9:16 + real-photo + no faces" \
  "[ \"\$(jq '[.assets[]|select(.method==\"generate\")|select((.prompt|test(\"9:16\")) and (.prompt|test(\"real-photo\")) and (.prompt|test(\"no faces\"))|not)]|length' '$G1VID')\" = 0 ]"
rm -rf "$(dirname "$G1VID")"

echo "=== T_GATE2_run05: run05 real assets (thermometer mirror, phone not split, iMessage distinct) ==="
G2VID="$(run_draft_fresh "$RUN05")"
chk "T_GATE2_run05 thermometer source_slides == [1,5]"   "[ \"\$(jq -c '.assets.thermometer_01.source_slides' '$G2VID')\" = '[1,5]' ]"
chk "T_GATE2_run05 phone NOT split into a generated widget" \
  "[ \"\$(jq '[.assets|to_entries[]|select(.value.method==\"generate\" and (.key|test(\"widget\")))]|length' '$G2VID')\" = 0 ]"
chk "T_GATE2_run05 iMessage is a distinct id, method template" \
  "[ \"\$(jq -r '.assets.imessage_thread.method' '$G2VID')\" = template ]"
rm -rf "$(dirname "$G2VID")"

echo "=== T_ACCUM: run04 THEN run05 in ONE non-resetting sandbox campaign ==="
ABOX="$(mktemp -d)"
for d in "$RUN04" "$RUN05"; do
  rv="$(awk '/^---$/{c++;next} c==1 && /^run:/{sub(/^run:[[:space:]]*/,"");gsub(/[",'"'"' ]/,"");print;exit}' "$d")"
  mkdir -p "$ABOX/runs/$rv"; cp "$d" "$ABOX/$(basename "$d")"
  "$SCRIPT_DIR/asset_prompt.sh" --draft "$ABOX/$(basename "$d")" --campaign "$ABOX" >/dev/null 2>&1
done
AVID="$ABOX/visual_identity.json"
chk "T_ACCUM source_drafts contains BOTH drafts" \
  "[ \"\$(jq '[.source_drafts[]|select(test(\"run04\")or test(\"run05\"))]|length' '$AVID')\" = 2 ]"
chk "T_ACCUM run04 atoms preserved (jacket_01 [2,6] still present)" \
  "[ \"\$(jq -c '.assets.jacket_01.source_slides' '$AVID')\" = '[2,6]' ]"
chk "T_ACCUM run05 atoms added (thermometer_01 present)" \
  "jq -e '.assets.thermometer_01' '$AVID' >/dev/null"
chk "T_ACCUM shared id phone_empty_01 usage spans BOTH drafts" \
  "[ \"\$(jq '.assets.phone_empty_01.usage|keys|length' '$AVID')\" -ge 2 ]"
rm -rf "$ABOX"

rm -rf "$SBOX"
echo "===== VERDICT: $([ $PASS -eq 1 ] && echo 'ALL PASS' || echo 'FAIL') ====="
[ $PASS -eq 1 ] && exit 0 || exit 1

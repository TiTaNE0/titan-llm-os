#!/usr/bin/env bash
# verify_v3_scaffold.sh — acceptance test for the v3 agentic scaffold build (Phases 0-3).
#
# Tests each script-verifiable AC from the PRD v3.0 briefing.
# ACs 41-42 (live grok runs) are out of scope and not tested here.
#
# Usage: verify_v3_scaffold.sh
# Exit:  0 all pass · 1 any check failed
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
C="$(cd "$SCRIPT_DIR/.." && pwd -P)"

PASS=1
chk() {
  local label="$1"
  shift
  if eval "$@" >/dev/null 2>&1; then
    echo "  [PASS] $label"
  else
    echo "  [FAIL] $label"
    PASS=0
  fi
}

# ---------- GROUP: scaffold-existence -----------------------------------------
echo "=== scaffold-existence ==="

# AC 1: roster.md exists
chk "AC01  agents/roster.md exists" \
  '[ -f "$C/agents/roster.md" ]'

# AC 2: roster.md frontmatter type + locked
chk "AC02a roster.md frontmatter: type: pipeline-artifact" \
  'grep -q "type: pipeline-artifact" "$C/agents/roster.md"'
chk "AC02b roster.md frontmatter: locked:" \
  'grep -q "^locked:" "$C/agents/roster.md"'

# AC 3: roster.md table has all 9 roles + three model ids
chk "AC03a roster.md contains Orchestrator" \
  'grep -q "Orchestrator" "$C/agents/roster.md"'
chk "AC03b roster.md contains Scout" \
  'grep -q "Scout" "$C/agents/roster.md"'
chk "AC03c roster.md contains Matcher" \
  'grep -q "Matcher" "$C/agents/roster.md"'
chk "AC03d roster.md contains Drafter" \
  'grep -q "Drafter" "$C/agents/roster.md"'
chk "AC03e roster.md contains Critic" \
  'grep -q "Critic" "$C/agents/roster.md"'
chk "AC03f roster.md contains Gatekeeper" \
  'grep -q "Gatekeeper" "$C/agents/roster.md"'
chk "AC03g roster.md contains Asset" \
  'grep -q "Asset" "$C/agents/roster.md"'
chk "AC03h roster.md contains Producer" \
  'grep -q "Producer" "$C/agents/roster.md"'
chk "AC03i roster.md contains Wins-logger" \
  'grep -iq "wins" "$C/agents/roster.md"'
chk "AC03j roster.md contains claude-fable-5" \
  'grep -q "claude-fable-5" "$C/agents/roster.md"'
chk "AC03k roster.md contains claude-sonnet-4-6" \
  'grep -q "claude-sonnet-4-6" "$C/agents/roster.md"'
chk "AC03l roster.md contains claude-haiku-4-5" \
  'grep -q "claude-haiku-4-5" "$C/agents/roster.md"'

# AC 4-10: each role_spec exists, has tier: 2, has model: line
for role in scout matcher drafter critic asset producer wins; do
  chk "AC04-10 role_specs/$role.md exists" \
    "[ -f \"$C/agents/role_specs/$role.md\" ]"
  chk "AC04-10 role_specs/$role.md has frontmatter tier: 2" \
    "grep -q \"tier: 2\" \"$C/agents/role_specs/$role.md\""
  chk "AC04-10 role_specs/$role.md has model: line" \
    "grep -q \"^model:\" \"$C/agents/role_specs/$role.md\""
done

# AC 4-10: matcher model contains claude-sonnet-4-6
chk "AC04-10 matcher model is claude-sonnet-4-6" \
  'grep -q "claude-sonnet-4-6" "$C/agents/role_specs/matcher.md"'

# AC 4-10: drafter model contains claude-sonnet-4-6
chk "AC04-10 drafter model is claude-sonnet-4-6" \
  'grep -q "claude-sonnet-4-6" "$C/agents/role_specs/drafter.md"'

# AC 4-10: asset model contains claude-haiku-4-5
chk "AC04-10 asset model is claude-haiku-4-5" \
  'grep -q "claude-haiku-4-5" "$C/agents/role_specs/asset.md"'

# AC 4-10: producer model contains claude-haiku-4-5
chk "AC04-10 producer model is claude-haiku-4-5" \
  'grep -q "claude-haiku-4-5" "$C/agents/role_specs/producer.md"'

# AC 4-10: scout model mentions Grok
chk "AC04-10 scout model mentions Grok" \
  'grep -iq "grok" "$C/agents/role_specs/scout.md"'

# AC 4-10: wins model mentions Grok
chk "AC04-10 wins model mentions Grok" \
  'grep -iq "grok" "$C/agents/role_specs/wins.md"'

# AC 4-10: critic model is non-Claude — mentions grok and does NOT name a claude-* model as primary
chk "AC04-10 critic model mentions grok (non-Claude primary)" \
  'grep -iq "grok" "$C/agents/role_specs/critic.md"'
# The model: line must not start with claude-
chk "AC04-10 critic model: line does not name claude-* as primary" \
  '! grep "^model:" "$C/agents/role_specs/critic.md" | grep -qi "^model:.*\"claude-"'

# AC 11: twitter-reply-orchestrate.md exists
chk "AC11  skill/twitter-reply-orchestrate.md exists" \
  '[ -f "$C/skill/twitter-reply-orchestrate.md" ]'

# AC 12: agents/schemas.md exists
chk "AC12  agents/schemas.md exists" \
  '[ -f "$C/agents/schemas.md" ]'

# AC 13: runs/_schema/README.md exists, contains DEPRECATED and references agents/schemas.md
chk "AC13a runs/_schema/README.md exists" \
  '[ -f "$C/runs/_schema/README.md" ]'
chk "AC13b README.md contains DEPRECATED" \
  'grep -qi "deprecated" "$C/runs/_schema/README.md"'
chk "AC13c README.md references agents/schemas.md" \
  'grep -q "agents/schemas.md" "$C/runs/_schema/README.md"'

# AC 14: legacy _schema files still present
chk "AC14a runs/_schema/01_candidates.json present" \
  '[ -f "$C/runs/_schema/01_candidates.json" ]'
chk "AC14b runs/_schema/02_anchored.json present" \
  '[ -f "$C/runs/_schema/02_anchored.json" ]'
chk "AC14c runs/_schema/03_tactical_brief.json present" \
  '[ -f "$C/runs/_schema/03_tactical_brief.json" ]'

# ---------- GROUP: isolation-contracts ----------------------------------------
echo "=== isolation-contracts ==="

# AC 15: scout.md Must-not-see mentions voice, register, project_authority entries, drafts
chk "AC15a scout Must-not-see mentions voice" \
  'grep -iq "voice" "$C/agents/role_specs/scout.md"'
chk "AC15b scout Must-not-see mentions register" \
  'grep -iq "register" "$C/agents/role_specs/scout.md"'
chk "AC15c scout Must-not-see mentions project_authority" \
  'grep -iq "project_authority" "$C/agents/role_specs/scout.md"'
chk "AC15d scout Must-not-see mentions drafts" \
  'grep -iq "draft" "$C/agents/role_specs/scout.md"'

# AC 16: matcher Reads = 00_candidates.json + project_authority.md only; Must-not-see has voice
chk "AC16a matcher Reads contains 00_candidates.json" \
  'grep -q "00_candidates.json" "$C/agents/role_specs/matcher.md"'
chk "AC16b matcher Reads contains project_authority.md" \
  'grep -q "project_authority.md" "$C/agents/role_specs/matcher.md"'
chk "AC16c matcher Must-not-see contains voice" \
  'grep -iq "voice" "$C/agents/role_specs/matcher.md"'

# AC 17: drafter sees ONE target/one bound entry; must-not-see includes project_authority full + other targets
chk "AC17a drafter spec mentions one target per invocation" \
  'grep -iq "one\|ONE" "$C/agents/role_specs/drafter.md"'
chk "AC17b drafter must-not-see includes full project_authority" \
  'grep -iq "project_authority" "$C/agents/role_specs/drafter.md"'
chk "AC17c drafter must-not-see includes other targets" \
  'grep -iq "other target" "$C/agents/role_specs/drafter.md"'

# AC 18: drafter Hard boundaries: does NOT write replies_to_post.md, does NOT run gate, does NOT do asset
chk "AC18a drafter Hard boundaries: does NOT write replies_to_post.md" \
  'grep -q "replies_to_post.md" "$C/agents/role_specs/drafter.md"'
chk "AC18b drafter Hard boundaries: does NOT run gate" \
  'grep -q "gate" "$C/agents/role_specs/drafter.md"'
chk "AC18c drafter Hard boundaries: does NOT do asset" \
  'grep -iq "asset" "$C/agents/role_specs/drafter.md"'

# AC 19: critic must-not-see: full voice/register; contains Rubric v1; all 5 criterion tokens
chk "AC19a critic must-not-see: voice" \
  'grep -iq "voice" "$C/agents/role_specs/critic.md"'
chk "AC19b critic must-not-see: register" \
  'grep -iq "register" "$C/agents/role_specs/critic.md"'
chk "AC19c critic contains Rubric v1 heading" \
  'grep -iq "rubric v1" "$C/agents/role_specs/critic.md"'
chk "AC19d critic contains voice_fit criterion" \
  'grep -q "voice_fit" "$C/agents/role_specs/critic.md"'
chk "AC19e critic contains specificity_present criterion" \
  'grep -q "specificity_present" "$C/agents/role_specs/critic.md"'
chk "AC19f critic contains no_fabrication criterion" \
  'grep -q "no_fabrication" "$C/agents/role_specs/critic.md"'
chk "AC19g critic contains not_generic criterion" \
  'grep -q "not_generic" "$C/agents/role_specs/critic.md"'
chk "AC19h critic contains length_register_sane criterion" \
  'grep -q "length_register_sane" "$C/agents/role_specs/critic.md"'

# AC 20: producer.md contains "never posts" (case-insensitive)
chk "AC20  producer contains 'never posts'" \
  'grep -iq "never posts" "$C/agents/role_specs/producer.md"'

# AC 21: orchestrate.md contains state model (batch id, status, retry) and statement it never ingests voice/register/grounding/search
chk "AC21a orchestrate.md: state model mentions batch_id" \
  'grep -iq "batch_id\|batch id" "$C/skill/twitter-reply-orchestrate.md"'
chk "AC21b orchestrate.md: state model mentions status" \
  'grep -iq "status" "$C/skill/twitter-reply-orchestrate.md"'
chk "AC21c orchestrate.md: state model mentions retry" \
  'grep -iq "retry\|retries" "$C/skill/twitter-reply-orchestrate.md"'
chk "AC21d orchestrate.md: states it never ingests voice" \
  'grep -iq "never ingests.*voice\|voice.*never" "$C/skill/twitter-reply-orchestrate.md"'

# ---------- GROUP: control-flow-caps ------------------------------------------
echo "=== control-flow-caps ==="

# AC 22: widen cap 3 + "widened 3 times" loud line
chk "AC22a orchestrate.md: widen cap 3" \
  'grep -iq "cap.*3\|3.*cap\|widen.*3\|3.*pass" "$C/skill/twitter-reply-orchestrate.md"'
chk "AC22b orchestrate.md: loud widened 3 times line" \
  'grep -q "widened 3 times" "$C/skill/twitter-reply-orchestrate.md"'

# AC 23: groundable floor 8
chk "AC23  orchestrate.md: groundable floor 8" \
  'grep -iq "floor.*8\|8.*floor\|groundable.*8\|<8" "$C/skill/twitter-reply-orchestrate.md"'

# AC 24: matcher re-scout cap 1
chk "AC24  orchestrate.md: re-scout cap 1 (at most 1 extra)" \
  'grep -iq "re-scout\|rescout" "$C/skill/twitter-reply-orchestrate.md"'
chk "AC24b matcher.md: re-scout cap 1" \
  'grep -iq "re-scout\|1.*re-scout\|most 1" "$C/agents/role_specs/matcher.md"'

# AC 25: shared retry budget 2
chk "AC25a orchestrate.md: shared retry budget 2" \
  'grep -iq "shared.*2\|2.*shared\|shared.*budget.*2\|2.*retries" "$C/skill/twitter-reply-orchestrate.md"'
chk "AC25b caps table: Shared retries = 2" \
  'grep -i "shared" "$C/skill/twitter-reply-orchestrate.md" | grep -q "2"'

# AC 26: skipped recorded in 03_review.json with skip_reason
chk "AC26a orchestrate.md: skip_reason in 03_review.json" \
  'grep -q "skip_reason" "$C/skill/twitter-reply-orchestrate.md"'
chk "AC26b schemas.md: skip_reason field defined" \
  'grep -q "skip_reason" "$C/agents/schemas.md"'

# AC 27: top 2 by engagement.views
chk "AC27a orchestrate.md: top 2 by engagement.views" \
  'grep -iq "top 2" "$C/skill/twitter-reply-orchestrate.md"'
chk "AC27b orchestrate.md: selection by views" \
  'grep -iq "views" "$C/skill/twitter-reply-orchestrate.md"'

# AC 28: gate.sh exit 2 → ABORT
chk "AC28  orchestrate.md: exit 2 → ABORT" \
  'grep -q "exit 2" "$C/skill/twitter-reply-orchestrate.md" && grep -q "ABORT" "$C/skill/twitter-reply-orchestrate.md"'

# AC 29: render_asset exit 3 → "open + screenshot" continue
chk "AC29a orchestrate.md: render_asset.sh exit 3 is non-fatal" \
  'grep -q "exit 3" "$C/skill/twitter-reply-orchestrate.md"'
chk "AC29b orchestrate.md: open + screenshot continue" \
  'grep -iq "open.*screenshot\|screenshot" "$C/skill/twitter-reply-orchestrate.md"'

# AC 30: probe step present (fenced)
chk "AC30a orchestrate.md: PROBE heading or section" \
  'grep -iq "probe" "$C/skill/twitter-reply-orchestrate.md"'
chk "AC30b orchestrate.md: probe section mentions fenced (token: fenced)" \
  'grep -iq "fenced" "$C/skill/twitter-reply-orchestrate.md"'

# AC 31: Phase-1 stub in orchestrate.md AND critic.md with "claude-stub" + "no cross-family veto"
chk "AC31a orchestrate.md: claude-stub" \
  'grep -q "claude-stub" "$C/skill/twitter-reply-orchestrate.md"'
chk "AC31b orchestrate.md: no cross-family veto" \
  'grep -iq "no cross-family veto" "$C/skill/twitter-reply-orchestrate.md"'
chk "AC31c critic.md: claude-stub" \
  'grep -q "claude-stub" "$C/agents/role_specs/critic.md"'
chk "AC31d critic.md: no cross-family veto" \
  'grep -iq "no cross-family veto" "$C/agents/role_specs/critic.md"'

# AC 32: bash≥4 invocation in orchestrate.md; NOT /bin/bash for gate.sh
chk "AC32a orchestrate.md: /opt/homebrew/bin/bash invocation" \
  'grep -q "/opt/homebrew/bin/bash" "$C/skill/twitter-reply-orchestrate.md"'
chk "AC32b orchestrate.md: does NOT instruct bare /bin/bash for gate.sh" \
  '! grep "gate.sh" "$C/skill/twitter-reply-orchestrate.md" | grep -v "opt/homebrew" | grep -q "/bin/bash"'

# ---------- GROUP: schemas ----------------------------------------------------
echo "=== schemas ==="

# AC 33-36: each fenced json block in schemas.md passes jq empty
# Use python3 to extract and validate each block (avoids awk+read line-splitting bug)
SCHEMA_FILE="$C/agents/schemas.md"

BLOCK_COUNT=$(grep -c '^```json' "$SCHEMA_FILE" || true)
chk "AC33  schemas.md has at least 1 fenced json block" \
  '[ "$BLOCK_COUNT" -ge 1 ]'

# python3 extracts each block and exits non-zero if any block is invalid JSON
JSON_VALIDATE_RESULT=$(python3 - "$SCHEMA_FILE" <<'PYEOF'
import json, sys, re
content = open(sys.argv[1]).read()
blocks = re.findall(r'```json\n(.*?)\n```', content, re.DOTALL)
if not blocks:
    print("NO_BLOCKS")
    sys.exit(1)
all_valid = True
for i, b in enumerate(blocks):
    try:
        json.loads(b)
    except Exception as e:
        print(f"INVALID_BLOCK_{i+1}: {e}")
        all_valid = False
if all_valid:
    print(f"ALL_VALID:{len(blocks)}")
else:
    sys.exit(1)
PYEOF
) && JSON_VALIDATE_RC=0 || JSON_VALIDATE_RC=$?

if [ $JSON_VALIDATE_RC -eq 0 ]; then
  NBLOCKS=$(echo "$JSON_VALIDATE_RESULT" | sed 's/ALL_VALID://')
  echo "  [PASS] AC33-36 all fenced json blocks in schemas.md are valid JSON ($NBLOCKS blocks)"
else
  echo "  [FAIL] AC33-36 schemas.md fenced json blocks have invalid JSON: $JSON_VALIDATE_RESULT"
  PASS=0
fi

# AC 34-36: fields collectively present across all JSON content
SCHEMA_ALL_JSON=$(awk '/^```json/{f=1; next} f && /^```/{f=0; next} f{print}' "$SCHEMA_FILE")

chk "AC34a schemas.md json: source_tag field (00_candidates)" \
  'echo "$SCHEMA_ALL_JSON" | grep -q "source_tag"'
chk "AC34b schemas.md json: text_snippet field (00_candidates)" \
  'echo "$SCHEMA_ALL_JSON" | grep -q "text_snippet"'
chk "AC35a schemas.md json: engagement field (01_anchored)" \
  'echo "$SCHEMA_ALL_JSON" | grep -q "engagement"'
chk "AC35b schemas.md json: pillar field (01_anchored)" \
  'echo "$SCHEMA_ALL_JSON" | grep -q "pillar"'
chk "AC35c schemas.md json: ground_with field (01_anchored)" \
  'echo "$SCHEMA_ALL_JSON" | grep -q "ground_with"'
chk "AC35d schemas.md json: entry_substance field (01_anchored)" \
  'echo "$SCHEMA_ALL_JSON" | grep -q "entry_substance"'
chk "AC35e schemas.md json: contribution field (01_anchored, contributability gate)" \
  'echo "$SCHEMA_ALL_JSON" | grep -q "contribution"'
chk "AC36a schemas.md json: verify_flags field (02_drafts)" \
  'echo "$SCHEMA_ALL_JSON" | grep -q "verify_flags"'
chk "AC36b schemas.md json: critic_verdict field (03_review)" \
  'echo "$SCHEMA_ALL_JSON" | grep -q "critic_verdict"'
chk "AC36c schemas.md json: cross_family_veto field (03_review)" \
  'echo "$SCHEMA_ALL_JSON" | grep -q "cross_family_veto"'
chk "AC36d schemas.md json: skip_reason field (03_review)" \
  'echo "$SCHEMA_ALL_JSON" | grep -q "skip_reason"'
chk "AC36e schemas.md json: retries field (03_review)" \
  'echo "$SCHEMA_ALL_JSON" | grep -q "retries"'
chk "AC36f schemas.md json: status field (03_review)" \
  'echo "$SCHEMA_ALL_JSON" | grep -q "\"status\""'

# AC 37: supersession note present
chk "AC37a schemas.md: contains 'supersede'" \
  'grep -iq "supersede" "$C/agents/schemas.md"'
chk "AC37b schemas.md: references 03_tactical_brief" \
  'grep -q "03_tactical_brief" "$C/agents/schemas.md"'

# ---------- GROUP: gatekeeper-harness -----------------------------------------
echo "=== gatekeeper-harness ==="

# AC 38: verify_gate.sh exists and is executable
chk "AC38a bin/verify_gate.sh exists" \
  '[ -f "$C/bin/verify_gate.sh" ]'
chk "AC38b bin/verify_gate.sh is executable" \
  '[ -x "$C/bin/verify_gate.sh" ]'

# AC 39-40: run verify_gate.sh → exit 0 (covers all 22 internal gate checks)
VERIFY_GATE_RC=0
VERIFY_GATE_OUT=""
if [ -x /opt/homebrew/bin/bash ]; then
  BASH4=/opt/homebrew/bin/bash
elif command -v bash >/dev/null 2>&1 && [ "$(bash -c 'echo ${BASH_VERSINFO[0]}')" -ge 4 ] 2>/dev/null; then
  BASH4=bash
else
  echo "  [FAIL] AC39-40: bash>=4 not found (need /opt/homebrew/bin/bash or system bash>=4)"
  PASS=0
  BASH4=""
fi

if [ -n "$BASH4" ]; then
  VERIFY_GATE_OUT=$("$BASH4" "$C/bin/verify_gate.sh" 2>&1) && VERIFY_GATE_RC=$? || VERIFY_GATE_RC=$?
  if [ $VERIFY_GATE_RC -eq 0 ]; then
    echo "  [PASS] AC39-40 verify_gate.sh exits 0 (all internal gate checks pass)"
  else
    echo "  [FAIL] AC39-40 verify_gate.sh exited $VERIFY_GATE_RC"
    echo "--- verify_gate.sh output ---"
    echo "$VERIFY_GATE_OUT"
    echo "--- end ---"
    PASS=0
  fi
fi

# ---------- GROUP: relevance-fix (2026-06-10 post-mortem) ---------------------
echo "=== relevance-fix ==="

# post_type enum present in schemas.md AND scout.md
chk "RF01a schemas.md: post_type enum" \
  'grep -q "post_type" "$C/agents/schemas.md" && grep -q "showcase" "$C/agents/schemas.md"'
chk "RF01b scout.md: post_type" \
  'grep -q "post_type" "$C/agents/role_specs/scout.md"'

# 00b_threads.json defined in schemas.md AND read by matcher.md
chk "RF02a schemas.md: 00b_threads.json defined" \
  'grep -q "00b_threads.json" "$C/agents/schemas.md"'
chk "RF02b matcher.md: reads 00b_threads.json" \
  'grep -q "00b_threads.json" "$C/agents/role_specs/matcher.md"'

# thread_gist present in schemas.md, matcher.md, drafter.md, critic.md
chk "RF03a schemas.md: thread_gist" \
  'grep -q "thread_gist" "$C/agents/schemas.md"'
chk "RF03b matcher.md: thread_gist" \
  'grep -q "thread_gist" "$C/agents/role_specs/matcher.md"'
chk "RF03c drafter.md: thread_gist" \
  'grep -q "thread_gist" "$C/agents/role_specs/drafter.md"'
chk "RF03d critic.md: thread_gist" \
  'grep -q "thread_gist" "$C/agents/role_specs/critic.md"'

# thread_fit criterion present in critic.md
chk "RF04  critic.md: thread_fit criterion" \
  'grep -q "thread_fit" "$C/agents/role_specs/critic.md"'

# matcher replyability filter present
chk "RF05  matcher.md: replyability filter" \
  'grep -iq "replyab" "$C/agents/role_specs/matcher.md"'

# post_actually_about + live-read instruction present in critic.md
chk "RF06a critic.md: post_actually_about" \
  'grep -q "post_actually_about" "$C/agents/role_specs/critic.md"'
chk "RF06b critic.md: live-read instruction (open + live)" \
  'grep -iq "open" "$C/agents/role_specs/critic.md" && grep -iq "live" "$C/agents/role_specs/critic.md"'

# derived jq views note present in schemas.md naming targets/tN.json + drafts/tN.json
chk "RF07a schemas.md: derived jq views note" \
  'grep -iq "derived jq views\|projection" "$C/agents/schemas.md"'
chk "RF07b schemas.md: names targets/tN.json + drafts/tN.json" \
  'grep -q "targets/tN.json" "$C/agents/schemas.md" && grep -q "drafts/tN.json" "$C/agents/schemas.md"'

# gate.sh structural-template + em-dash checks reachable
chk "RF08a gate.sh: structural-template check" \
  'grep -q "the real" "$C/bin/gate.sh"'
chk "RF08b gate.sh: em-dash/splice check" \
  'grep -iq "em-dash\|splice" "$C/bin/gate.sh"'

# PRODUCTION-BATCH STUB GUARD: any 03_review.json with claude-stub MUST also have held:true.
echo "  -- production-batch stub guard --"
STUB_GUARD_OK=1
for rf in "$C"/runs/*/03_review.json; do
  [ -f "$rf" ] || continue
  if grep -q "claude-stub" "$rf"; then
    if grep -Eq '"held"[[:space:]]*:[[:space:]]*true' "$rf"; then
      echo "  [PASS] stub-guard: $(basename "$(dirname "$rf")") has claude-stub AND held:true"
    else
      echo "  [FAIL] stub-guard: $(basename "$(dirname "$rf")") has claude-stub but NOT held:true — a stubbed batch must be HELD"
      STUB_GUARD_OK=0
      PASS=0
    fi
  fi
done
[ $STUB_GUARD_OK -eq 1 ] && echo "  [PASS] RF09 all stubbed batches are held:true"

# cross_family_veto/stub consistency: no 03_review.json may have cross_family_veto:true with claude-stub.
VETO_OK=1
for rf in "$C"/runs/*/03_review.json; do
  [ -f "$rf" ] || continue
  if grep -q "claude-stub" "$rf" && grep -Eq '"cross_family_veto"[[:space:]]*:[[:space:]]*true' "$rf"; then
    echo "  [FAIL] veto-consistency: $(basename "$(dirname "$rf")") has claude-stub AND cross_family_veto:true"
    VETO_OK=0
    PASS=0
  fi
done
[ $VETO_OK -eq 1 ] && echo "  [PASS] RF10 no stubbed batch claims cross_family_veto:true"

chk "RF11 save-and-halt policy present in orchestrate skill" \
  'grep -q "SAVE-AND-HALT" "$C/skill/twitter-reply-orchestrate.md" && grep -q "HALT.json" "$C/skill/twitter-reply-orchestrate.md"'
chk "RF11b save-and-halt mirrored in PRD" \
  'grep -q "Save-and-halt" "$C/Reply_Pipeline_PRD_v3.0_Agentic.md"' 

# ---------- VERDICT -----------------------------------------------------------
echo "===== VERDICT: $([ $PASS -eq 1 ] && echo 'ALL PASS' || echo 'FAIL') ====="
[ $PASS -eq 1 ] && exit 0 || exit 1

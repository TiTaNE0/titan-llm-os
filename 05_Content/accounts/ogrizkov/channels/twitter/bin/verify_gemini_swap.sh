#!/usr/bin/env bash
# verify_gemini_swap.sh — acceptance tests for the Critic→Gemini snapshot-read task.
# Each test covers one DoD acceptance criterion.
# Exit 0 = ALL PASS. Any failure exits non-zero and prints a FAIL line.

set -uo pipefail

C="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0; BUGS=()

pass() { echo "  [PASS] $1"; (( PASS++ )) || true; }
fail() { echo "  [FAIL] $1"; (( FAIL++ )) || true; BUGS+=("$1"); }
chk()  {
  local label="$1" expr="$2"
  if eval "$expr" >/dev/null 2>&1; then pass "$label"; else fail "$label"; fi
}

echo "=== DoD: roster.md ==="

chk "roster Critic row names agy -p invocation" \
  'grep -q "agy -p" "$C/agents/roster.md"'

chk "roster Critic row names Gemini 3.1 Pro (High)" \
  'grep -q "Gemini 3.1 Pro (High)" "$C/agents/roster.md"'

chk "roster Critic row has --print-timeout 10m" \
  'grep -q "print-timeout 10m" "$C/agents/roster.md"'

chk "roster Critic row has --dangerously-skip-permissions" \
  'grep -q "dangerously-skip-permissions" "$C/agents/roster.md"'

chk "roster Critic row provider is google (non-grok)" \
  'grep -i "google\|gemini" "$C/agents/roster.md" | grep -qi "critic\|4.*Critic\|cross-family"'

chk "roster cross-family-veto rule retained (non-Claude)" \
  'grep -q "non-Claude" "$C/agents/roster.md"'

chk "roster grok-budget note: Critic is NOT a grok call" \
  'grep -q "NOT a grok call\|not a grok call" "$C/agents/roster.md"'

chk "roster grok-budget note: MAX_GROK_CALLS bounds Scout + Wins only" \
  'grep -iE "Scout.*Wins|Wins.*Scout" "$C/agents/roster.md"'


echo "=== DoD: critic.md model/invocation ==="

chk "critic.md model line names Gemini 3.1 Pro (High)" \
  'grep "^model:" "$C/agents/role_specs/critic.md" | grep -q "Gemini 3.1 Pro (High)"'

chk "critic.md model line names agy -p" \
  'grep "^model:" "$C/agents/role_specs/critic.md" | grep -q "agy -p"'

chk "critic.md model line has --print-timeout 10m" \
  'grep "^model:" "$C/agents/role_specs/critic.md" | grep -q "print-timeout 10m"'

chk "critic.md model line has --dangerously-skip-permissions" \
  'grep "^model:" "$C/agents/role_specs/critic.md" | grep -q "dangerously-skip-permissions"'

chk "critic.md title says snapshot-read (not live-read)" \
  'grep "^# Critic" "$C/agents/role_specs/critic.md" | grep -q "snapshot-read"'

chk "critic.md title does NOT say live-read" \
  '! grep "^# Critic" "$C/agents/role_specs/critic.md" | grep -qi "live-read"'


echo "=== DoD: critic.md snapshot-read — no live-read judging instruction ==="

chk "critic.md states Critic NEVER opens the URL (negation present)" \
  'grep -q "NEVER opens the URL\|NEVER open the URL\|never opens the URL\|do NOT open the URL" "$C/agents/role_specs/critic.md"'

chk "critic.md has no instruction to OPEN the URL as the judging basis" \
  '! grep -iE "open.*URL|browse.*URL|fetch.*URL" "$C/agents/role_specs/critic.md" | grep -qv "NEVER\|NOT to open\|do NOT open\|NEVER opens"'

chk "critic.md judging basis is the persisted snapshot (00b_threads)" \
  'grep -q "00b_threads" "$C/agents/role_specs/critic.md"'

chk "critic.md says judging basis is snapshot not live" \
  'grep -q "Snapshot-read, not live-read" "$C/agents/role_specs/critic.md"'

chk "critic.md prompt template says do NOT open the URL" \
  'grep -q "do NOT open the URL" "$C/agents/role_specs/critic.md"'

chk "critic.md inputs say url is NOT to open" \
  'grep -q "NOT to open" "$C/agents/role_specs/critic.md"'


echo "=== DoD: critic.md output and telemetry ==="

chk "critic.md output JSON has \"critic\": \"gemini\"" \
  'grep -q "\"critic\": \"gemini\"" "$C/agents/role_specs/critic.md"'

chk "critic.md telemetry uses model gemini-3.1-pro" \
  'grep "run_traced.sh" "$C/agents/role_specs/critic.md" | grep -q "gemini-3.1-pro"'

chk "critic.md telemetry uses provider google" \
  'grep "run_traced.sh" "$C/agents/role_specs/critic.md" | grep -q "google"'

chk "critic.md telemetry does NOT use provider xai" \
  '! grep "run_traced.sh" "$C/agents/role_specs/critic.md" | grep -q "xai"'

chk "critic.md telemetry does NOT have --model grok" \
  '! grep "run_traced.sh" "$C/agents/role_specs/critic.md" | grep -q "\-\-model grok"'

chk "critic.md output has post_snapshot_about (not post_actually_about)" \
  'grep -q "post_snapshot_about" "$C/agents/role_specs/critic.md"'

chk "critic.md does NOT output post_actually_about" \
  '! grep -q '"'"'"post_actually_about"'"'"' "$C/agents/role_specs/critic.md"'


echo "=== DoD: critic.md Rubric v1.3 body unchanged ==="

chk "critic.md rubric has thread_fit criterion" \
  'grep -q "thread_fit" "$C/agents/role_specs/critic.md"'

chk "critic.md rubric has no_fabrication criterion" \
  'grep -q "no_fabrication" "$C/agents/role_specs/critic.md"'

chk "critic.md rubric has voice_fit criterion" \
  'grep -q "voice_fit" "$C/agents/role_specs/critic.md"'

chk "critic.md rubric has specificity_present criterion" \
  'grep -q "specificity_present" "$C/agents/role_specs/critic.md"'

chk "critic.md rubric has topic-adjacent-flex (thread_fit flex)" \
  'grep -q "topic-adjacent flex" "$C/agents/role_specs/critic.md"'

chk "critic.md rubric header says judged against persisted snapshot (not LIVE thread)" \
  'grep -i "rubric\|eight criteria" "$C/agents/role_specs/critic.md" | grep -qi "snapshot"'

chk "critic.md rubric header does NOT say judged against LIVE thread (old wording)" \
  '! grep -i "judged against the LIVE thread" "$C/agents/role_specs/critic.md"'


echo "=== DoD: critic.md cross-family veto + no Claude model ==="

chk "critic.md cross-family preserved: non-Claude" \
  'grep -q "non-Claude" "$C/agents/role_specs/critic.md"'

chk "critic.md does NOT set a claude-* model as primary (model: line)" \
  '! grep "^model:" "$C/agents/role_specs/critic.md" | grep -qi "claude-"'

chk "critic.md independence = non-Claude + snapshot" \
  'grep -q "non-Claude.*snapshot\|snapshot.*non-Claude" "$C/agents/role_specs/critic.md"'


echo "=== DoD: critic.md calibration probe compatibility ==="

chk "critic.md supports snapshot:null for calibration probes" \
  'grep -q "snapshot:null" "$C/agents/role_specs/critic.md"'

chk "critic.md calibration probes: judge from grounded_claim+DRAFT when snapshot:null" \
  'grep -q "grounded_claim.*DRAFT\|DRAFT.*grounded_claim" "$C/agents/role_specs/critic.md"'


echo "=== DoD: critic.md degradation rule updated ==="

chk "critic.md degradation rule mentions agy/Gemini (not grok)" \
  'grep -i "degradation\|unavailable\|UNAVAILABLE" "$C/agents/role_specs/critic.md" | grep -qi "agy\|gemini"'

chk "critic.md no silent stub revert (abort policy)" \
  'grep -q "No silent stub revert\|ABORT\|SAVE-AND-HALT" "$C/agents/role_specs/critic.md"'

chk "critic.md print-timeout 10m as wait mechanism (not kill)" \
  'grep -q "print-timeout 10m" "$C/agents/role_specs/critic.md"'

chk "critic.md no external kill/watchdog for agy" \
  'grep -q "no external kill/watchdog\|no external kill" "$C/agents/role_specs/critic.md"'


echo "=== DoD: schemas.md ==="

chk "schemas.md 00b_threads.json has engagement field" \
  'python3 -c "
import json, re, sys
t = open('"'"'$C/agents/schemas.md'"'"').read()
blocks = re.findall(r\"\`\`\`json(.*?)\`\`\`\", t, re.DOTALL)
found = any(\"engagement\" in b and \"captured_at\" in b for b in blocks)
sys.exit(0 if found else 1)
"'

chk "schemas.md 00b_threads.json engagement has quotes field" \
  'grep -q "quotes" "$C/agents/schemas.md"'

chk "schemas.md 00b_threads.json engagement has reposts field" \
  'grep -q "reposts" "$C/agents/schemas.md"'

chk "schemas.md 00b_threads.json engagement has bookmarks field" \
  'grep -q "bookmarks" "$C/agents/schemas.md"'

chk "schemas.md 00b_threads.json has captured_at field" \
  'grep -q "captured_at" "$C/agents/schemas.md"'

chk "schemas.md captured_at described as ISO-8601" \
  'grep -i "captured_at" "$C/agents/schemas.md" | grep -qi "ISO\|iso-8601\|ISO-8601"'

chk "schemas.md captured_at noted as Scout-filled (not file-mtime)" \
  'grep -i "captured_at" "$C/agents/schemas.md" | grep -qi "Scout\|scout"'

chk "schemas.md 03_review.json critic enum includes gemini" \
  'grep "\"gemini\"\|\"grok\"\|\"claude-stub\"" "$C/agents/schemas.md" | grep -q "gemini"'

chk "schemas.md 03_review.json critic enum retains grok for history" \
  'grep "\"gemini\"\|\"grok\"\|\"claude-stub\"" "$C/agents/schemas.md" | grep -q "grok"'

chk "schemas.md example 03_review.json shows critic: gemini" \
  'python3 -c "
import json, re, sys
t = open('"'"'$C/agents/schemas.md'"'"').read()
blocks = re.findall(r\"\`\`\`json(.*?)\`\`\`\", t, re.DOTALL)
found = any(b.strip().startswith('"'"'{'"'"') and json.loads(b).get('"'"'critic'"'"') == '"'"'gemini'"'"' for b in blocks if b.strip().startswith('"'"'{'"'"'))
sys.exit(0 if found else 1)
"'

chk "schemas.md 00b_threads.json documented as Critic judging snapshot" \
  'grep -i "judging snapshot\|Critic.*judg.*snapshot\|This artifact is the Critic" "$C/agents/schemas.md"'

chk "schemas.md 00b_threads example JSON includes engagement block" \
  'python3 "$C/bin/_test_schemas_engagement.py" "$C/agents/schemas.md"'


echo "=== DoD: scout.md ==="

chk "scout.md thread-fetch captures engagement (nullable)" \
  'grep -A2 "engagement" "$C/agents/role_specs/scout.md" | grep -qi "nullable\|null\|null\b"'

chk "scout.md thread-fetch captures captured_at (ISO-8601)" \
  'grep -i "captured_at" "$C/agents/role_specs/scout.md"'

chk "scout.md 00b_threads is the Critic judging snapshot" \
  'grep -i "critic.*snapshot\|snapshot.*critic\|Critic.*judg\|judg.*snapshot" "$C/agents/role_specs/scout.md"'

chk "scout.md Critic never opens a URL (snapshot responsibility note)" \
  'grep -i "Critic never opens\|never opens.*URL\|Critic.*never.*URL" "$C/agents/role_specs/scout.md"'

chk "scout.md captures engagement with views, likes, replies, quotes, reposts, bookmarks" \
  'grep -E "views.*likes.*replies|engagement.*\{" "$C/agents/role_specs/scout.md" | grep -qi "quotes\|reposts\|bookmarks"'


echo "=== DoD: orchestrate.md ==="

chk "orchestrate PROBE step liveness-checks agy" \
  'grep -i "agy" "$C/skill/twitter-reply-orchestrate.md" | grep -qi "probe\|liveness"'

chk "orchestrate agy probe has --print-timeout 10m" \
  'grep -i "agy.*probe\|probe.*agy" "$C/skill/twitter-reply-orchestrate.md" | grep -q "print-timeout 10m"'

chk "orchestrate agy probe has --dangerously-skip-permissions" \
  'grep -i "agy.*probe\|probe.*agy" "$C/skill/twitter-reply-orchestrate.md" | grep -q "dangerously-skip-permissions"'

chk "orchestrate PROBE step still checks grok (Scout+Wins not removed)" \
  'grep -i "probe" "$C/skill/twitter-reply-orchestrate.md" | grep -qi "grok"'

chk "orchestrate 4c builds snapshot payload from 00b_threads" \
  'grep -i "snapshot" "$C/skill/twitter-reply-orchestrate.md" | grep -qi "00b_threads"'

chk "orchestrate 4c invokes agy (model gemini-3.1-pro, provider google)" \
  'grep "gemini-3.1-pro" "$C/skill/twitter-reply-orchestrate.md" | grep -q "google"'

chk "orchestrate 4c has --print-timeout 10m in agy critic call" \
  'grep -i "agy.*gemini\|gemini.*agy\|agy -p" "$C/skill/twitter-reply-orchestrate.md" | grep -q "print-timeout 10m"'

chk "orchestrate 4c has --dangerously-skip-permissions in agy critic call" \
  'grep -i "agy -p" "$C/skill/twitter-reply-orchestrate.md" | grep -q "dangerously-skip-permissions"'

chk "orchestrate 4c: critic call does NOT increment grok_calls" \
  'grep -i "grok_calls.*increment\|increment.*grok_calls\|No.*grok_calls\|not a grok call" "$C/skill/twitter-reply-orchestrate.md" | grep -qi "critic\|not a grok"'

chk "orchestrate ISOLATION MATRIX: Critic reads persisted snapshot (not live URL)" \
  'grep -i "persisted.*00b_threads.*snapshot\|00b_threads.*snapshot" "$C/skill/twitter-reply-orchestrate.md" | grep -qi "Critic"'

chk "orchestrate ISOLATION MATRIX: deny-list has no live URL open" \
  'grep -i "live X.*URL\|any URL to open\|live.*URL.*open" "$C/skill/twitter-reply-orchestrate.md"'

chk "orchestrate error paths reference agy/Gemini critic unavailability" \
  'grep -i "UNAVAILABLE\|critic.*unavailable" "$C/skill/twitter-reply-orchestrate.md" | grep -qi "agy\|gemini"'

chk "orchestrate agy exceeds 10m → self-abort → CRITIC-UNAVAILABLE → SAVE-AND-HALT" \
  'grep -i "print-timeout.*10m\|10m.*print-timeout" "$C/skill/twitter-reply-orchestrate.md" | grep -qi "SAVE-AND-HALT\|UNAVAILABLE\|self-abort"'

chk "orchestrate: grok_calls counter/MAX_GROK_CALLS still present (Scout+Wins scope)" \
  'grep -q "MAX_GROK_CALLS" "$C/skill/twitter-reply-orchestrate.md"'

chk "orchestrate: grok_calls incremented for Scout (not removed)" \
  'grep -i "Increment.*grok_calls\|grok_calls.*Increment" "$C/skill/twitter-reply-orchestrate.md"'


echo "=== DoD: verify_v3_scaffold.sh ==="

chk "verify_v3_scaffold.sh AC04-10 critic check uses agy|gemini (not grok)" \
  'grep -E "agy\|gemini" "$C/bin/verify_v3_scaffold.sh" | grep -qi "critic"'

chk "verify_v3_scaffold.sh AC04-10 critic check does NOT grep for grok in critic.md" \
  '! grep -E "grep.*grok.*critic\.md|critic\.md.*grok" "$C/bin/verify_v3_scaffold.sh" | grep -qv "agy\|gemini"'

chk "verify_v3_scaffold.sh no-claude-* primary check still present" \
  'grep -q "claude-\*\|claude-.*primary\|does not name claude" "$C/bin/verify_v3_scaffold.sh"'


echo "=== DoD: PIPELINE_OVERVIEW.md ==="

chk "PIPELINE_OVERVIEW Critic row: Gemini 3.1 Pro (High) via agy -p" \
  'grep -i "Critic" "$C/PIPELINE_OVERVIEW.md" | grep -qi "Gemini\|agy"'

chk "PIPELINE_OVERVIEW cross-family veto preserved: Gemini ≠ Claude" \
  'grep -i "cross-family\|Gemini.*Claude\|Gemini.*veto" "$C/PIPELINE_OVERVIEW.md"'

chk "PIPELINE_OVERVIEW Prereqs: agy logged in (required for Critic)" \
  'grep -i "agy" "$C/PIPELINE_OVERVIEW.md" | grep -qi "prereq\|required\|logged in"'

chk "PIPELINE_OVERVIEW no lingering agy-rejected note" \
  '! grep -iE "agy.*rejected|rejected.*agy|agy.*not.*support|agy.*cannot" "$C/PIPELINE_OVERVIEW.md"'


echo "=== DoD: Reply_Pipeline_PRD_v3.0_Agentic.md ==="

chk "PRD §4.4 Critic: Gemini snapshot-read heading" \
  'grep -i "Critic.*Gemini\|Gemini.*snapshot\|snapshot-read" "$C/Reply_Pipeline_PRD_v3.0_Agentic.md" | head -1 | grep -qi "gemini\|snapshot"'

chk "PRD §178-182: snapshot-critic design active (not pending)" \
  'sed -n "178,185p" "$C/Reply_Pipeline_PRD_v3.0_Agentic.md" | grep -qi "gemini\|snapshot\|captured_at"'

chk "PRD §351-356 Critic input is persisted snapshot" \
  'sed -n "350,360p" "$C/Reply_Pipeline_PRD_v3.0_Agentic.md" | grep -qi "snapshot\|captured_at\|persisted"'

chk "PRD §438 roster row: Critic is Gemini (updated)" \
  'sed -n "435,445p" "$C/Reply_Pipeline_PRD_v3.0_Agentic.md" | grep -qi "gemini\|agy\|snapshot"'

chk "PRD §452-455: agy/Gemini rejection paragraph reversed" \
  'sed -n "450,462p" "$C/Reply_Pipeline_PRD_v3.0_Agentic.md" | grep -qi "gemini\|agy\|snapshot"'

chk "PRD cross-family veto rationale preserved (Gemini ≠ Claude)" \
  'grep -i "cross-family\|Gemini.*Claude\|non-Claude" "$C/Reply_Pipeline_PRD_v3.0_Agentic.md" | grep -qi "gemini\|agy"'


echo "=== DoD: run_traced.sh UNCHANGED ==="

chk "run_traced.sh has no kill command" \
  '! grep -q "\bkill\b" "$C/bin/run_traced.sh"'

chk "run_traced.sh has no sleep command" \
  '! grep -q "\bsleep\b" "$C/bin/run_traced.sh"'

chk "run_traced.sh has no CALL_TIMEOUT or watchdog variable" \
  '! grep -qiE "CALL_TIMEOUT|watchdog|alarm" "$C/bin/run_traced.sh"'

chk "run_traced.sh blocks on \$@ (line 55 pattern)" \
  'grep -q '"'"'"$@" > "$out"'"'"' "$C/bin/run_traced.sh"'

chk "run_traced.sh exits with wrapped command code" \
  'grep -q "exit.*\$code" "$C/bin/run_traced.sh"'


echo "=== Adversarial: no Claude model as Critic ==="

chk "critic.md model: line does not reference claude-opus" \
  '! grep "^model:" "$C/agents/role_specs/critic.md" | grep -qi "claude-opus"'

chk "critic.md model: line does not reference claude-sonnet" \
  '! grep "^model:" "$C/agents/role_specs/critic.md" | grep -qi "claude-sonnet"'

chk "critic.md model: line does not reference claude-haiku" \
  '! grep "^model:" "$C/agents/role_specs/critic.md" | grep -qi "claude-haiku"'

chk "roster.md Critic row invocation (| 4 | Critic row) does not mention grok" \
  '! grep "| 4 | Critic" "$C/agents/roster.md" | grep -qi "grok"'


echo "=== Adversarial: staleness acknowledged ==="

chk "critic.md captured_at staleness explicitly sanctioned (PRD §178-182)" \
  'grep -i "captured_at" "$C/agents/role_specs/critic.md" | grep -qi "PRD.*178\|sanction\|tradeoff"'

chk "schemas.md captured_at staleness acknowledged (PRD §178-182)" \
  'grep -i "captured_at" "$C/agents/schemas.md" | grep -qi "PRD.*178\|Critic accepts\|staleness"'


echo "=== Adversarial: dangling critic-grok in 8 files ==="

# This test captures the bug found in PRD v3.1.3 pseudocode line 160
chk "PRD v3.1.3 control flow pseudocode does NOT say CRITIC (grok, live-read)" \
  '! grep -q "CRITIC (grok" "$C/Reply_Pipeline_PRD_v3.0_Agentic.md"'


echo ""
echo "===== SUMMARY ====="
echo "  PASS: $PASS  FAIL: $FAIL"
if [ "$FAIL" -eq 0 ]; then
  echo "===== VERDICT: ALL PASS ====="
  exit 0
else
  echo "===== VERDICT: FAIL ($FAIL failures) ====="
  for b in "${BUGS[@]}"; do echo "  BUG: $b"; done
  exit 1
fi

#!/usr/bin/env bash
# DoD 4: with non-empty rule_proposals the run surfaces each proposal where the operator sees it
# without opening 03_Brain/ (the daily log + final message), then ends; promotion stays human.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
SB="$TMP/sb"; mk_sandbox "$SB"
drive_unattended "$SB"
props="$(grep -c '^Synthesis proposal ' "$REPORT")"; cons="$(grep -c '^Synthesis contradiction ' "$REPORT")"
eq "report lists exactly the 2 pending proposals (missing status = pending; promoted/rejected excluded)" "$props" "2"
eq "report lists exactly the 1 open contradiction (resolved excluded)" "$cons" "1"
eq "first report line is the summary" "$(sed -n 1p "$REPORT" | cut -c1-41)" "Synthesize 2026-W47 (unattended): success"
grep -q 'rule_proposals=2' "$REPORT" && grep -q 'contradictions=1' "$REPORT" && pass "summary counts only pending/open" || fail "summary counts"
grep -qF 'proposal_2026-W47_001) (2026-W47)' "$REPORT" || grep -qF 'proposal_2026-W47_001 (2026-W47) for 03_Brain/Agent_Roles.md: Always do X.' "$REPORT" \
  && pass "proposal line is single-line with whitespace collapsed and names target file" || fail "proposal line shape"
grep -qF 'Approve: /graduate as Architect.' "$REPORT" && grep -qF 'reject proposal_2026-W47_001' "$REPORT" && pass "proposal line carries approve/reject path" || fail "approve/reject path"
grep -qF 'fact_A vs fact_B: A says yes, B says no.' "$REPORT" && pass "contradiction line collapsed" || fail "contradiction line"
grep -q 'proposal_2026-W47_003\|proposal_2026-W47_004\|fact_C' "$REPORT" && fail "promoted/rejected/resolved leaked" || pass "no promoted/rejected/resolved leakage"
# Persist each line to the daily log as the runbook's Step 9 does; each must be a single log line.
export TELEMETRY_DIR="$SB/04_Logs/Telemetry"
while IFS= read -r line; do
  ( cd "$SB" && TITAN_SESSION_ID="$SID" ./.vault_link/.scripts/append_log.sh --date 2026-11-30 --entry "$line" --source-persona Synthesizer ) >/dev/null 2>&1
done < "$REPORT"
LOG="$SB/04_Logs/2026-11-30.md"
eq "daily log has 2 proposal lines" "$(grep -c 'Synthesis proposal ' "$LOG")" "2"
eq "daily log has 1 contradiction line" "$(grep -c 'Synthesis contradiction ' "$LOG")" "1"
eq "daily log has 1 summary line" "$(grep -c '^.*Synthesize 2026-W47 (unattended): success' "$LOG")" "1"
# Empty case: only the summary line.
E="$TMP/empty"; mk_sandbox "$E"; write_w47 "$E"
python3 - "$E/03_Brain/Weekly_Synthesis/2026-W47.synthesis.json" <<'PY'
import json,sys
p=sys.argv[1]; d=json.load(open(p)); d["contradictions"]=[]; d["rule_proposals"]=[]; json.dump(d,open(p,"w"))
PY
out="$(cd "$E" && ./.vault_link/.scripts/synthesize_run.sh report --week 2026-W47 --unattended)"
eq "no proposals/contradictions: exactly one line" "$(echo "$out" | wc -l | tr -d ' ')" "1"
# Runbook names the daily log as the channel and does not overclaim.
U="$TMP/u.md"; section "$RUNBOOK" '## UNATTENDED MODE' > "$U"
has "$U" 'The daily log `04_Logs/<Israel date>.md` gets one line each' "runbook names daily log channel"
has "$U" 'carries every line as well' "runbook names final message channel"
hasnt "$RUNBOOK" 'loads that log into every session' "no overclaim about boot loading"
has "$RUNBOOK" 'until a later daily log exists' "runbook states the boot-context limit"
# Promotion stays human.
step8="$(awk '/^### Step 8 - /{on=1;next} /^(###|##) /{on=0} on' "$RUNBOOK")"
echo "$step8" | grep -q 'Nothing is promoted' && pass "step 8: nothing promoted" || fail "step 8 promote rule"
has "$RUNBOOK" 'interactive Architect session runs `/graduate`' "promotion path is interactive Architect /graduate"

# Fix 9: scope E4 after a clean report still surfaces every contradiction and proposal line.
U9="$TMP/u9.md"; section "$RUNBOOK" '## UNATTENDED MODE' > "$U9"; S9="$TMP/s9.md"; awk '/^### Step 9 - /{on=1;next} /^(###|##) /{on=0} on' "$RUNBOOK" > "$S9"
has "$U9" 'surfacing lines appended' "UNATTENDED MODE pins the scope-E4 surfacing"
has "$S9" 'surfacing lines appended' "Step 9 pins the scope-E4 surfacing"
has "$S9" 'scope' "Step 9 names the scope check"
has "$U9" 'except the scope-E4 surfacing' "stop sentence carries the E4 exception"
E4="$TMP/e4"; mk_sandbox "$E4"
export TELEMETRY_DIR="$E4/04_Logs/Telemetry"
( cd "$E4" && ./.vault_link/.scripts/telemetry_start.sh synthesize )
( cd "$E4" && ./.vault_link/.scripts/session_state_write.sh --persona Synthesizer --session-id synth-e4 --started-at 2026-11-30T06:00:00Z --no-legacy-mirror ) >/dev/null
h4="$(git -C "$E4" rev-parse HEAD)"; write_w47 "$E4"
syn "$E4" report --week 2026-W47 --unattended > "$TMP/e4.report"; eq "e4: report exits 0" "$?" "0"
( cd "$E4/03_Brain/Weekly_Synthesis" && mv facts.jsonl.next facts.jsonl )
sleep 1; echo tampered >> "$E4/03_Brain/System_Agents.md"
syn "$E4" scope --session-id synth-e4 --head "$h4" >/dev/null 2>&1; eq "e4: scope exits 4" "$?" "4"
tpl="$(grep -o 'Synthesize <W> (unattended): error <class> at <step>: <reason>\. Report: \[\[<report basename>\]\]\.' "$U9" | head -1)"
rsn="$(grep -o 'out-of-scope writes <paths>; synthesis written, <n> surfacing lines appended' "$U9" | head -1)"
if [ -z "$tpl" ] || [ -z "$rsn" ]; then fail "e4: runbook lacks the error template or the pinned reason"; else
  n=$(( $(wc -l < "$TMP/e4.report" | tr -d ' ') - 1 ))
  line="${tpl//<W>/2026-W47}"; line="${line//<class>/E4}"; line="${line//<step>/scope}"
  line="${line//<reason>/${rsn//<paths>/03_Brain/System_Agents.md}}"; line="${line//<n>/$n}"; line="${line//<report basename>/2026-11-30_E4_synthesize_2026-W47}"
  ( cd "$E4" && ./.vault_link/.scripts/append_log.sh --date 2026-11-30 --entry "$line" --source-persona Synthesizer ) >/dev/null
  tail -n +2 "$TMP/e4.report" | while IFS= read -r l; do ( cd "$E4" && ./.vault_link/.scripts/append_log.sh --date 2026-11-30 --entry "$l" --source-persona Synthesizer ) >/dev/null; done
  ( cd "$E4" && ./.vault_link/.scripts/emit_telemetry.sh synthesize error auto E4 Synthesizer ) >/dev/null
  L4="$E4/04_Logs/2026-11-30.md"
  eq "e4: one error summary line at scope" "$(grep -c '^Synthesize 2026-W47 (unattended): error E4 at scope' "$L4")" "1"
  grep '^Synthesize 2026-W47 (unattended): error E4 at scope' "$L4" | grep -qF '3 surfacing lines appended' && pass "e4: summary says 3 surfacing lines appended" || fail "e4: summary reason"
  eq "e4: 1 contradiction line" "$(grep -c '^Synthesis contradiction ' "$L4")" "1"
  eq "e4: 2 proposal lines" "$(grep -c '^Synthesis proposal ' "$L4")" "2"
  eq "e4: one synthesize error/E4 row" "$(cat "$E4/04_Logs/Telemetry/"*.jsonl | grep '"macro":"synthesize"' | grep '"status":"error"' | grep -c '"error_class":"E4"')" "1"
  syn "$E4" plan --week 2026-W47 >/dev/null 2>&1; eq "e4: later plan exits 6" "$?" "6"
fi
unset TELEMETRY_DIR
finish

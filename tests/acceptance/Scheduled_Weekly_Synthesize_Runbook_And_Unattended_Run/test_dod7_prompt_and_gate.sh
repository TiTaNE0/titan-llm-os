#!/usr/bin/env bash
# DoD 7: the scheduled task is created only after the operator confirms one manual unattended run;
# the task prompt is a short pointer to the runbook. Never headless claude -p.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
[ -s "$PROMPT" ] && pass "prompt exists" || { fail "prompt missing"; finish; }
body="$(awk 'BEGIN{n=0} /^---$/{n++; next} n>=2' "$PROMPT")"
eq "prompt body has at most 12 non-blank lines" "$([ "$(echo "$body" | grep -c '[^[:space:]]')" -le 12 ] && echo yes || echo no)" "yes"
has "$PROMPT" '.scripts/runbooks/synthesize.md' "prompt points at the runbook"
has "$PROMPT" 'UNATTENDED MODE' "prompt points at the section"
has "$PROMPT" 'Monday 09:00 Israel' "prompt names schedule"
has "$PROMPT" 'Synthesizer' "prompt names persona"
hasnt "$PROMPT" 'claude -p' "prompt has no claude -p"
grep -q '^name: weekly-synthesize$' "$PROMPT" && grep -q '^description: .\+' "$PROMPT" && pass "prompt frontmatter name+description" || fail "prompt frontmatter"
# The pointed-to runbook path and section exist.
[ -f "$VAULT/.scripts/runbooks/synthesize.md" ] && grep -q '^## UNATTENDED MODE$' "$RUNBOOK" && pass "pointer target resolves" || fail "pointer target"
has "$RUNBOOK" 'The scheduled task is created only after the operator confirms one manually started unattended-mode run on his machine.' "gate sentence pinned"
sched="$(section "$RUNBOOK" '## SCHEDULING')"
echo "$sched" | grep -q 'subscription-billed' && pass "subscription-billed" || fail "subscription-billed"
echo "$sched" | grep -q 'Never headless `claude -p`' && pass "never headless claude -p" || fail "claude -p rule"
echo "$sched" | grep -q 'Schedule_Weekly_Synthesis_Cron' && pass "supersedes 2026-10-30 rejection" || fail "supersession note"
echo "$sched" | grep -q 'weekly-synthesize' && pass "task name" || fail "task name"
# Nothing created a live scheduled task (build must not create it before operator confirmation).
[ ! -e "$HOME/.claude/scheduled-tasks/weekly-synthesize" ] && pass "no live weekly-synthesize task exists yet" || fail "live scheduled task already exists before operator confirmation"
# Runbook never instructs a headless run anywhere outside prohibitions.
grep -n 'claude -p' "$RUNBOOK" | grep -vi 'never\|not' >/dev/null && fail "claude -p used affirmatively" || pass "claude -p only appears in prohibitions"

# Fix 6: the prompt tells the session to skip the default post-boot handshake.
has "$PROMPT" 'post-boot' "prompt skips the default post-boot handshake"
has "$PROMPT" 'legacy .session_state.json is never written' "prompt keeps the legacy session file untouched"
grep -v 'post-boot' "$PROMPT" > "$TMP/p_nopb.md"
grep -qF 'post-boot' "$TMP/p_nopb.md" && fail "RED copy still has post-boot" || pass "RED: prompt copy without the line lacks post-boot"
eq "prompt body stays at 12 non-blank lines or fewer" "$([ "$(echo "$body" | grep -c '[^[:space:]]')" -le 12 ] && echo yes || echo no)" "yes"
finish

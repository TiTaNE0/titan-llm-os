#!/usr/bin/env bash
# DoD 2: execute_task Step 8 sends the full numbered findings list to the planner in one resume,
# and the re-review checks only those findings plus regressions they introduced; bounded, never halts.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

S6="$(step_body 6)"; S8="$(step_body 8)"
AUTO="$(printf '%s\n' "$S8" | awk '/^\*\*Autonomous caller/{on=1} on')"
FIRST="$(printf '%s\n' "$AUTO" | awk '/^\*\*Revision loop\*\*/{exit} {print}')"
LOOP="$(printf '%s\n' "$AUTO" | awk '/^\*\*Revision loop\*\*/{on=1} /^\*\*Escalate block\*\*/{exit} on')"
ESC="$(printf '%s\n' "$AUTO" | awk '/^\*\*Escalate block\*\*/{on=1} on')"
item() { printf '%s\n' "$LOOP" | awk -v n="$1" '$0 ~ "^"n"\\. "{on=1; print; next} on && /^[0-9]+\. /{exit} on'; }

# Agent-start accounting reflects up to 3 reviewer rounds and planner resumes.
AS="$(block_body 'Agent starts')"
has "Agent starts: up to 3 pm-reviewer rounds" "$AS" 'up to 3 `pm-reviewer` rounds at Step 8'
has "Agent starts: revisions resume the planner" "$AS" "spec revisions resuming the existing planner"
has "Agent starts: default chain still 4 starts" "$AS" "4 agent starts"
has "Agent starts: resumes are not new starts" "$AS" "resumes of an existing agent are not new starts"

# First review round: verdict now carries the numbered list; FLAG no longer escalates directly.
has "first round verdict carries numbered list" "$FIRST" '`FLAG: <N> findings` followed by the numbered findings list'
has "first round FLAG routes to the revision loop" "$FIRST" '`FLAG` → revision loop.'
lacks "first round FLAG no longer escalates immediately" "$FIRST" '`FLAG` → escalate.'
has "first round APPROVE still proceeds to Step 9" "$FIRST" '`APPROVE` → proceed to Step 9.'

[ -n "$LOOP" ] && pass "Revision loop block present after the first round" || fail "Revision loop block missing"
expect "Revision loop is not a caller heading" 0 "$(printf '%s\n' "$LOOP" | grep -c '^\*\*Autonomous caller')"
expect "Revision loop has items 1..6 in order" "1 2 3 4 5 6" "$(printf '%s\n' "$LOOP" | grep -oE '^[0-9]+\. ' | tr -d '. ' | tr '\n' ' ' | sed 's/ $//')"

I1="$(item 1)"
has "bound: at most 2 revisions" "$I1" "at most 2 revisions"
has "bound: REV starts at 0" "$I1" '`REV` starts at 0'
has "bound: up to 3 reviewer rounds" "$I1" "up to 3 pm-reviewer rounds"
has "bound: REV < 2 continues" "$I1" "On FLAG with REV < 2, increment REV and continue"
has "bound: REV = 2 escalates with flattened findings" "$I1" 'On FLAG with REV = 2, escalate with reason "reviewer flag after 2 revisions: <findings flattened to one line>"'

I2="$(item 2)"
has "planner round is timed" "$I2" '.vault_link/.scripts/telemetry_start.sh invoke_planner "<Task_Name>"'
has "resumes the Step 6 planner" "$I2" "resume the planner agent started in Step 6"
has "resume is not a new start" "$I2" "a resume is not a new start"
has "all findings in one resume" "$I2" "in one resume"
has "full list sent verbatim" "$I2" "full numbered findings list verbatim"
has "fix every finding in one revision" "$I2" "fix every listed finding in one revision and change nothing else"
has "status contract retained" "$I2" "return at most 2 lines per the status contract"
has "fallback when resume is unavailable" "$I2" "re-run Step 6 once with the findings appended to the brief"
p_timer="$(printf '%s\n' "$I2" | grep -nF 'telemetry_start.sh invoke_planner' | head -1 | cut -d: -f1)"
p_resume="$(printf '%s\n' "$I2" | grep -nF 'resume the planner' | head -1 | cut -d: -f1)"
[ -n "$p_timer" ] && [ -n "$p_resume" ] && [ "$p_timer" -le "$p_resume" ] && pass "timer starts before the resume" || fail "invoke_planner timer not before the resume"
# The revision persists through exactly Step 6's write command, forced to --overwrite.
W6="$(printf '%s\n' "$S6" | grep -F 'write_task_section.sh --task-path "<TASK_PATH>" --section spec' | head -1 | sed -E 's/^[[:space:]]+//')"
W2="$(printf '%s\n' "$I2" | grep -F 'write_task_section.sh --task-path "<TASK_PATH>" --section spec' | head -1 | sed -E 's/^[[:space:]]+//')"
expect "revision write = Step 6 write with --overwrite" "${W6/\[--overwrite\]/--overwrite}" "$W2"

I3="$(item 3)"
has "presence check reuses Step 7.1 grep" "$I3" '.vault_link/.scripts/grep_section.sh "$TASK_PATH" "Spec" empty'
has "presence check requires WROTE spec" "$I3" '`WROTE spec`'
has "unpersisted revision -> E3 telemetry" "$I3" '.vault_link/.scripts/emit_telemetry.sh invoke_planner error auto E3 Executioner "<Task_Name>"'
has "unpersisted revision -> escalate" "$I3" '"spec revision not persisted"'
has "persisted revision -> success telemetry" "$I3" '.vault_link/.scripts/emit_telemetry.sh invoke_planner success auto null Executioner "<Task_Name>"'

I4="$(item 4)"
has "rubric re-runs after each revision" "$I4" '.vault_link/.scripts/spec_rubric.sh --task-path "$TASK_PATH"'
has "rubric re-run exit 3 routing" "$I4" '"rubric fail: <detail>"'
has "rubric re-run degraded routing" "$I4" '"spec gate unavailable (degraded)"'

I5="$(item 5)"
has "re-review round is timed" "$I5" '.vault_link/.scripts/telemetry_start.sh spec_gate "<Task_Name>"'
has "re-review uses a fresh pm-reviewer" "$I5" 'start a fresh `pm-reviewer`'
has "re-review brief allows the task file" "$I5" 'allows `$TASK_PATH` as a read'
has "re-review brief carries the prior list" "$I5" "carries the prior numbered list verbatim"
has "re-review scope" "$I5" "check only those findings plus regressions they introduced"
has "re-review raises nothing else" "$I5" "raise nothing else"
has "re-review recorded as spec_gate" "$I5" '.vault_link/.scripts/emit_telemetry.sh spec_gate <approve|flag> auto null Orchestrator "<Task_Name>"'
has "re-review APPROVE -> Step 9" "$I5" '`APPROVE` → proceed to Step 9.'
has "re-review FLAG -> back to item 1 with the new list" "$I5" '`FLAG` → back to item 1 with the new list'

has "loop never halts; failures escalate" "$(item 6)" "The loop never halts. Every failure path goes to the Escalate block."

# Escalation: triggers include the exhausted bound; findings are flattened for queue_attention.
has "escalate trigger list" "$ESC" "(rubric fail, rubric non-zero, revision not persisted, or reviewer FLAG after 2 revisions)"
has "escalate flattens the list" "$ESC" 'flatten the findings list to one line (newlines to ` / `)'
has "escalate source mapping" "$ESC" '`--source pm_reviewer` applies to the reviewer-flag case'
has "escalate then skips to Step 15" "$ESC" "Then skip to Step 15"

# Spawns: this half starts only pm-reviewer; the planner is resumed, never re-spawned as a backticked agent.
SP="$(printf '%s\n' "$AUTO" | grep -oE '[Ss]pawn(ing)? (the )?`[a-z-]+`' | sed -E 's/.*`([a-z-]+)`/\1/' | sort -u | tr '\n' ' ' | sed 's/ $//')"
expect "Autonomous half spawns only pm-reviewer" "pm-reviewer" "$SP"
bad="$(printf '%s\n' "$S8" | grep -F 'emit_telemetry.sh invoke_' | grep -vcF '"<Task_Name>"' || true)"
expect "every Step 8 invoke_* emit carries the task name" 0 "$bad"
finish

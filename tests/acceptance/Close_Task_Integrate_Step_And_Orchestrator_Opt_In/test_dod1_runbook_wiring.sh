#!/usr/bin/env bash
# DoD 1 (crit 35-36, 38, 40, 42-44): ordering, fail-closed, retry route, no rebuild.
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
CT="$(cat "$CLOSE")"
S47="$(slice "$CLOSE" '^## Step 4\.7 ' '^## Step 5 ')"
# ordering: headings
ln() { grep -n "$2" "$1" | head -1 | cut -d: -f1; }
a=$(ln "$CLOSE" '^## Step 4\.5 '); b=$(ln "$CLOSE" '^## Step 4\.6 '); c=$(ln "$CLOSE" '^## Step 4\.7 '); d=$(ln "$CLOSE" '^## Step 5 ')
[ -n "$a" ] && [ "$a" -lt "$b" ] && [ "$b" -lt "$c" ] && [ "$c" -lt "$d" ] && pass "headings 4.5<4.6<4.7<5" || fail "heading order ($a $b $c $d)"
# fenced call order
prev=0; ok=1
for s in commit_task.sh codemap_refresh.sh integrate_task.sh populate_summary.sh set_task_status.sh archive_file.sh; do
  n=$(fenced_lineno "$CLOSE" "$s"); if [ -z "$n" ] || [ "$n" -le "$prev" ]; then ok=0; echo "  order break at $s ($n after $prev)"; fi; prev=${n:-$prev}
done
[ $ok = 1 ] && pass "fenced call order commit<codemap<integrate<populate<flip<archive" || fail "fenced call order"
in=$(fenced_lineno "$CLOSE" integrate_task.sh)
[ "$in" -gt "$c" ] && [ "$in" -lt "$d" ] && pass "integrate call inside Step 4.7" || fail "integrate call outside 4.7"
# crit 36 fail-closed
for p in 'do not run Steps 5-10' 'in_progress' 'HALT' '--state close_gate' 'integrate_task E'; do has "4.7 contains $p" "$S47" "$p"; done
# crit 38/40/43
has "missing key counts as empty" "$S47" 'a missing key counts as empty'
has "source-persona" "$S47" '--source-persona Executioner'
has "allow-missing-branch expansion" "$S47" '${IT_ALLOW:+--allow-missing-branch}'
has "route on rc only" "$S47" 'on `$IT_RC` only'
for p in IR_RC .integrate_retry panel_guard.sh 'integrate retry pending'; do has "4.7 contains $p" "$S47" "$p"; done
hasnt "no task_owner.sh in close_task" "$CT" task_owner.sh
S10="$(slice "$CLOSE" '^## Step 10 ' '^## Error handling')"
has "Step 10 Integrated" "$S10" Integrated; has "Step 10 Committed" "$S10" Committed
has "HARD RULE lists integrate_task.sh" "$(slice "$CLOSE" '^## HARD RULE' '^## Invocation')" integrate_task.sh
has "Invocation mentions Step 4a" "$(slice "$CLOSE" '^## Invocation' '^## Step 1 ')" 'Step 4a'
# tick
T4="$(slice "$TICK" '^## Step 4 ' '^### Step 4a')"
r=$(printf '%s\n' "$T4" | grep -n '\.integrate_retry' | head -1 | cut -d: -f1)
g=$(printf '%s\n' "$T4" | grep -n -- '--state-file .vault_link/04_Logs/Orchestrator/.dispatched.' | head -1 | cut -d: -f1)
[ -n "$r" ] && [ -n "$g" ] && [ "$r" -lt "$g" ] && pass "tick: .integrate_retry check precedes .dispatched guard" || fail "tick route order ($r vs $g)"
S4A="$(slice "$TICK" '^### Step 4a' '^### Step 4b')"
[ -n "$S4A" ] || fail "Step 4a exists"
has "4a invokes close only" "$S4A" '/close_task [[<task>]] --run-id'
has "4a own guard" "$S4A" '.integrate_dispatched.'
has "4a stamps owner" "$S4A" task_owner.sh
hasnt "4a no execute_task" "$S4A" '/execute_task [['
has "4a before 4b" "$(grep -n '^### Step 4' "$TICK" | cut -d: -f2 | tr '\n' '|')" 'Step 4a'
S14="$(slice "$EXEC" '^## Step 14' '^## Step 15')"
has "exec Step 14 outcome" "$S14" 'integrate retry pending'
S16="$(slice "$EXEC" '^## Step 16' '^## Step 17|^## Reminders|^## Error')"
has "exec Step 16 outcome" "$S16" 'integrate retry pending'
has "exec Step 16 pin kept" "$S16" '| queued no_progress>'
S5="$(slice "$TICK" '^## Step 5 ' '^## Step 6')"
has "tick Step 5 outcome" "$S5" 'integrate retry pending'
has "tick Step 5 no stop line" "$S5" 'no `stop:` line'
# crit 44
TK="$(cat "$TICK")"
has "no resume shortcut kept" "$TK" 'There is no resume-at-gateway shortcut'
has "shortcut exception" "$TK" 'except the integrate-retry route (Step 4a)'
for s in integrate_task.sh commit_task.sh; do
  [ -z "$(fenced "$TICK" | grep -F "$s")" ] && pass "tick has no fenced $s" || fail "tick fenced $s"
done
finish

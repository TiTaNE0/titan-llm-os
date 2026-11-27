#!/usr/bin/env bash
# DoD 2: UNATTENDED MODE owns the handshake, the ISO week, per-class error handling and the final message.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
U="$TMP/unattended.md"
section "$RUNBOOK" '## UNATTENDED MODE' > "$U"
[ -s "$U" ] && pass "UNATTENDED MODE section exists" || { fail "no UNATTENDED MODE section"; finish; }
for lit in 'session_state_write.sh' '--persona Synthesizer' '--no-legacy-mirror' 'TITAN_SESSION_ID=' 'synthesize_run.sh week' \
           'synthesize_run.sh scope' 'append_log.sh' 'emit_telemetry.sh synthesize' 'week-unknown' 'error <class> at <step>' 'Final message' \
           'synth-'; do
  has "$U" "$lit" "owns: $lit"
done
for c in E1 E2 E3 E4 E5; do grep -q "$c" "$U" && pass "error class $c handled" || fail "error class $c"; done
# Order bullet: week precedes handshake, handshake precedes scope, scope precedes Step 9.
order_blk="$(awk '/^- Order:/{on=1;next} on&&/^- /{exit} on' "$U")"
w="$(echo "$order_blk" | grep -n 'synthesize_run.sh week' | head -1 | cut -d: -f1)"
h="$(echo "$order_blk" | grep -n 'session_state_write.sh' | head -1 | cut -d: -f1)"
s="$(echo "$order_blk" | grep -n 'synthesize_run.sh scope' | head -1 | cut -d: -f1)"
n9="$(echo "$order_blk" | grep -n 'Step 9' | head -1 | cut -d: -f1)"
[ -n "$w" ] && [ -n "$h" ] && [ -n "$s" ] && [ -n "$n9" ] && [ "$w" -lt "$h" ] && [ "$h" -lt "$s" ] && [ "$s" -lt "$n9" ] \
  && pass "order: week < handshake < scope < Step 9" || fail "order bullet ($w $h $s $n9)"
# Handshake must not mirror to the legacy singleton (would rebind a concurrent session).
grep -q 'Never write the legacy' "$U" && pass "legacy mirror forbidden" || fail "legacy mirror rule"
# The helper's `week` answers the 'which ISO week' rule: previous week, and the rule says exactly one.
has "$U" 'Exactly one week per run' "one week per run"
# Every step enum named in the generic template is used by the per-class list.
for st in week handshake persona plan synthesis report scope log; do grep -q "\`$st\`" "$U" && pass "step enum $st" || fail "step enum $st"; done
# Pointer files do not hold rules of their own.
hasnt "$PROMPT" 'session_state_write' "prompt holds no handshake rule"
finish

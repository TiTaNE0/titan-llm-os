#!/usr/bin/env bash
# DoD 2: /execute_task runs 4 agent starts by default (planner, builder, test-verifier, validator);
# the old four agent files stay for /feature and other commands.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

for a in planner builder researcher spec-writer backend-builder frontend-builder; do
  [ -f "$AGENTS/$a.md" ] && pass "agent file $a.md present" || fail "agent file $a.md missing"
done
for a in planner builder; do
  n="$(awk '/^---$/{c++; next} c==1 && /^name:/{sub(/^name:[[:space:]]*/,""); print; exit}' "$AGENTS/$a.md")"
  expect "$a.md frontmatter name" "$a" "$n"
done

spawns() { grep -oE '[Ss]pawn(ing)? (the )?`[a-z-]+`' | sed -E 's/.*`([a-z-]+)`/\1/'; }

# Default path: Step 10 minus its split branch; Step 8 minus its Autonomous half.
S6="$(step_body 6)"; S8="$(step_body 8)"; S10="$(step_body 10)"; S11="$(step_body 11)"; S12="$(step_body 12)"
S8_HUMAN="$(printf '%s\n' "$S8" | awk '/^\*\*Autonomous caller/{exit} {print}')"
S8_AUTO="$(printf '%s\n' "$S8" | awk '/^\*\*Autonomous caller/{on=1} on{print}')"
S10_DEFAULT="$(printf '%s\n' "$S10" | awk '/^\*\*Matched \(split\)/{exit} {print}')"
S10_SPLIT="$(printf '%s\n' "$S10" | awk '/^\*\*Matched \(split\)/{on=1} /^\*\*Parallel exception/{exit} on{print}')"

expect "Step 6 spawns only planner" "planner" "$(printf '%s\n' "$S6" | spawns | sort -u | tr '\n' ' ' | sed 's/ $//')"
expect "Step 8 interactive half spawns nothing" "" "$(printf '%s\n' "$S8_HUMAN" | spawns | sort -u | tr '\n' ' ' | sed 's/ $//')"
expect "Step 8 Autonomous half spawns only pm-reviewer" "pm-reviewer" "$(printf '%s\n' "$S8_AUTO" | spawns | sort -u | tr '\n' ' ' | sed 's/ $//')"
expect "Step 10 default branch spawns only builder" "builder" "$(printf '%s\n' "$S10_DEFAULT" | spawns | sort -u | tr '\n' ' ' | sed 's/ $//')"
expect "Step 10 split branch spawns backend-builder then frontend-builder" "backend-builder frontend-builder" "$(printf '%s\n' "$S10_SPLIT" | spawns | tr '\n' ' ' | sed 's/ $//')"
expect "Step 11 spawns test-verifier and fix builder" "builder test-verifier" "$(printf '%s\n' "$S11" | spawns | sort -u | tr '\n' ' ' | sed 's/ $//')"
expect "Step 12 spawns only validator" "validator" "$(printf '%s\n' "$S12" | spawns | sort -u | tr '\n' ' ' | sed 's/ $//')"

# Ordered default chain, first spawn per step, interactive non-split path.
CHAIN="$(printf '%s\n%s\n%s\n%s\n' "$S6" "$S10_DEFAULT" "$S11" "$S12" | spawns | awk '!seen[$0]++' | tr '\n' ' ' | sed 's/ $//')"
expect "default chain order (4 starts)" "planner builder test-verifier validator" "$CHAIN"

# Old agents do not appear anywhere in Steps 6-12 (plain or backticked) (Steps 9-10 may name the split builders).
S6_12="$(for n in 6 7 8 9 10 11 12; do step_body $n; done)"
for w in researcher spec-writer invoke_researcher invoke_spec_writer; do
  c="$(printf '%s\n' "$S6_12" | grep -cw -- "$w" || true)"
  expect "Steps 6-12 never name $w" 0 "$c"
done
OUTSIDE_9_10="$(for n in 6 7 8 11 12; do step_body $n; done)"
for w in backend-builder frontend-builder; do
  c="$(printf '%s\n' "$OUTSIDE_9_10" | grep -cw -- "$w" || true)"
  expect "default path outside Steps 9-10 never names $w" 0 "$c"
done

printf '%s\n' "$S6" | grep -qF 'telemetry_start.sh invoke_planner' && pass "Step 6 times invoke_planner" || fail "Step 6 lacks invoke_planner timer"
printf '%s\n' "$S6" | grep -qF -- '--section spec --source-persona Executioner --content-file -' && pass "planner persists spec itself (one spec write)" || fail "Step 6 planner write command missing"
printf '%s\n' "$S6" | grep -qF 'Responsibility map' && printf '%s\n' "$S6" | grep -qF 'Context pack' \
  && pass "planner brief requires Responsibility map and Context pack" || fail "planner brief lacks map/pack requirement"
printf '%s\n' "$S8" | grep -qF 'persisted by the planner' && printf '%s\n' "$S8" | grep -qF 'planner brief' \
  && pass "Step 8 corrections re-run the planner" || fail "Step 8 planner wording missing"

AS="$(block_body 'Agent starts')"
printf '%s\n' "$AS" | grep -qF '4 agent starts' && pass "Agent starts block states 4 agent starts" || fail "Agent starts block lacks '4 agent starts'"
head -5 "$EXEC_MD" | grep -E '^description:' | grep -qF '4-agent' && pass "description says 4-agent" || fail "description lacks 4-agent"
grep -qF 'researcher, spec-writer, backend-builder, frontend-builder remain for /feature' "$EXEC_MD" \
  && pass "Reminders keep old agents for /feature" || fail "Reminders lack default-chain note"
finish

#!/usr/bin/env bash
# DoD 4: an Orchestrator run cannot auto-close without the measurement (Step 14 guard, run verbatim
# on fixture task files); pm-reviewer time is now measured (Step 8 spec_gate timer, exercised through
# the real telemetry scripts); the agent-start rule is stated once in "## Agent starts".
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
S14="$(step_body 14)"
GUARD="$(printf '%s\n' "$S14" | awk '/^MEAS_BLOCK=\$\(awk/{on=1} on{print} on && /measurement_scope: \(run/{exit}')"
[ -n "$GUARD" ] || { fail "Step 14 guard not found"; finish; }
guard() { TASK_PATH="$1" bash -c "$GUARD" >/dev/null 2>&1 && echo close || echo escalate; }

# vo <name> <verification-output-body> [spec-body]: task file with those section bodies.
vo() {
  local t="$TMP/$1.md"; mk_task "$t"
  printf '%s\n' "$2" > "$TMP/$1.vo"; printf '%s\n' "${3:-}" > "$TMP/$1.sp"
  awk -v v="$TMP/$1.vo" -v s="$TMP/$1.sp" '
    /<!-- write_task_section section=verification_output -->/ { print; while ((getline l < v) > 0) print l; next }
    /<!-- write_task_section section=spec -->/ { print; while ((getline l < s) > 0) print l; next }
    { print }' "$t" > "$t.x" && mv "$t.x" "$t"
  echo "$t"
}
GW=$'**Test command:** `bash tests/x.sh`\n**Exit code:** 0\n**Output:**\n```\nALL GREEN\n```'
OK=$'agent_starts: 5\nagent_time_ms: 6000\nzero_duration_rows: 1\nmeasurement_scope: run run-20261108T110000Z\n'

expect "complete block -> close" close "$(guard "$(vo full "$OK$GW")")"
expect "invocation scope -> close" close "$(guard "$(vo inv $'agent_starts: 4\nagent_time_ms: 0\nmeasurement_scope: invocation\n'"$GW")")"
expect "empty Verification Output -> escalate" escalate "$(guard "$(vo empty "")")"
expect "gateway block only -> escalate" escalate "$(guard "$(vo gwonly "$GW")")"
expect "missing agent_starts -> escalate" escalate "$(guard "$(vo nostarts $'agent_time_ms: 6000\nmeasurement_scope: invocation\n'"$GW")")"
expect "agent_starts: 0 -> escalate" escalate "$(guard "$(vo zero $'agent_starts: 0\nagent_time_ms: 6000\nmeasurement_scope: invocation\n'"$GW")")"
expect "agent_starts placeholder <N> -> escalate" escalate "$(guard "$(vo ph $'agent_starts: <N>\nagent_time_ms: 6000\nmeasurement_scope: invocation\n'"$GW")")"
expect "agent_time_ms unavailable -> escalate" escalate "$(guard "$(vo unavail $'agent_starts: 5\nagent_time_ms: unavailable (timer missing)\nmeasurement_scope: invocation\n'"$GW")")"
expect "missing measurement_scope -> escalate" escalate "$(guard "$(vo noscope $'agent_starts: 5\nagent_time_ms: 6000\n'"$GW")")"
expect "malformed scope -> escalate" escalate "$(guard "$(vo badscope $'agent_starts: 5\nagent_time_ms: 6000\nmeasurement_scope: run 2026-11-08\n'"$GW")")"
expect "markers only inside the gateway fence -> escalate" escalate \
  "$(guard "$(vo fence $'**Test command:** `bash tests/x.sh`\n**Exit code:** 0\n**Output:**\n```\nagent_starts: 5\nagent_time_ms: 6000\nmeasurement_scope: invocation\n```')")"
expect "markers only in § Spec -> escalate" escalate \
  "$(guard "$(vo inspec "$GW" $'### Example\nagent_starts: 5\nagent_time_ms: 6000\nmeasurement_scope: invocation')")"
# A spec that documents the guard (as this task's own spec does) quotes the anchor text in prose.
expect "spec quoting the anchor text plus example lines, empty Verification Output -> escalate" escalate \
  "$(guard "$(vo quoted "" $'The guard runs `awk \'/write_task_section section=verification_output/{on=1;next} ...\'`.\nExample block:\nagent_starts: 5\nagent_time_ms: 6000\nmeasurement_scope: invocation')")"

ANC='<!-- write_task_section section=verification_output -->'
expect "spec containing the exact anchor line + example lines, empty Verification Output -> escalate" escalate \
  "$(guard "$(vo exactanchor "" $'```\n'"$ANC"$'\nagent_starts: 5\nagent_time_ms: 6000\nmeasurement_scope: invocation\n```')")"
expect "spec containing the exact anchor line, real block present -> close" close \
  "$(guard "$(vo exactanchor2 "$OK$GW" $'```\n'"$ANC"$'\nagent_starts: 0\n```')")"
expect "measurement lines in the section after Verification Output -> escalate" escalate \
  "$(guard "$(vo after $'## 🏁 COMPLETION SUMMARY (Post-Mortem)\nagent_starts: 5\nagent_time_ms: 6000\nmeasurement_scope: invocation')")"
expect "markers split across fence and block (agent_starts only in fence) -> escalate" escalate \
  "$(guard "$(vo split $'agent_time_ms: 6000\nmeasurement_scope: invocation\n**Test command:** `x`\n```\nagent_starts: 5\n```')")"
expect "block without any Test command line (next ## ends it) -> close" close "$(guard "$(vo nocmd "$OK")")"
expect "trailing whitespace on a marker -> escalate" escalate \
  "$(guard "$(vo ws $'agent_starts: 5 \nagent_time_ms: 6000\nmeasurement_scope: invocation\n'"$GW")")"

# Structure: the guard runs before auto-close and escalates as close_gate "measurement missing".
AUTO="$(printf '%s\n' "$S14" | awk '/^\*\*Autonomous caller/{on=1} on{print}')"
printf '%s\n' "$AUTO" | grep -qF 'first run the measurement guard, then auto-invoke `/close_task`' \
  && pass "guard ordered before auto /close_task" || fail "Step 14 does not order the guard before /close_task"
printf '%s\n' "$AUTO" | grep -F 'measurement missing' | grep -qF -- '--state close_gate' \
  && pass "guard failure queues close_gate 'measurement missing'" || fail "guard escalation line missing"
# The guard adds no branch: still exactly 3 branch headings per mode (Steps 8/9/14).
expect "Autonomous caller (Orchestrator) branch headings == 3" 3 "$(grep -c '^\*\*Autonomous caller (Orchestrator) —' "$EXEC_MD")"
expect "Interactive caller (human) branch headings == 3" 3 "$(grep -c '^\*\*Interactive caller (human) —' "$EXEC_MD")"
expect "Step 14 has one Autonomous branch heading" 1 "$(printf '%s\n' "$S14" | grep -c 'Autonomous caller (Orchestrator)')"
HUMAN="$(printf '%s\n' "$S14" | awk '/^\*\*Autonomous caller/{exit} {print}')"
printf '%s\n' "$HUMAN" | grep -qF 'MEAS_BLOCK' && fail "interactive close gate must not run the guard" || pass "interactive close gate has no guard"

AS="$(block_body 'Agent starts')"
for s in 'resumes of an existing agent are not new starts' 'Keep a running count; Step 13 records it.' 'every `pm-reviewer` round' 'every builder including fix builders' 'every `test-verifier` iteration'; do
  printf '%s\n' "$AS" | grep -qF -- "$s" && pass "Agent starts rule: '$s'" || fail "Agent starts block lacks '$s'"
done

# Step 8: pm-reviewer is timed (timer started after the rubric passes, emit uses auto, never 0).
S8="$(step_body 8)"
printf '%s\n' "$S8" | grep -F 'Exit 0' | grep -qF 'telemetry_start.sh spec_gate' && pass "spec_gate timer starts on rubric exit 0" || fail "spec_gate timer not on the rubric-pass line"
printf '%s\n' "$S8" | grep -qF 'emit_telemetry.sh spec_gate <approve|flag> auto null Orchestrator' && pass "spec_gate emitted with auto duration" || fail "spec_gate emit not auto"
printf '%s\n' "$S8" | grep -qF 'spec_gate <approve|flag> 0' && fail "spec_gate still hard-codes 0" || pass "spec_gate no longer hard-codes 0"
# Exercise the pair through the real scripts: a timed spec_gate row is non-zero and counted by --since.
V="$TMP/v"; mk_vault "$V"
( cd "$V" && .vault_link/.scripts/telemetry_start.sh spec_gate "T" \
  && TF="$(ls 04_Logs/Telemetry/.timers/spec_gate__T.tmp)" \
  && printf '%s\n' "$(( $(cat "$TF") - 4000 ))" > "$TF" \
  && .vault_link/.scripts/emit_telemetry.sh spec_gate approve auto null Orchestrator "T" ) >/dev/null 2>&1
D="$(cat "$V"/04_Logs/Telemetry/*.jsonl 2>/dev/null | jq -r 'select(.macro=="spec_gate") | .duration_ms' | tail -n 1)"
[ -n "$D" ] && [ "$D" -ge 4000 ] && pass "timed spec_gate row carries measured duration ($D ms)" || fail "spec_gate duration not measured: [$D]"
OUT="$(TELEMETRY_DIR="$V/04_Logs/Telemetry" bash "$V/.scripts/telemetry_task_report.sh" --task T --since 2000-01-01T00:00:00Z 2>&1)"
printf '%s\n' "$OUT" | head -n 1 | grep -qE "^agent_time_ms: $D\$" && pass "pm-reviewer time counted in agent_time_ms" || fail "report did not count spec_gate: [$OUT]"
finish

#!/usr/bin/env bash
# DoD3 (interactive): after a builder failure the coordinator runs only the § Builder failure
# commands, verbatim from the runbook, in a sandbox vault: the invoke_builders error record lands,
# the HALT offers exactly retry | panel | abort, a retry restarts the timer for a fresh builder,
# and the failure panel can be convened once per task, then only retry or abort remain.
. "$(dirname "$0")/_lib.sh"
sandbox; project

section "$ET" '^## Builder failure$' > "$TMP/bf"
[ -s "$TMP/bf" ] && pass "§ Builder failure exists" || { fail "§ Builder failure missing"; done_; }

# Every command the section tells the coordinator to run is a .vault_link/.scripts/ call (no file tool, no Bash write).
CMDS="$(awk '/^[[:space:]]*```/{f=!f;next} f' "$TMP/bf" | sed 's/^[[:space:]]*//' | grep -v '^--' | grep -v '^$')"
BAD="$(printf '%s\n' "$CMDS" | grep -v '^\.vault_link/\.scripts/' || true)"
[ -z "$BAD" ] && pass "section's fenced commands are vault scripts only" || fail "non-script command in § Builder failure: $BAD"
# Inline script calls, normalised to the .vault_link/.scripts/ prefix whether or not the prose spells it out.
INLINE="$(grep -oE '`(\.vault_link/\.scripts/)?(telemetry_start|panel_guard)\.sh [^`]+`' "$TMP/bf" | tr -d '`' | sed -E 's#^(telemetry_start|panel_guard)#.vault_link/.scripts/\1#')"
printf '%s\n' "$INLINE" | grep -q 'telemetry_start.sh invoke_builders' && printf '%s\n' "$INLINE" | grep -q 'panel_guard.sh' \
  && pass "retry and panel routes run vault scripts" || fail "retry/panel inline commands missing"

# HALT menu: exactly one menu line, and its reply set is exactly retry, panel, abort.
HALT="$(grep -oE '> \*\*Builder failed \(<kind>\)\.\*\* Reply [^.]*\.' "$TMP/bf")"
eq "exactly one HALT menu line" "$(printf '%s\n' "$HALT" | grep -c 'Builder failed')" 1
eq "HALT replies are exactly retry panel abort" "$(printf '%s' "$HALT" | sed 's/.*Reply//' | grep -oE '`[a-z]+`' | tr -d '`' | tr '\n' ' ')" "retry panel abort "
for r in retry panel abort; do grep -qE "^[[:space:]]*- \`$r\` →" "$TMP/bf" && pass "route defined for $r" || fail "no route for $r"; done
grep -qF 'Any other reply → show the menu again.' "$TMP/bf" && pass "unknown reply re-shows the menu" || fail "unknown reply not handled"

# Step 10 starts the timer; the failure emits the error record and consumes it.
START="$(grep -oE '`\.vault_link/\.scripts/telemetry_start\.sh invoke_builders "<Task_Name>"`' "$ET" | head -n 1 | tr -d '`' | sub_task)"
EMIT="$(fenced "$TMP/bf" 'emit_telemetry\.sh invoke_builders error' | sub_task)"
run_block "$START" TELEMETRY_DIR="$SB/04_Logs/Telemetry"; eq "Step 10 timer start exit 0" "$RC" 0
run_block "$EMIT" TELEMETRY_DIR="$SB/04_Logs/Telemetry"; eq "builder-failure emit exit 0" "$RC" 0
REC="$(grep '"invoke_builders"' "$TEL" 2>/dev/null | tail -n 1)"
for f in '"status":"error"' '"E2"' "\"$TASK\"" '"Executioner"'; do
  case "$REC" in *"$f"*) pass "error record has $f" ;; *) fail "error record lacks $f (got '$REC')" ;; esac
done
[ ! -f "$SB/04_Logs/Telemetry/.write_failures.log" ] || ! grep -q 'missing-timer' "$SB/04_Logs/Telemetry/.write_failures.log" \
  && pass "error emit consumed the Step 10 timer" || fail "error emit found no timer"

# retry: restart the timer, then the fresh builder's success emit (Step 10 line) has a timer too.
RETRY="$(printf '%s\n' "$INLINE" | grep 'telemetry_start.sh invoke_builders' | head -n 1 | sub_task)"
section "$ET" '^## Step 10 ' > "$TMP/s10"
OK="$(fenced "$TMP/s10" 'emit_telemetry\.sh invoke_builders success' | sub_task)"
run_block "$RETRY" TELEMETRY_DIR="$SB/04_Logs/Telemetry"; run_block "$OK" TELEMETRY_DIR="$SB/04_Logs/Telemetry"
eq "after retry: one error + one success invoke_builders record" "$(grep '"invoke_builders"' "$TEL" | grep -c '"status":"error"')/$(grep '"invoke_builders"' "$TEL" | grep -c '"status":"success"')" "1/1"
! grep -q 'missing-timer' "$SB/04_Logs/Telemetry/.write_failures.log" 2>/dev/null && pass "retry builder ran with a fresh timer" || fail "retry success emit had no timer"

# panel: interactive run id is 'interactive'; first convene allowed, second refused (exit 3 -> retry|abort only).
PANEL="$(printf '%s\n' "$INLINE" | grep 'panel_guard.sh' | head -n 1 | sub_task)"
run_block "$PANEL"; eq "first panel convene allowed (exit 0)" "$RC" 0
grep -qxF "$TASK" "$SB/04_Logs/Orchestrator/.panel_convened.interactive" 2>/dev/null && pass "panel recorded under run id 'interactive'" || fail "panel state not recorded as interactive"
run_block "$PANEL"; eq "second panel convene refused (exit 3)" "$RC" 3
grep -qF 'Exit 3 → the panel was already used for this task; HALT with `retry` or `abort` only.' "$TMP/bf" && pass "exit 3 narrows the menu to retry|abort" || fail "exit 3 routing missing"

# abort leaves the task in_progress and resumable; never a takeover.
grep -qF 'Task remains in_progress; re-invoke /execute_task to resume from the spec gate.' "$TMP/bf" && pass "abort keeps task in_progress" || fail "abort message missing"
grep -qF "never resume or continue the failed builder" "$TMP/bf" && pass "failed builder is never resumed" || fail "stop-builder rule missing"
grep -qF 'spawn a fresh builder (a new start; never the failed agent)' "$TMP/bf" && pass "retry is a fresh builder" || fail "retry fresh-builder rule missing"
done_

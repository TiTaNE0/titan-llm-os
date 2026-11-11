#!/usr/bin/env bash
# DoD3 (Orchestrator): under a run id there is no menu; the section's queue command, verbatim,
# lands a no_progress entry in the sandbox Needs_Attention queue, and Step 16 can report it.
. "$(dirname "$0")/_lib.sh"
sandbox; project
section "$ET" '^## Builder failure$' > "$TMP/bf"

grep -qF 'Under an Orchestrator run (`$ORCH_RUN_ID` non-empty) there is no menu and no HALT:' "$TMP/bf" && pass "Orchestrator branch has no menu/HALT" || fail "Orchestrator no-HALT rule missing"
Q="$(fenced "$TMP/bf" 'queue_attention\.sh' | sub_task | sed 's/<kind>/killed/')"
[ -n "$Q" ] && pass "queue command found" || { fail "queue command missing"; done_; }
RID="run-20261111T000000Z"
run_block "$Q" ORCH_RUN_ID="$RID" TELEMETRY_DIR="$SB/04_Logs/Telemetry"
eq "queue_attention accepts the no_progress escalation (exit 0)" "$RC" 0
E="$(grep -F "[[$TASK]]" "$SB/Needs_Attention.md" 2>/dev/null)"
for f in 'state: no_progress' 'source: orchestrator' "run_id: $RID" 'reason: builder failure: killed'; do
  case "$E" in *"$f"*) pass "queue entry has '$f'" ;; *) fail "queue entry lacks '$f' (got '$E')" ;; esac
done
eq "exactly one queue entry" "$(grep -cF "[[$TASK]]" "$SB/Needs_Attention.md" 2>/dev/null)" 1
grep -qF 'Then skip to Step 15; the Step 16 outcome is `queued no_progress`.' "$TMP/bf" && pass "routes to Step 15 with outcome queued no_progress" || fail "Step 15 routing missing"
section "$ET" '^## Step 16' | grep -qF '| queued no_progress>' && pass "Step 16 outcome list includes queued no_progress" || fail "Step 16 lacks queued no_progress"
done_

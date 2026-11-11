#!/usr/bin/env bash
# DoD5: /close_task's evidence guard, run verbatim from the runbook the harness loads, against a task
# shaped like the Grok incident (fresh task template: Validator Report and Verification Output never
# written) and against a real archived task closed through the full chain.
. "$(dirname "$0")/_lib.sh"
sandbox; project

section "$CT" '^## Step 4\.4 ' > "$TMP/s44"
EV="$(fenced "$TMP/s44" '^EV_RC=0; EV_MISSING=""')"
[ -n "$EV" ] && pass "Step 4.4 guard block found" || { fail "Step 4.4 guard block missing"; done_; }
guard() { run_block "$EV"'
printf "%s|%s" "$EV_RC" "$EV_MISSING"' TASK_PATH="$1" "${@:2}"; }

# Incident-shaped task: the real task template, in_progress, evidence sections untouched.
INC="$SB/02_Tasks/P/$TASK.md"
sed -e 's/^status: todo/status: in_progress/' "$VAULT/00_Templates/Task_Template.md" > "$INC"
BEFORE="$(cksum < "$INC")"
guard "$INC"; eq "incident task (no validator, no gateway) is refused" "$OUT" "3|§ Validator Report, § Verification Output"
MISSING="${OUT#*|}"

# A real task that went through validator + gateway closes.
REAL="$(find "$VAULT/99_Archive" -name 'CODEMAP_Per_Project_Refresh_At_Close.md' -path '*TiTan_LLM_OS*' 2>/dev/null | head -n 1)"
if [ -n "$REAL" ]; then cp "$REAL" "$TMP/real.md"; guard "$TMP/real.md"; eq "real chain-closed task passes the guard" "$OUT" "0|"
else fail "archived reference task not found"; fi

# Orchestrator refusal: queue close_gate + E3 telemetry, verbatim; the task file is left untouched and in_progress.
ORCH="$(fenced "$TMP/s44" 'queue_attention\.sh' | sub_task | sed "s/<EV_MISSING>/$MISSING/")"
RID="run-20261111T000000Z"
run_block "$ORCH" ORCH_RUN_ID="$RID" TELEMETRY_DIR="$SB/04_Logs/Telemetry"; eq "Orchestrator refusal commands exit 0" "$RC" 0
grep -F "[[$TASK]]" "$SB/Needs_Attention.md" 2>/dev/null | grep -qF "state: close_gate | source: orchestrator | run_id: $RID" \
  && pass "close_gate queued for the human" || fail "close_gate entry missing"
grep -F "[[$TASK]]" "$SB/Needs_Attention.md" 2>/dev/null | grep -qF "reason: evidence missing: § Validator Report, § Verification Output" \
  && pass "queue reason names the empty sections" || fail "queue reason wrong"
grep '"close_task"' "$TEL" 2>/dev/null | grep '"status":"error"' | grep -q '"E3"' && pass "close_task error E3 telemetry emitted" || fail "close_task E3 telemetry missing"
eq "task file untouched after refusal" "$(cksum < "$INC")" "$BEFORE"
grep -qx 'status: in_progress' "$INC" && pass "task stays in_progress" || fail "task status changed"
grep -qF 'do not run Steps 4.5-10' "$TMP/s44" && pass "Orchestrator refusal ends /close_task before 4.5" || fail "end-of-close rule missing"

# An Orchestrator close cannot use the override.
guard "$INC" EVIDENCE_OVERRIDE=1 ORCH_RUN_ID="$RID"; eq "override ignored under --run-id" "${OUT%%|*}" 3

# The guard runs before anything that commits, summarises or flips status.
g="$(grep -nF 'EV_RC=0; EV_MISSING=""' "$CT" | head -n 1 | cut -d: -f1)"
for s in 'commit_task.sh --task-path' 'populate_summary.sh \' 'set_task_status.sh \'; do
  l="$(grep -nF -- ".vault_link/.scripts/$s" "$CT" | head -n 1 | cut -d: -f1)"
  [ -n "$g" ] && [ -n "$l" ] && [ "$g" -lt "$l" ] && pass "guard precedes ${s%% *}" || fail "guard does not precede ${s%% *}"
done

# Interactive refusal tells the human both ways forward.
grep -qF '"E3: refusing to close — <EV_MISSING> empty. Task stays in_progress. Run /execute_task to produce the evidence, or re-run /close_task [[<Task_Name>]] --override-evidence to close without it."' "$TMP/s44" \
  && pass "interactive E3 message offers /execute_task or --override-evidence" || fail "interactive E3 message missing"

# Autonomous callers never pass the override.
grep -qF -- '--override-evidence' "$ET" && fail "execute_task.md passes --override-evidence" || pass "/execute_task never passes the override"
grep -qF -- '--override-evidence' "$VAULT/.claude/commands/orchestrator_tick.md" 2>/dev/null && fail "orchestrator_tick passes the override" || pass "Orchestrator tick never passes the override"
grep -qF '`/close_task [[<Task_Name>]] --run-id $ORCH_RUN_ID`' "$ET" && pass "Step 14 autonomous close invocation unchanged" || fail "Step 14 invocation changed"
done_

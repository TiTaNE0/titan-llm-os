#!/usr/bin/env bash
# DoD5: a human-typed --override-evidence lets the close proceed, and the override is visible in the
# completion summary template and in the daily log line Step 8 writes (run verbatim in a sandbox vault).
. "$(dirname "$0")/_lib.sh"
sandbox; project

section "$CT" '^## Invocation' | grep -qF -- '`--override-evidence` (optional) sets `EVIDENCE_OVERRIDE=1`' && pass "invocation parses --override-evidence" || fail "invocation lacks --override-evidence parsing"
section "$CT" '^## Invocation' | grep -qF 'ignored when `--run-id` is present' && pass "override ignored with --run-id (documented)" || fail "run-id exclusion missing"

section "$CT" '^## Step 4\.4 ' > "$TMP/s44"
EV="$(fenced "$TMP/s44" '^EV_RC=0; EV_MISSING=""')"
INC="$SB/02_Tasks/P/$TASK.md"
sed -e 's/^status: todo/status: in_progress/' "$VAULT/00_Templates/Task_Template.md" > "$INC"
run_block "$EV"'
printf "%s|%s" "$EV_RC" "$EV_MISSING"' TASK_PATH="$INC" EVIDENCE_OVERRIDE=1
eq "override lets the close continue and keeps what was missing" "$OUT" "0|§ Validator Report, § Verification Output"
MISSING="${OUT#*|}"

section "$CT" '^## Step 5 ' > "$TMP/s5"
grep -qF '**Evidence override:** <none | yes — <EV_MISSING> empty>' "$TMP/s5" && pass "summary template records the override" || fail "summary override line missing"
grep -qF '**Validator verdict:** <SHIP|FIX REQUIRED|BLOCK|n/a>' "$TMP/s5" && pass "summary verdict allows n/a" || fail "summary verdict lacks n/a"

# Step 8: build <EVIDENCE_NOTE> from the runbook's own definition, then run the append verbatim.
section "$CT" '^## Step 8 ' > "$TMP/s8"
NOTE_T="$(grep -F '`<EVIDENCE_NOTE>` is empty when no override was used, else' "$TMP/s8" | sed -E 's/.*else `([^`]*)`.*/\1/')"
NOTE="${NOTE_T//<EV_MISSING>/$MISSING}"
eq "EVIDENCE_NOTE definition" "$NOTE" " Evidence override: § Validator Report, § Verification Output empty."
LOG="$(fenced "$TMP/s8" '^TODAY=' | sub_task | sed -e 's/<Project>/P/' -e 's/<verdict>/n\/a/' -e 's/<PASS|FAIL>/FAIL/')"
LOG="${LOG//<EVIDENCE_NOTE>/$NOTE}"
run_block "$LOG" TELEMETRY_DIR="$SB/04_Logs/Telemetry"; eq "Step 8 append exit 0" "$RC" 0
grep -qxF "Closed [[$TASK]] (P). Validator: n/a. Verification: FAIL. Evidence override: § Validator Report, § Verification Output empty." "$SB/04_Logs/$(date +%Y-%m-%d).md" 2>/dev/null \
  && pass "daily log line records the override" || fail "daily log line lacks the override ($(cat "$SB/04_Logs/$(date +%Y-%m-%d).md" 2>/dev/null))"

# Without the override the same Step 8 line carries no note.
LOG0="$(fenced "$TMP/s8" '^TODAY=' | sub_task | sed -e 's/<Project>/P/' -e 's/<verdict>/SHIP/' -e 's/<PASS|FAIL>/PASS/' -e 's/<EVIDENCE_NOTE>//')"
run_block "$LOG0" TELEMETRY_DIR="$SB/04_Logs/Telemetry"
grep -qxF "Closed [[$TASK]] (P). Validator: SHIP. Verification: PASS." "$SB/04_Logs/$(date +%Y-%m-%d).md" && pass "normal close log line unchanged" || fail "normal close log line changed"
section "$CT" '^## Reminders' | grep -qF 'only a human-typed `--override-evidence` passes it' && pass "Reminders restate the guard" || fail "Reminders bullet missing"
done_

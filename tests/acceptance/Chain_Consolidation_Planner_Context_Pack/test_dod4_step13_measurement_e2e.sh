#!/usr/bin/env bash
# DoD 4: Verification Output records agent starts and agent time of the run. Executes the Step 13
# GW_RC=0 measurement + composition block and the Step 14 guard, extracted verbatim from
# execute_task.md, in a temp vault with fixture telemetry. The agent-start count is a literal the
# coordinator supplies (<N>); the test passes a fixed fixture value, never an env override.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

S13="$(step_body 13 | awk '/^ +SINCE=""; SCOPE=""/{on=1} on{print} on && /^ +rm -f "\$CONTENT_FILE"/{exit}' | sed -E 's/^     //')"
S14_GUARD="$(step_body 14 | awk '/^MEAS_BLOCK=\$\(awk/{on=1} on{print} on && /measurement_scope: \(run/{exit}')"
[ -n "$S13" ] || { fail "Step 13 measurement block not found"; finish; }
[ -n "$S14_GUARD" ] || { fail "Step 14 measurement guard not found"; finish; }
printf '%s\n' "$S13" | head -n 1 | grep -q '^SINCE=""' && printf '%s\n' "$S13" | grep -q '^VERIF_EOF$' || fail "Step 13 block extraction malformed"

VG_RAW_FIXTURE=$'GATEWAY_CMD=bash tests/x.sh\nGATEWAY_EXIT=0\n--- GATEWAY OUTPUT ---\nagent_starts: 9\nagent_time_ms: 1\nmeasurement_scope: invocation\nALL GREEN'

# run13 <vault> <task-path> <task-name> <orch-run-id or ""> <N>: run the Step 13 block from the vault root.
run13() {
  local body; body="${S13//<Task_Name>/$3}"; body="${body//<N>/$5}"
  ( cd "$1" && TASK_PATH="$2" ORCH_RUN_ID="$4" VG_RAW="$VG_RAW_FIXTURE" bash -c "$body" ) >"$TMP/s13_out" 2>&1
}
guard() { TASK_PATH="$1" bash -c "$S14_GUARD" >/dev/null 2>&1 && echo close || echo escalate; }
meas_lines() { section_body "$1" verification_output | awk '/^\*\*Test command:\*\*/{exit} NF{print}'; }
row() { printf '{"ts":"%s","macro":"%s","duration_ms":%s,"task":"%s","status":"success"}\n' "$@"; }

# ---- Orchestrator run: since = start instant of orchestrator_run_id read via task_owner.sh --get.
V="$TMP/orch"; mk_vault "$V"; T="$V/02_Tasks/P/T.md"; mk_task "$T" run-20261108T110000Z
{
  row 2026-11-08T10:59:59Z invoke_researcher 400 T
  row 2026-11-08T11:00:00Z invoke_planner 1500 T
  row 2026-11-08T11:20:00Z spec_gate 0 T
  row 2026-11-08T11:40:00Z invoke_builders 3000 T
  row 2026-11-08T11:50:00Z invoke_test_verifier 700 T
  row 2026-11-08T12:00:00Z invoke_validator 800 T
  row 2026-11-08T12:00:00Z invoke_planner 5000 Other
} > "$V/04_Logs/Telemetry/2026-11.jsonl"
run13 "$V" "$T" T run-20261108T110000Z 5 || fail "orchestrator Step 13 block failed: $(cat "$TMP/s13_out")"
expect "orchestrator: measurement block" \
  $'agent_starts: 5\nagent_time_ms: 6000\nzero_duration_rows: 1\nmeasurement_scope: run run-20261108T110000Z' "$(meas_lines "$T")"
VO="$(section_body "$T" verification_output)"
first_meas="$(printf '%s\n' "$VO" | grep -n '^agent_starts:' | head -n 1 | cut -d: -f1)"
first_cmd="$(printf '%s\n' "$VO" | grep -n '^\*\*Test command:\*\*' | head -n 1 | cut -d: -f1)"
[ -n "$first_meas" ] && [ -n "$first_cmd" ] && [ "$first_meas" -lt "$first_cmd" ] \
  && pass "measurement precedes **Test command:** in the same write" || fail "measurement not before Test command (meas=$first_meas cmd=$first_cmd)"
printf '%s\n' "$VO" | grep -qF '**Test command:** `bash tests/x.sh`' && printf '%s\n' "$VO" | grep -qF '**Exit code:** 0' \
  && pass "gateway block still recorded" || fail "gateway block missing from Verification Output"
expect "one verification_output anchor (single write)" 1 "$(grep -cF '<!-- write_task_section section=verification_output -->' "$T")"
expect "Step 14 guard closes a measured orchestrator run" close "$(guard "$T")"

# Frontmatter run id is re-read at Step 13, not taken from the coordinator's variable.
V2="$TMP/orch2"; mk_vault "$V2"; T2="$V2/02_Tasks/P/T.md"; mk_task "$T2" run-20261108T120000Z
cp "$V/04_Logs/Telemetry/2026-11.jsonl" "$V2/04_Logs/Telemetry/"
run13 "$V2" "$T2" T run-19990101T000000Z 5 || fail "Step 13 (stale var) failed: $(cat "$TMP/s13_out")"
expect "since comes from task_owner.sh --get" \
  $'agent_starts: 5\nagent_time_ms: 800\nzero_duration_rows: 0\nmeasurement_scope: run run-20261108T120000Z' "$(meas_lines "$T2")"

# No telemetry in scope -> agent_time_ms unavailable with the report's reason; guard escalates.
V3="$TMP/orch3"; mk_vault "$V3"; T3="$V3/02_Tasks/P/T.md"; mk_task "$T3" run-20261108T130000Z
cp "$V/04_Logs/Telemetry/2026-11.jsonl" "$V3/04_Logs/Telemetry/"
run13 "$V3" "$T3" T run-20261108T130000Z 4 || fail "Step 13 (no rows) failed: $(cat "$TMP/s13_out")"
expect "no rows in scope -> unavailable with reason" \
  $'agent_starts: 4\nagent_time_ms: unavailable (no telemetry rows for T since 2026-11-08T13:00:00Z)\nmeasurement_scope: run run-20261108T130000Z' "$(meas_lines "$T3")"
expect "Step 14 guard escalates when agent time is unavailable" escalate "$(guard "$T3")"

# Malformed run id -> unavailable (run id malformed); guard escalates.
V4="$TMP/orch4"; mk_vault "$V4"; T4="$V4/02_Tasks/P/T.md"; mk_task "$T4" run-2026-11-08
run13 "$V4" "$T4" T run-2026-11-08 4 || fail "Step 13 (malformed id) failed: $(cat "$TMP/s13_out")"
meas_lines "$T4" | grep -qx 'agent_time_ms: unavailable (run id malformed)' && pass "malformed run id -> unavailable (run id malformed)" || fail "malformed run id: $(meas_lines "$T4" | tr '\n' '|')"
expect "Step 14 guard escalates on malformed run id" escalate "$(guard "$T4")"

# ---- Interactive run: since = Step 1 execute_task timer (task name with spaces -> '_' key).
V5="$TMP/inter"; mk_vault "$V5"; T5="$V5/02_Tasks/P/T.md"; mk_task "$T5"
NAME="My Task (v2)"
( cd "$V5" && .vault_link/.scripts/telemetry_start.sh execute_task "$NAME" )
TF="$(ls "$V5/04_Logs/Telemetry/.timers/"execute_task__*.tmp 2>/dev/null | head -n 1)"
[ -n "$TF" ] || fail "telemetry_start.sh wrote no execute_task timer"
START_EPOCH="$(date -u -j -f '%Y-%m-%dT%H:%M:%SZ' 2026-11-08T11:00:00Z +%s 2>/dev/null || date -u -d 2026-11-08T11:00:00Z +%s)"
printf '%s\n' "$((START_EPOCH * 1000 + 250))" > "$TF"
{
  row 2026-11-08T10:59:59Z invoke_planner 900 "$NAME"
  row 2026-11-08T11:00:00Z invoke_planner 1200 "$NAME"
  row 2026-11-08T11:30:00Z invoke_builders 0 "$NAME"
  row 2026-11-08T12:00:00Z invoke_validator 300 "$NAME"
} > "$V5/04_Logs/Telemetry/2026-11.jsonl"
run13 "$V5" "$T5" "$NAME" "" 4 || fail "interactive Step 13 block failed: $(cat "$TMP/s13_out")"
expect "interactive: measurement block from the Step 1 timer" \
  $'agent_starts: 4\nagent_time_ms: 1500\nzero_duration_rows: 1\nmeasurement_scope: invocation' "$(meas_lines "$T5")"
expect "guard accepts an invocation-scoped block" close "$(guard "$T5")"

# Interactive with no timer -> unavailable (timer missing).
V6="$TMP/inter2"; mk_vault "$V6"; T6="$V6/02_Tasks/P/T.md"; mk_task "$T6"
run13 "$V6" "$T6" "$NAME" "" 4 || fail "interactive (no timer) failed: $(cat "$TMP/s13_out")"
expect "interactive without timer" \
  $'agent_starts: 4\nagent_time_ms: unavailable (timer missing)\nmeasurement_scope: invocation' "$(meas_lines "$T6")"
finish

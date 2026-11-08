#!/usr/bin/env bash
# DoD 3: a small report script prints per-task agent time vs wall-clock from
# telemetry; tested on fixture rows (independent fixture from the gateway test).
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

REPORT="$S/telemetry_task_report.sh"
FX="$TMP/fx"; mkdir -p "$FX"
# Task Alpha spans two months' files; one implausible legacy epoch-ms row; one
# malformed line; one non-invoke row that counts for wall-clock only.
cat > "$FX/2026-10.jsonl" <<'J'
{"ts":"2026-10-31T23:59:00Z","macro":"invoke_researcher","status":"success","duration_ms":30000,"error_class":null,"persona":"Executioner","task":"Alpha"}
J
cat > "$FX/2026-11.jsonl" <<'J'
{"ts":"2026-11-01T00:01:00Z","macro":"invoke_builders","status":"success","duration_ms":90000,"error_class":null,"persona":"Executioner","task":"Alpha"}
{"ts":"2026-11-01T00:02:00Z","macro":"execute_task","status":"success","duration_ms":240000,"error_class":null,"persona":"Executioner","task":"Alpha"}
{"ts":"2026-11-01T00:03:00Z","macro":"invoke_validator","status":"success","duration_ms":1762600000000,"error_class":null,"persona":"Executioner","task":"Alpha"}
{"ts":"2026-11-02T10:00:00Z","macro":"invoke_test_verifier","status":"error","duration_ms":7000,"error_class":"E3","persona":"Executioner","task":"Beta Task"}
{"ts":"2026-11-02T10:00:05Z","macro":"metrics","status":"success","duration_ms":10,"error_class":null,"persona":"unknown","task":null}
{this is not json
{"ts":"2026-11-02T10:00:06Z","macro":"invoke_researcher","status":"success","duration_ms":-5,"error_class":null,"persona":"Executioner","task":"Beta Task"}
J
before="$( (cd "$FX" && ls -1A && cat ./*) | cksum )"

out="$(TELEMETRY_DIR="$FX" bash "$REPORT" 2>"$TMP/err")"; rc=$?
echo "$out" > "$TMP/out"
assert "report exits 0" test "$rc" -eq 0
assert "report prints CSV header" sh -c "head -n1 '$TMP/out' | grep -qx 'task,rows,agent_ms,wall_ms,excluded'"
# Alpha: rows 4; agent = 30000+90000 (validator excluded); wall = 00:02:00 - (00:02:00-240s) = 240 s
assert "Alpha: agent time vs wall-clock across month files" grep -qx 'Alpha,4,120000,240000,1' "$TMP/out"
# Beta: rows 2; negative row excluded; agent 7000 (errors still count as agent time); wall 7000
assert "Beta Task: negative row excluded, name with space intact" grep -qx 'Beta Task,2,7000,7000,1' "$TMP/out"
assert "null-task rows not reported" sh -c "! grep -q '^null,\\|^,' '$TMP/out'"
assert "exactly header + 2 task lines" test "$(wc -l < "$TMP/out" | tr -d ' ')" -eq 3
assert "tasks sorted" sh -c "sed -n 2p '$TMP/out' | grep -q '^Alpha,'"

out="$(TELEMETRY_DIR="$FX" bash "$REPORT" --task "Beta Task")"
assert "--task filters to a single task" test "$out" = "$(printf 'task,rows,agent_ms,wall_ms,excluded\nBeta Task,2,7000,7000,1')"

TELEMETRY_DIR="$FX" bash "$REPORT" --bogus >/dev/null 2>"$TMP/err"; rc=$?
assert "unknown flag exits 1" test "$rc" -eq 1
assert "unknown flag prints usage on stderr" grep -qi usage "$TMP/err"

mkdir -p "$TMP/empty"
out="$(TELEMETRY_DIR="$TMP/empty" bash "$REPORT")"; rc=$?
assert "empty telemetry: friendly message, exit 0" sh -c "[ $rc -eq 0 ] && [ '$out' = '(no task-attributed telemetry)' ]"

after="$( (cd "$FX" && ls -1A && cat ./*) | cksum )"
assert "report is read-only (fixture dir unchanged)" test "$before" = "$after"
assert "report emits no telemetry into its own vault" test ! -e "$TDIR"

# End to end: rows written by emit_telemetry.sh feed straight into the report.
start "invoke_researcher" "E2E"; sleep 1
emit invoke_researcher success auto null Executioner "E2E" >/dev/null 2>&1
emit execute_task success 1500 null Executioner "E2E" >/dev/null 2>&1
out="$(TELEMETRY_DIR="$TDIR" bash "$REPORT" --task E2E)"
assert "report reads emit_telemetry output (2 rows, agent>=1000)" \
  sh -c "echo '$out' | tail -n1 | awk -F, '\$1==\"E2E\" && \$2==2 && \$3>=1000 && \$5==0 {ok=1} END{exit !ok}'"

finish

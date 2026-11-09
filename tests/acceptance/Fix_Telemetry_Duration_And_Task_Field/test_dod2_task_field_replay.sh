#!/usr/bin/env bash
# DoD 2: invoke_researcher, invoke_spec_writer, invoke_builders, invoke_test_verifier,
# invoke_validator, execute_task and close_task rows carry a non-null task field
# when run under a task — and their durations are real elapsed times.
#
# Rather than grepping for patterns, this replays the telemetry commands exactly as
# the kit's execute_task.md / close_task.md success path tells the agent to run them,
# each command in its own shell (as separate agent Bash calls are), against a
# mktemp vault reached through a .vault_link symlink.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

TASK_NAME="${SENTINEL}_Accept Task"
WORK="$TMP/project"
mkdir -p "$WORK"
ln -s "$TMP/vault" "$WORK/.vault_link"

[ -f "$KIT_CMDS/execute_task.md" ] && [ -f "$KIT_CMDS/close_task.md" ] \
  || { fail "kit commands not found at $KIT_CMDS"; finish; }

# Success-path telemetry lines in document order. Error-path lines and spec_gate
# (whose status is a <approve|flag> choice) are not part of the happy path.
extract() {
  grep -o '\.vault_link/\.scripts/\(telemetry_start\|emit_telemetry\)\.sh[^`]*' "$1" \
    | sed 's/[[:space:]]*$//' \
    | grep -v ' error ' | grep -v 'emit_telemetry\.sh spec_gate' | grep -v 'telemetry_start\.sh spec_gate' \
    | grep -v '^\.vault_link/\.scripts/emit_telemetry\.sh`\?$'
}
extract "$KIT_CMDS/execute_task.md" > "$TMP/exec_cmds"
extract "$KIT_CMDS/close_task.md" > "$TMP/close_cmds"

assert "execute_task.md yields replayable telemetry lines" test -s "$TMP/exec_cmds"
assert "close_task.md yields replayable telemetry lines" test -s "$TMP/close_cmds"
assert "no unresolved placeholder other than <Task_Name>" \
  sh -c "! sed 's/<Task_Name>//g' '$TMP/exec_cmds' '$TMP/close_cmds' | grep -q '[<>]'"

replay() { # file — one fresh bash per command; pause 1 s before each emit
  while IFS= read -r line; do
    case "$line" in *emit_telemetry*) sleep 1;; esac
    cmd="${line//<Task_Name>/$TASK_NAME}"
    (cd "$WORK" && bash -c "$cmd") >/dev/null 2>>"$TMP/replay_err"
  done < "$1"
}
replay "$TMP/exec_cmds"
replay "$TMP/close_cmds"

assert "replay produced no stderr" test ! -s "$TMP/replay_err"
assert "replay wrote into the temp vault" test -s "$(ls "$TDIR"/*.jsonl 2>/dev/null | head -n1)"

for M in invoke_planner invoke_builders invoke_test_verifier invoke_validator execute_task close_task; do
  n="$(rows | jq -c --arg m "$M" 'select(.macro == $m)' | wc -l | tr -d ' ')"
  assert "$M: at least one row emitted" test "$n" -ge 1
  assert "$M: every row carries the task name" \
    sh -c "cat '$TDIR'/*.jsonl | jq -e -s --arg m '$M' --arg t '$TASK_NAME' '[.[]|select(.macro==\$m)] | length>0 and all(.task==\$t)'"
  assert "$M: duration is a real elapsed time (1 s .. 10 min)" \
    sh -c "cat '$TDIR'/*.jsonl | jq -e -s --arg m '$M' '[.[]|select(.macro==\$m)] | all(.duration_ms>=1000 and .duration_ms<=600000)'"
done

# execute_task spans every phase, so it must be at least as long as any single phase.
assert "execute_task duration covers its sub-phases" \
  sh -c "cat '$TDIR'/*.jsonl | jq -e -s '([.[]|select(.macro==\"execute_task\")|.duration_ms]|max) >= ([.[]|select(.macro|startswith(\"invoke_\"))|.duration_ms]|max)'"

assert "no timer-miss notes during replay" sh -c "! grep -q missing-timer '$FAILS' 2>/dev/null"
assert "every started timer was consumed" sh -c "[ -z \"\$(ls -A '$TDIR/.timers' 2>/dev/null)\" ]"

# Error paths: each documented error emit, run after its phase timer, also carries the task.
grep -o '\.vault_link/\.scripts/emit_telemetry\.sh [a-z_]* error [^`]*' \
  "$KIT_CMDS/execute_task.md" "$KIT_CMDS/close_task.md" | sed 's/^[^:]*://' > "$TMP/err_cmds"
assert "error-path emit lines found" test -s "$TMP/err_cmds"
while IFS= read -r line; do
  M="$(echo "$line" | awk '{print $2}')"
  cmd="${line//<Task_Name>/$TASK_NAME}"; cmd="${cmd//<E-class>/E3}"; cmd="${cmd//E<rc>/E2}"
  start "$M" "$TASK_NAME"
  (cd "$WORK" && bash -c "$cmd") >/dev/null 2>&1
  assert "error row for $M carries task + error_class" \
    sh -c "cat '$TDIR'/*.jsonl | tail -n1 | jq -e --arg m '$M' --arg t '$TASK_NAME' '.macro==\$m and .status==\"error\" and .task==\$t and (.error_class|test(\"^E[0-9]\$\"))'"
done < "$TMP/err_cmds"

# Task given as a wiki-link at emit time matches a timer started with the bare name.
start "${SENTINEL}_wl" "Wiki Task"
sleep 1
emit "${SENTINEL}_wl" success auto null Executioner "[[Wiki Task]]" >/dev/null 2>&1
assert "[[Task]] stripped and shares timer with bare name" \
  sh -c "cat '$TDIR'/*.jsonl | tail -n1 | jq -e '.task==\"Wiki Task\" and .duration_ms>=1000'"

# Quotes and backslashes in a task name keep the row valid JSON.
emit "${SENTINEL}_q" success 5 null Executioner 'Say "hi" \ now' >/dev/null 2>&1
assert "task with quote/backslash round-trips" \
  sh -c "cat '$TDIR'/*.jsonl | tail -n1 | jq -e '.task==\"Say \\\"hi\\\" \\\\ now\"'"

# Rows emitted with no task stay null (not the string "null").
emit "${SENTINEL}_nt" success 5 null Executioner >/dev/null 2>&1
assert "absent task encodes as JSON null" sh -c "cat '$TDIR'/*.jsonl | tail -n1 | jq -e '.task==null'"

finish

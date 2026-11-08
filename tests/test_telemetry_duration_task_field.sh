#!/usr/bin/env bash
# test_telemetry_duration_task_field.sh
#
# Verification Gateway for Fix_Telemetry_Duration_And_Task_Field.
# DoD 1: duration clamp; DoD 2: task field + timer-file durations + kit command
# wiring; DoD 3: per-task report; DoD 4: real telemetry untouched.
# All script runs use a mktemp vault copy. Exit 0 = all assertions pass.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRIPTS="$REPO_ROOT/.scripts"
PROBE="tdtf_probe_$$"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/.scripts"
for f in emit_telemetry.sh telemetry_start.sh telemetry_task_report.sh; do
  cp "$SCRIPTS/$f" "$TMP/.scripts/" 2>/dev/null || true
done
S="$TMP/.scripts"
TDIR="$TMP/04_Logs/Telemetry"
FAILS="$TDIR/.write_failures.log"

FAILED=0
fail() { echo "FAIL: $1" >&2; FAILED=1; }
pass() { echo "ok: $1"; }
check() { # name, command...
  local n="$1"; shift
  if "$@" >/dev/null 2>&1; then pass "$n"; else fail "$n"; fi
}

last_row() { tail -n 1 "$TDIR"/*.jsonl 2>/dev/null | tail -n 1; }
row_count() { cat "$TDIR"/*.jsonl 2>/dev/null | wc -l | tr -d ' '; }
last_has() { last_row | jq -e "$1" >/dev/null 2>&1; }
log_has() { grep -q -- "$1" "$FAILS" 2>/dev/null; }

emit() { bash "$S/emit_telemetry.sh" "$@" 2>"$TMP/stderr"; }

# ---- DoD 1: duration plausibility ----
emit "${PROBE}_a" success 90061000 null Executioner; rc=$?
[ "$rc" -eq 0 ] && last_has '.duration_ms == 0' && log_has 'clamp-duration:90061000' \
  && pass "1a >24h clamped to 0 + note" || fail "1a >24h clamped to 0 + note"

emit "${PROBE}_b" success -5 null Executioner; rc=$?
[ "$rc" -eq 0 ] && last_has ".macro == \"${PROBE}_b\" and .duration_ms == 0" && log_has 'clamp-duration:-5' \
  && pass "1b negative clamped to 0 + note" || fail "1b negative clamped to 0 + note"

emit "${PROBE}_c" success 99999999999999999999 null Executioner; rc=$?
[ "$rc" -eq 0 ] && last_has '.duration_ms == 0' && [ ! -s "$TMP/stderr" ] \
  && pass "1c 20-digit clamped, no arithmetic error" || fail "1c 20-digit clamped, no arithmetic error"

ok=1
emit "${PROBE}_d1" success 1234; last_has '.duration_ms == 1234' || ok=0
emit "${PROBE}_d2" success 86400000; last_has '.duration_ms == 86400000' || ok=0
emit "${PROBE}_d3" success 86400001; last_has '.duration_ms == 0' || ok=0
[ "$ok" -eq 1 ] && pass "1d boundaries" || fail "1d boundaries"

emit "${PROBE}_e" success 0042; last_has '.duration_ms == 42' \
  && pass "1e leading zeros normalised" || fail "1e leading zeros normalised"
bad=0
while IFS= read -r line; do printf '%s' "$line" | jq -e . >/dev/null 2>&1 || bad=1; done < <(cat "$TDIR"/*.jsonl)
[ "$bad" -eq 0 ] && pass "1e all rows valid JSON" || fail "1e all rows valid JSON"

before="$(row_count)"
emit "${PROBE}_f" success abc; rc=$?
[ "$rc" -eq 0 ] && [ "$(row_count)" = "$before" ] && log_has 'reject.*non-numeric-duration:abc' \
  && pass "1f non-numeric rejected, no row" || fail "1f non-numeric rejected, no row"
# 1g: exit 0 on every shape
ok=1
for args in "m s 5" "m s -5" "m s abc" "m" "m s 1 2 3 4 5" "m --x" "m s auto"; do
  # shellcheck disable=SC2086
  bash "$S/emit_telemetry.sh" $args >/dev/null 2>&1 || ok=0
done
[ "$ok" -eq 1 ] && pass "1g always exit 0" || fail "1g always exit 0"

# ---- DoD 2: timer + task field ----
bash "$S/telemetry_start.sh" "${PROBE}_res" "My Task" >/dev/null 2>&1
sleep 1
emit "${PROBE}_res" success auto null Executioner "My Task"
last_has '.duration_ms >= 1000 and .duration_ms <= 10000 and .task == "My Task"' \
  && pass "2a auto duration + task" || fail "2a auto duration + task"
[ -z "$(ls "$TDIR/.timers"/*"${PROBE}_res"* 2>/dev/null)" ] \
  && pass "2a timer removed" || fail "2a timer removed"

emit "${PROBE}_nt" success auto null Executioner "No Start"
last_has '.duration_ms == 0' && log_has 'missing-timer' \
  && pass "2b auto without start" || fail "2b auto without start"

emit "${PROBE}_br" success 5 null Executioner "[[Foo]]"
last_has '.task == "Foo"' && pass "2c wiki wrapper stripped" || fail "2c wiki wrapper stripped"
emit "${PROBE}_q" success 5 null Executioner 'a"b'
last_has '.task == "a\"b"' && pass "2c quote escaped" || fail "2c quote escaped"

# wrapper / plain share a timer
bash "$S/telemetry_start.sh" "${PROBE}_wr" "[[Foo]]" >/dev/null 2>&1
sleep 1
emit "${PROBE}_wr" success auto null Executioner "Foo"
last_has '.duration_ms >= 1000 and .duration_ms <= 10000 and .task == "Foo"' \
  && pass "2c [[Foo]] start matches Foo emit" || fail "2c [[Foo]] start matches Foo emit"
bash "$S/telemetry_start.sh" "${PROBE}_wr2" "Foo" >/dev/null 2>&1
sleep 1
emit "${PROBE}_wr2" success auto null Executioner "[[Foo]]"
last_has '.duration_ms >= 1000 and .duration_ms <= 10000' \
  && pass "2c Foo start matches [[Foo]] emit" || fail "2c Foo start matches [[Foo]] emit"

# 48h-old timer
mkdir -p "$TDIR/.timers"
old=$(( ( $(date +%s) - 172800 ) * 1000 ))
printf '%s\n' "$old" > "$TDIR/.timers/${PROBE}_old__Old_Task.tmp"
emit "${PROBE}_old" success auto null Executioner "Old Task"
last_has '.duration_ms == 0' && log_has 'clamp-duration' \
  && pass "2d stale timer clamped" || fail "2d stale timer clamped"

# kit command wiring
KIT_DIR=""
for d in "${KIT_COMMANDS_DIR:-}" "$REPO_ROOT/.claude/commands" "$HOME/AI_Workflow/claude-agent-kit/project-template/.claude/commands"; do
  [ -n "$d" ] && [ -f "$d/execute_task.md" ] && [ -f "$d/close_task.md" ] && [ -f "$d/orchestrator_tick.md" ] && { KIT_DIR="$d"; break; }
done
if [ -z "$KIT_DIR" ]; then
  fail "kit commands dir not found"
else
  ET="$KIT_DIR/execute_task.md"; CT="$KIT_DIR/close_task.md"; OT="$KIT_DIR/orchestrator_tick.md"
  TN='"<Task_Name>"'
  for m in invoke_researcher invoke_spec_writer invoke_builders invoke_test_verifier invoke_validator execute_task; do
    grep -Eq "telemetry_start\.sh $m \"<Task_Name>\"" "$ET" && grep -Eq "emit_telemetry\.sh $m (success|error) auto .*\"<Task_Name>\"" "$ET" \
      && pass "2e $m wired" || fail "2e $m wired"
  done
  grep -Eq "telemetry_start\.sh close_task \"<Task_Name>\"" "$CT" && grep -Eq "emit_telemetry\.sh close_task (success|error) auto .*\"<Task_Name>\"" "$CT" \
    && pass "2f close_task wired" || fail "2f close_task wired"
  bad=0
  while IFS= read -r l; do case "$l" in *'"<Task_Name>"'*) ;; *) bad=1; echo "  missing task: $l" >&2;; esac; done \
    < <(grep -hE 'emit_telemetry\.sh (invoke_[a-z_]+|execute_task|close_task)' "$ET" "$CT")
  [ "$bad" -eq 0 ] && pass "2g all task-bearing emits carry task" || fail "2g all task-bearing emits carry task"
  if grep -hE 'emit_telemetry\.sh.*(<duration_ms>|START_TS_MS|_START_MS)' "$ET" "$CT" "$OT" | grep -q . \
     || grep -E '(START_TS_MS|_START_MS)=' "$ET" "$CT" "$OT" | grep -q .; then
    fail "2h stale duration vars/placeholders remain"
  else pass "2h no stale duration vars/placeholders"; fi
  grep -q 'telemetry_start\.sh orchestrator_tick' "$OT" \
    && ! grep -h 'emit_telemetry\.sh' "$OT" | grep -v ' auto ' | grep -q . \
    && pass "2i orchestrator_tick wired" || fail "2i orchestrator_tick wired"
fi

# ---- DoD 3: report ----
FX="$TMP/fx"; mkdir -p "$FX"
T0=$(date -j -u -f '%Y-%m-%dT%H:%M:%SZ' '2026-11-01T00:00:00Z' +%s 2>/dev/null || date -u -d '2026-11-01T00:00:00Z' +%s)
iso() { date -u -r $(( T0 + $1 )) +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "@$(( T0 + $1 ))" +%Y-%m-%dT%H:%M:%SZ; }
row() { printf '{"ts":"%s","macro":"%s","status":"success","duration_ms":%s,"error_class":null,"persona":"Executioner","task":%s}\n' "$(iso "$1")" "$2" "$3" "$4"; }
{
  row 100 invoke_researcher 60000 '"A"'
  row 200 invoke_spec_writer 50000 '"A"'
  row 300 execute_task 300000 '"A"'
  row 10 invoke_validator 5000 '"B"'
  row 50 metrics 10 null
  row 60 close_task 20 null
  row 250 invoke_builders 1762600000000 '"A"'
  echo 'not json {'
} > "$FX/2026-11.jsonl"
R="$S/telemetry_task_report.sh"
out="$(TELEMETRY_DIR="$FX" bash "$R" 2>/dev/null)"; rc=$?
exp=$'task,rows,agent_ms,wall_ms,excluded\nA,4,110000,300000,1\nB,1,5000,5000,0'
[ "$rc" -eq 0 ] && [ "$out" = "$exp" ] && pass "3a report fixture" || { fail "3a report fixture"; echo "$out" >&2; }
out="$(TELEMETRY_DIR="$FX" bash "$R" --task B 2>/dev/null)"
[ "$out" = $'task,rows,agent_ms,wall_ms,excluded\nB,1,5000,5000,0' ] && pass "3b --task filter" || fail "3b --task filter"
TELEMETRY_DIR="$FX" bash "$R" --bogus >/dev/null 2>&1; [ $? -eq 1 ] && pass "3c unknown arg exit 1" || fail "3c unknown arg exit 1"
mkdir -p "$TMP/empty"
out="$(TELEMETRY_DIR="$TMP/empty" bash "$R" 2>/dev/null)"; rc=$?
[ "$rc" -eq 0 ] && [ "$out" = "(no task-attributed telemetry)" ] && pass "3d empty dir" || fail "3d empty dir"

# ---- DoD 4: real files untouched ----
n=$(cat "$REPO_ROOT"/04_Logs/Telemetry/*.jsonl "$REPO_ROOT/04_Logs/Telemetry/.write_failures.log" 2>/dev/null | grep -c 'tdtf_probe_' || true)
[ "${n:-0}" -eq 0 ] && pass "4a no probe in real telemetry" || fail "4a no probe in real telemetry"
ls "$REPO_ROOT"/04_Logs/Telemetry/.timers/*tdtf_probe* >/dev/null 2>&1 && fail "4b real timers polluted" || pass "4b no real probe timers"

[ "$FAILED" -eq 0 ] && echo "ALL PASS" || { echo "SOME FAILED" >&2; exit 1; }

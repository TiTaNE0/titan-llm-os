#!/usr/bin/env bash
# DoD 4: agent time of a run is aggregated by telemetry_task_report.sh --since (boundary inclusive,
# invoke_* + spec_gate only, zero-duration rows counted, no rows -> exit 3); default modes unchanged.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
R="$VAULT/.scripts/telemetry_task_report.sh"
D="$TMP/tel"; mkdir -p "$D"
row() { printf '{"ts":"%s","macro":"%s","duration_ms":%s,"task":"%s","status":"success"}\n' "$@"; }
{
  row 2026-11-08T10:00:00Z invoke_researcher 500 T
  row 2026-11-08T11:00:00Z invoke_spec_writer 100 T
  row 2026-11-08T12:00:00Z invoke_planner 1000 T
  row 2026-11-08T12:30:00Z spec_gate 0 T
  row 2026-11-08T12:40:00Z write_task_section 50 T
  row 2026-11-08T12:50:00Z execute_task 9999 T
  row 2026-11-08T13:00:00Z invoke_validator 2000 T
  row 2026-11-08T13:10:00Z invoke_planner 7777 U
  echo '{not json'
} > "$D/2026-11.jsonl"
{
  row 2026-11-08T13:20:00Z invoke_builders 0 T
  row 2026-11-08T13:30:00Z invoke_test_verifier 99999999999 T
} > "$D/2026-12.jsonl"

# rep <args...>: sets RC, OUT, ERR.
rep() { RC=0; OUT="$(TELEMETRY_DIR="$D" bash "$R" "$@" 2>"$TMP/err")" || RC=$?; ERR="$(cat "$TMP/err")"; }

rep --task T --since 2026-11-08T11:00:00Z
expect "boundary run: exit" 0 "$RC"
expect "boundary run: stdout (boundary row in; earlier, wrong macro, other task, implausible excluded; spec_gate + zero rows counted; both files read)" \
  $'agent_time_ms: 3100\nzero_duration_rows: 2' "$OUT"
rep --since 2026-11-08T11:00:00Z --task T
expect "arguments in either order" $'agent_time_ms: 3100\nzero_duration_rows: 2' "$OUT"
rep --task T --since 2026-11-08T11:00:01Z
expect "one second after boundary excludes the boundary row" $'agent_time_ms: 3000\nzero_duration_rows: 2' "$OUT"
rep --task T --since 2026-11-08T12:30:00Z
expect "zero-duration-only start still counts rows" $'agent_time_ms: 2000\nzero_duration_rows: 2' "$OUT"

rep --task T --since 2026-11-08T14:00:00Z
expect "no rows: exit 3" 3 "$RC"; expect "no rows: stderr" "no telemetry rows for T since 2026-11-08T14:00:00Z" "$ERR"; expect "no rows: empty stdout" "" "$OUT"
rep --task Nobody --since 2026-01-01T00:00:00Z
expect "unknown task: exit 3" 3 "$RC"
mkdir -p "$TMP/empty"; RC=0; TELEMETRY_DIR="$TMP/empty" bash "$R" --task T --since 2026-01-01T00:00:00Z >/dev/null 2>&1 || RC=$?
expect "empty telemetry dir in --since mode: exit 3" 3 "$RC"

for bad in "--since 2026-11-08T11:00:00Z" "--task T --since 2026-11-08" "--task T --since 2026-11-08T11:00:00+02:00" "--task T --since" "--bogus"; do
  # shellcheck disable=SC2086
  rep $bad
  [ "$RC" = 1 ] && printf '%s' "$ERR" | grep -q '^usage:' && [ -z "$OUT" ] && pass "bad usage '$bad' -> exit 1 + usage" || fail "bad usage '$bad': exit $RC out [$OUT] err [$ERR]"
done

# Default and --task modes are byte-identical to the committed (pre-change) script.
git -C "$VAULT" show HEAD:.scripts/telemetry_task_report.sh > "$TMP/report_head.sh"
for args in "" "--task T" "--task U" "--task Nobody"; do
  # shellcheck disable=SC2086
  a="$(TELEMETRY_DIR="$D" bash "$R" $args 2>&1; echo "rc=$?")"
  # shellcheck disable=SC2086
  b="$(TELEMETRY_DIR="$D" bash "$TMP/report_head.sh" $args 2>&1; echo "rc=$?")"
  expect "mode '${args:-<no args>}' unchanged vs HEAD" "$b" "$a"
done
finish

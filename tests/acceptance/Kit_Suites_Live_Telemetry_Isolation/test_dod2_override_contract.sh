#!/usr/bin/env bash
# DoD 2: emit_telemetry.sh and telemetry_start.sh honour a TELEMETRY_DIR env override.
# Exercised on byte copies of the live scripts in a scratch vault; default path, row shape
# and exit 0 unchanged when the variable is unset or empty.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
V="$TMP/v"; mkdir -p "$V/.scripts" "$TMP/cwd"
cp "$VAULT/.scripts/emit_telemetry.sh" "$VAULT/.scripts/telemetry_start.sh" "$V/.scripts/"
EMIT="$V/.scripts/emit_telemetry.sh"; START="$V/.scripts/telemetry_start.sh"
DEF="$V/04_Logs/Telemetry"; OV="$TMP/override"; MONTH="$(date -u +%Y-%m)"
KEYS='ts,macro,status,duration_ms,error_class,persona,task'
keys_of() { tail -n 1 "$1" | jq -r 'keys_unsorted | join(",")'; }

TELEMETRY_DIR="$OV" bash "$EMIT" "${SENTINEL}set" success 7 null Executioner Some_Task; rc=$?
expect "override: exit code" 0 "$rc"
expect "override: rows in override dir" 1 "$(rows_in "$OV")"
expect "override: nothing created at default dir" no "$([ -e "$DEF" ] && echo yes || echo no)"
expect "override: row shape" "$KEYS" "$(keys_of "$OV/$MONTH.jsonl")"
expect "override: task field kept" Some_Task "$(jq -r .task "$OV/$MONTH.jsonl")"

env -u TELEMETRY_DIR bash "$EMIT" "${SENTINEL}unset" success 7 null Executioner; rc=$?
expect "unset: exit code" 0 "$rc"
expect "unset: row goes to <vault>/04_Logs/Telemetry" 1 "$(rows_in "$DEF")"
expect "unset: row shape" "$KEYS" "$(keys_of "$DEF/$MONTH.jsonl")"
expect "unset: override dir untouched" 1 "$(rows_in "$OV")"

( cd "$TMP/cwd" && TELEMETRY_DIR= bash "$EMIT" "${SENTINEL}empty" success 7 null Executioner ); rc=$?
expect "empty: exit code" 0 "$rc"
expect "empty: row goes to default dir" 2 "$(rows_in "$DEF")"
expect "empty: nothing written relative to cwd" "" "$(ls -A "$TMP/cwd")"

TELEMETRY_DIR="$OV" bash "$START" "${SENTINEL}phase" Timed_Task; rc=$?
expect "start override: exit code" 0 "$rc"
expect "start override: one timer under override .timers" 1 "$(ls "$OV/.timers" 2>/dev/null | wc -l | tr -d ' ')"
expect "start override: no timer at default" no "$([ -d "$DEF/.timers" ] && [ -n "$(ls -A "$DEF/.timers")" ] && echo yes || echo no)"
sleep 1
TELEMETRY_DIR="$OV" bash "$EMIT" "${SENTINEL}phase" success auto null Executioner Timed_Task
expect "auto: timer consumed from override .timers" 0 "$(ls "$OV/.timers" 2>/dev/null | wc -l | tr -d ' ')"
d="$(grep -F "\"macro\":\"${SENTINEL}phase\"" "$OV/$MONTH.jsonl" | jq -r .duration_ms)"
[ -n "$d" ] && [ "$d" -ge 900 ] && pass "auto: duration from override timer ($d ms)" || fail "auto: duration [$d], want >= 900 (timer key mismatch?)"
grep -q 'missing-timer' "$OV/.write_failures.log" 2>/dev/null && fail "auto: missing-timer note in override" || pass "auto: no missing-timer note"

env -u TELEMETRY_DIR bash "$START" "${SENTINEL}phase2"
expect "start unset: timer at default .timers" 1 "$(ls "$DEF/.timers" 2>/dev/null | wc -l | tr -d ' ')"

TELEMETRY_DIR="$OV" bash "$EMIT" onlyone; rc=$?
expect "reject: exit code" 0 "$rc"
grep -q 'reject' "$OV/.write_failures.log" 2>/dev/null && pass "reject sentinel lands in override dir" || fail "reject sentinel not in override dir"
grep -q 'reject' "$DEF/.write_failures.log" 2>/dev/null && fail "reject sentinel in default dir" || pass "reject sentinel not in default dir"
finish

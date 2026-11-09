#!/usr/bin/env bash
# DoD 1 (behaviour, error path): a /new_task or /retrospective that halts after Step 1 emits the
# error-protocol line from the kit file in a later shell; the row carries the elapsed time and the
# E-class. A halt before Step 1 (no timer) still writes a row, with duration 0 and a missing-timer
# note, instead of a rejected placeholder.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
make_project
for m in new_task retrospective; do
  f="$CMDS/$m.md"
  start="$(step_bash "$f" 1)"
  err="$(grep -oE '\.vault_link/\.scripts/emit_telemetry\.sh '"$m"' error [^`]*' "$f")"
  expect "$m: exactly one error-protocol emit" 1 "$(printf '%s\n' "$err" | grep -c .)"
  err="${err//<E-class>/E4}"
  td="$TMP/td_$m"
  in_new_shell "$td" "$start"; sleep 2; in_new_shell "$td" "$err"
  row="$(lastrow "$td")"
  expect "$m error row status/class" "error/E4" "$(printf '%s' "$row" | jq -r '.status+"/"+.error_class')"
  d="$(printf '%s' "$row" | jq -r '.duration_ms')"
  [ "${d:-x}" -ge 2000 ] 2>/dev/null && [ "$d" -lt 3600000 ] && pass "$m error duration $d ms" || fail "$m error duration [$d]"

  td="$TMP/td_${m}_early"
  in_new_shell "$td" "$err"
  row="$(lastrow "$td")"
  expect "$m pre-Step-1 halt still writes an error row with duration 0" "error/0" "$(printf '%s' "$row" | jq -r '.status+"/"+(.duration_ms|tostring)')"
  grep -q missing-timer "$td/.write_failures.log" 2>/dev/null && pass "$m pre-Step-1 halt notes missing-timer" || fail "$m pre-Step-1 halt left no missing-timer note"
done
finish

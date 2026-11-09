#!/usr/bin/env bash
# DoD 1 (behaviour): run /new_task Step 1 and Step 7, and /retrospective Step 1 and Step 8, as the
# whole fenced bash blocks from the real kit files, each in its own fresh shell (Claude Code keeps
# no variables between Bash calls). The emitted row must carry the real elapsed time. RED: the
# pre-fix block pair, run the same way, yields no usable duration.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
make_project

run_pair() { # <label> <start-block> <emit-block> <td>; prints duration_ms of the last row
  in_new_shell "$4" "$2"; sleep 2; in_new_shell "$4" "$3"
  lastrow "$4" | jq -r '.duration_ms' 2>/dev/null
}
in_range() { [ "${2:-x}" -ge 2000 ] 2>/dev/null && [ "$2" -lt 3600000 ] && pass "$1 duration $2 ms" || fail "$1 duration out of range: [$2]"; }

check() { # <macro> <emit-step>
  local f="$CMDS/$1.md" s e td d row
  s="$(step_bash "$f" 1)"; e="$(step_bash "$f" "$2")"
  [ -n "$s" ] && [ -n "$e" ] || { fail "$1: Step 1 / Step $2 bash block not found"; return; }
  td="$TMP/td_$1"
  d="$(run_pair "$1" "$s" "$e" "$td")"
  in_range "$1 Step 1 -> Step $2 in separate shells" "$d"
  row="$(lastrow "$td")"
  expect "$1 row macro/status" "$1/success" "$(printf '%s' "$row" | jq -r '.macro+"/"+.status')"
  grep -q missing-timer "$td/.write_failures.log" 2>/dev/null && fail "$1: missing-timer note" || pass "$1: timer found"
  expect "$1 timer consumed" 0 "$(find "$td/.timers" -type f -name '*.tmp' 2>/dev/null | wc -l | tr -d ' ')"
}
check new_task 7
check retrospective 8

# RED control: the pre-fix /new_task blocks, verbatim, in separate shells.
old_s='START_TS_MS=$(($(date +%s) * 1000))
.vault_link/.scripts/persona_check.sh Executioner'
old_e='END_TS_MS=$(($(date +%s) * 1000))
.vault_link/.scripts/emit_telemetry.sh new_task success $((END_TS_MS - START_TS_MS)) null Executioner'
d="$(run_pair old "$old_s" "$old_e" "$TMP/td_red")"
[ "${d:-x}" -ge 2000 ] 2>/dev/null && [ "$d" -lt 3600000 ] && fail "RED: pre-fix blocks gave a plausible duration ($d)" || pass "RED: pre-fix blocks give no real duration ($d)"
finish

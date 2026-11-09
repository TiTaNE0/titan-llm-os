#!/usr/bin/env bash
# DoD 1: fields containing comma, double quote or newline are quoted, inner quotes doubled.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
{
  row 2026-11-01T00:00:10Z '"Alpha, Beta"'
  row 2026-11-01T00:00:20Z '"Alpha, Beta"' invoke_validator 500
  row 2026-11-01T00:00:10Z '"\"lead"'
  row 2026-11-01T00:00:10Z '"x,\"y\",z"'
  row 2026-11-01T00:00:10Z '"cr\rhere"'
  row 2026-11-01T00:00:10Z '"multi\nline"'
  row 2026-11-01T00:00:10Z '"Plain_Task"'
} > "$TMP/tel/2026-11.jsonl"
out="$(run)"

# User sees a comma-bearing task with its rows aggregated into a single quoted record.
grep -qxF '"Alpha, Beta",2,1500,11000,0' <<<"$out" && pass "comma field quoted, aggregation intact" || fail "comma field: $out"
grep -qxF '"""lead",1,1000,1000,0' <<<"$out" && pass "leading quote doubled and wrapped" || fail "leading quote"
grep -qxF '"x,""y"",z",1,1000,1000,0' <<<"$out" && pass "mixed comma+quotes" || fail "mixed comma+quotes"
grep -qxF '"multi' <<<"$out" && grep -qxF 'line",1,1000,1000,0' <<<"$out" && pass "LF field quoted across lines" || fail "LF field"
printf '%s' "$out" | grep -q $'^"cr\rhere",1,1000,1000,0$' && pass "CR field quoted" || fail "CR field"

# Any RFC 4180 reader gets exactly 5 columns and the original task names back.
printf '%s\n' "$out" | python3 -I -c '
import csv,sys,io
rows=list(csv.reader(io.StringIO(sys.stdin.read(),newline="")))
assert rows[0]==["task","rows","agent_ms","wall_ms","excluded"], rows[0]
assert all(len(r)==5 for r in rows), rows
want=["Alpha, Beta","\"lead","x,\"y\",z","cr\rhere","multi\nline","Plain_Task"]
assert sorted(r[0] for r in rows[1:])==sorted(want), rows
assert all(r[1].isdigit() and r[2].isdigit() and r[3].isdigit() and r[4].isdigit() for r in rows[1:]), rows
' && pass "python csv round-trip, 5 columns everywhere" || fail "python csv round-trip"

# --task filter with a special-character name returns the same quoted record.
[ "$(run --task 'x,"y",z')" = $'task,rows,agent_ms,wall_ms,excluded\n"x,""y"",z",1,1000,1000,0' ] \
  && pass "--task with special name quoted" || fail "--task with special name"
finish

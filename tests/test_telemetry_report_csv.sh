#!/usr/bin/env bash
# RFC 4180 quoting regression for .scripts/telemetry_task_report.sh.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
R="$REPO_ROOT/.scripts/telemetry_task_report.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/tel"
PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); echo "PASS $1"; }
fail() { FAIL=$((FAIL+1)); echo "FAIL $1"; }

row() { printf '{"ts":"%s","macro":"invoke_builders","status":"success","duration_ms":1000,"task":%s}\n' "$1" "$2"; }
{
  row 2026-11-01T00:00:10Z '"plain"'
  row 2026-11-01T00:00:10Z '"a,b"'
  row 2026-11-01T00:00:10Z '"say \"hi\""'
  row 2026-11-01T00:00:10Z '"line1\nline2"'
} > "$TMP/tel/2026-11.jsonl"
run() { TELEMETRY_DIR="$TMP/tel" bash "$R" "$@" 2>/dev/null; }

out="$(run)"
grep -qxF '"a,b",1,1000,1000,0' <<<"$out" && pass T1 || fail T1
grep -qxF '"say ""hi""",1,1000,1000,0' <<<"$out" && pass T2 || fail T2
grep -qxF '"line1' <<<"$out" && grep -qxF 'line2",1,1000,1000,0' <<<"$out" && pass T3 || fail T3

command -v python3 >/dev/null 2>&1 || { echo "FAIL python3 missing"; exit 1; }
printf '%s\n' "$out" | python3 -I -c '
import csv,sys,io
rows=list(csv.reader(io.StringIO(sys.stdin.read(),newline="")))
assert rows[0]==["task","rows","agent_ms","wall_ms","excluded"]
assert all(len(r)==5 for r in rows), rows
assert sorted(r[0] for r in rows[1:])==sorted(["plain","a,b","say \"hi\"","line1\nline2"]), rows
' && pass T4 || fail T4

[ "$(run --task plain)" = $'task,rows,agent_ms,wall_ms,excluded\nplain,1,1000,1000,0' ] && pass T5 || fail T5
[ "$(run --task 'a,b' --since 2026-01-01T00:00:00Z)" = $'agent_time_ms: 1000\nzero_duration_rows: 0' ] && pass T6 || fail T6

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && { echo "ALL PASS"; exit 0; } || exit 1

#!/usr/bin/env bash
# DoD 2: plain fields byte-identical to pre-change output; --task/--since consumers unchanged.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
# Baseline pinned to 24cf7dc, the last commit before the quoting change, so the check survives the task commit.
git -C "$REPO_ROOT" show 24cf7dc:.scripts/telemetry_task_report.sh > "$TMP/base.sh" 2>/dev/null || { fail "cannot read baseline 24cf7dc"; finish; exit 1; }
base() { TELEMETRY_DIR="$TMP/tel" bash "$TMP/base.sh" "$@" 2>/dev/null; }
{
  row 2026-11-01T00:00:10Z '"Beta Task"'
  row 2026-11-01T00:01:10Z '"Beta Task"' spec_gate 0
  row 2026-11-01T00:00:10Z '"semi;colon"'
  row 2026-11-01T00:00:10Z "\"it's\""
  row 2026-11-01T00:00:10Z '"Ünïcode-задача"'
  row 2026-11-01T00:00:10Z '"tab\there"'
  row 2026-11-01T00:00:10Z '"Bad_Dur"' invoke_builders -5
  echo 'not json'
} > "$TMP/tel/2026-11.jsonl"

cmp -s <(run; echo "rc=$?") <(base; echo "rc=$?") && pass "default report byte-identical for plain names" || fail "default report differs: $(diff <(run) <(base))"
for t in "Beta Task" "semi;colon" "it's" "Bad_Dur" "missing"; do
  cmp -s <(run --task "$t"; echo "rc=$?") <(base --task "$t"; echo "rc=$?") && pass "--task '$t' identical" || fail "--task '$t' differs"
done
for t in "Beta Task" "missing"; do
  a="$(run --task "$t" --since 2026-01-01T00:00:00Z; echo "rc=$?")"
  b="$(base --task "$t" --since 2026-01-01T00:00:00Z; echo "rc=$?")"
  [ "$a" = "$b" ] && pass "--since '$t' identical ($(tr '\n' ' ' <<<"$a"))" || fail "--since '$t': [$a] vs [$b]"
done
[ "$(run --task "Beta Task" --since 2026-01-01T00:00:00Z)" = $'agent_time_ms: 1000\nzero_duration_rows: 1' ] \
  && pass "--since Step 13 contract lines exact" || fail "--since contract"
run --since 2026-01-01T00:00:00Z; [ $? -eq 1 ] && pass "usage exit 1 unchanged" || fail "usage exit"
rm -f "$TMP/tel"/*.jsonl
[ "$(run)" = "(no task-attributed telemetry)" ] && pass "empty-state message unchanged" || fail "empty state"
finish

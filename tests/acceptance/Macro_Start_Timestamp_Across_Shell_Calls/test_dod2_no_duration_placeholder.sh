#!/usr/bin/env bash
# DoD 2: no literal <duration_ms> remains in kit commands or in what install.sh actually generates.
# Runs the real `install.sh setup-opencode` into mktemp dirs (XDG_CONFIG_HOME isolated) and scans
# every generated command, so the OpenCode preflight text is checked as the operator receives it.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
expect "no <duration_ms> in kit command sources" 0 "$(cat "$CMDS"/*.md | grep -cF '<duration_ms>')"
expect "no <duration_ms> in install.sh" 0 "$(grep -cF '<duration_ms>' "$KIT/install.sh")"

for f in execute_task close_task; do
  grep -E '^.{0,6}`?Macro '"$f"' completed' "$CMDS/$f.md" | grep -qE 'completed in ' \
    && fail "$f completion line still reports a duration" || pass "$f completion line has no unsourced duration"
done

OUT="$TMP/oc"
( cd "$KIT" && XDG_CONFIG_HOME="$TMP/xdg" bash install.sh setup-opencode --path "$OUT/agent" --command-path "$OUT/command" ) >"$TMP/setup.log" 2>&1
rc=$?
[ "$rc" = 0 ] || [ "$rc" = 3 ] && pass "setup-opencode ran (rc $rc)" || { fail "setup-opencode rc $rc"; cat "$TMP/setup.log" >&2; }
n="$(ls "$OUT/command"/*.md 2>/dev/null | wc -l | tr -d ' ')"
[ "$n" -ge 1 ] && pass "generated $n OpenCode commands" || fail "no OpenCode commands generated"
expect "no <duration_ms> in generated OpenCode commands" 0 "$(cat "$OUT/command"/*.md 2>/dev/null | grep -cF '<duration_ms>')"
grep -qF 'emit_telemetry.sh execute_task error auto E1 Executioner "<Task_Name>"' "$OUT/command/execute_task.md" 2>/dev/null \
  && pass "generated execute_task preflight emits auto with the task" || fail "generated execute_task preflight emit not auto"
grep -qF 'E1: missing agent/gate binding: <role>' "$OUT/command/execute_task.md" 2>/dev/null \
  && pass "preflight halt text kept" || fail "preflight halt text lost"
finish

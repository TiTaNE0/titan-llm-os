#!/usr/bin/env bash
# DoD 1 (static, kit-wide): no kit command computes a duration from shell arithmetic; every
# emit_telemetry.sh call in kit commands and install.sh passes `auto`, and every macro emitting
# `auto` has a telemetry_start.sh for that macro (install.sh's execute_task preflight relies on
# execute_task.md Step 1). A new command copying the old pattern would fail here.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
srcs=("$CMDS"/*.md "$KIT/install.sh")

n="$(cat "${srcs[@]}" | grep -cE 'START_TS_MS|END_TS_MS|\$\(\([^)]*TS')"
expect "no START_TS_MS/END_TS_MS arithmetic in kit commands or install.sh" 0 "$n"

emits="$(grep -hoE 'emit_telemetry\.sh [a-z_]+ [a-z_]+ [^ `"]+' "${srcs[@]}")"
[ -n "$emits" ] && pass "found emit calls" || fail "no emit_telemetry.sh calls found"
bad="$(printf '%s\n' "$emits" | awk '$4 != "auto"')"
expect "every emit_telemetry.sh call passes auto" "" "$bad"

for f in "$CMDS"/*.md "$KIT/install.sh"; do
  for m in $(grep -hoE 'emit_telemetry\.sh [a-z_]+ [a-z_]+ auto' "$f" | awk '{print $2}' | sort -u); do
    starter="$f"; [ "$f" = "$KIT/install.sh" ] && starter="$CMDS/$m.md"
    grep -qE "telemetry_start\.sh $m( |\$|\`)" "$starter" \
      && pass "$(basename "$f"): $m auto emit has a telemetry_start.sh $m" \
      || fail "$(basename "$f"): $m emits auto but nothing starts its timer"
  done
done
finish

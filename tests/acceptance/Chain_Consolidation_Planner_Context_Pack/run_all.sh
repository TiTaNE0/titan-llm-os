#!/usr/bin/env bash
# Runs every Chain_Consolidation_Planner_Context_Pack acceptance test, then proves the real task
# file, board, session state, telemetry and the kit agent files were not written.
# CHAIN_ACC_SKIP_GATEWAY=1 skips the DoD 5 gateway run (~15 min) for local iteration; the run then fails.
set -uo pipefail
unset TITAN_SESSION_ID
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
VAULT="$(cd "$HERE/../../.." && pwd -P)"
KIT="${KIT_ROOT:-$HOME/AI_Workflow/claude-agent-kit}"
TASK="$VAULT/02_Tasks/TiTan_LLM_OS/Chain_Consolidation_Planner_Context_Pack.md"
# Telemetry: task-attributed rows and timers must not change. The kit suites (test_gateway_*,
# test_resolve_attention*, test_metrics_breakdown) used to append task-null rows to the live telemetry
# through the kit's .vault_link; Kit_Suites_Live_Telemetry_Isolation fixed that (they export TELEMETRY_DIR),
# so the count below should now be 0 apart from other sessions writing concurrently.
snap() {
  { shasum "$TASK" "$VAULT/TiTan_LLM_OS_Board.md" "$VAULT"/.session_state*.json \
      "$KIT"/global/agents/*.md "$KIT/project-template/.claude/commands/execute_task.md" "$KIT/install.sh" 2>/dev/null
    cat "$VAULT"/04_Logs/Telemetry/*.jsonl 2>/dev/null | jq -R -c 'fromjson? | select(.task != null)'
    shasum "$VAULT"/04_Logs/Telemetry/.timers/* 2>/dev/null; } | shasum
}
nulls() { cat "$VAULT"/04_Logs/Telemetry/*.jsonl 2>/dev/null | jq -R -c 'fromjson? | select(.task == null)' | wc -l | tr -d ' '; }
null_before="$(nulls)"
before="$(snap)"
rc=0
for t in "$HERE"/test_*.sh; do
  n="$(basename "$t")"
  if [ "$n" = test_dod5_gateway_green.sh ] && [ "${CHAIN_ACC_SKIP_GATEWAY:-0}" = 1 ]; then echo "SKIP $n"; rc=1; continue; fi
  if bash "$t" >/dev/null 2>"$HERE/.last_err"; then echo "PASS $n"
  else echo "FAIL $n"; cat "$HERE/.last_err"; rc=1; fi
done
rm -f "$HERE/.last_err"
[ "$(snap)" = "$before" ] && echo "PASS real task file / board / session / task telemetry / timers / kit untouched" || { echo "FAIL real vault or kit changed"; rc=1; }
echo "NOTE live telemetry task-null rows added during run: $(( $(nulls) - null_before )) (expected 0 after the isolation fix; nonzero means another session wrote or a kit suite leaks)"
exit $rc

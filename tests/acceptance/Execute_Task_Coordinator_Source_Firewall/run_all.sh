#!/usr/bin/env bash
# Runs every Execute_Task_Coordinator_Source_Firewall acceptance test, then proves the vault HEAD,
# the live attention queue, the interactive panel state, the vault scripts and the kit runbooks
# were not changed (every script call runs in a mktemp sandbox vault).
# ACC_SKIP_GATEWAY=1 skips test_dod7_gateway_skip_mode.sh (it runs the task gateway).
set -uo pipefail
unset TITAN_SESSION_ID TELEMETRY_DIR
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
VAULT="$(cd "$HERE/../../.." && pwd -P)"
KIT="$(cd "${KIT_ROOT:-$HOME/AI_Workflow/claude-agent-kit}" && pwd -P)"
snap() {
  git -C "$VAULT" rev-parse HEAD 2>/dev/null
  [ -e "$VAULT/Needs_Attention.md" ] && cksum < "$VAULT/Needs_Attention.md" || echo no-queue
  [ -e "$VAULT/04_Logs/Orchestrator/.panel_convened.interactive" ] && cksum < "$VAULT/04_Logs/Orchestrator/.panel_convened.interactive" || echo no-panel
  find "$VAULT/.scripts" -type f -exec cksum {} + 2>/dev/null | sort | cksum
  cat "$KIT/project-template/.claude/commands/execute_task.md" "$KIT/project-template/.claude/commands/close_task.md" | cksum
}
before="$(snap)"
ERR="$(mktemp)"
rc=0
for t in "$HERE"/test_*.sh; do
  n="$(basename "$t")"
  if [ "$n" = test_dod7_gateway_skip_mode.sh ] && [ "${ACC_SKIP_GATEWAY:-0}" = 1 ]; then echo "SKIP $n (ACC_SKIP_GATEWAY=1)"; continue; fi
  if bash "$t" >/dev/null 2>"$ERR"; then echo "PASS $n"
  else echo "FAIL $n"; cat "$ERR"; rc=1; fi
done
rm -f "$ERR"
[ "$(snap)" = "$before" ] && echo "PASS vault HEAD / queue / panel state / scripts / kit runbooks untouched" || { echo "FAIL vault or kit state changed"; rc=1; }
exit $rc

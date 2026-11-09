#!/usr/bin/env bash
# Runs every Write_Task_Section_Hook_Argument_Scope acceptance test, then proves the kit hook/agents,
# this task file and the live telemetry log were not written.
# ACC_SKIP_GATEWAY=1 skips test_dod4_gateway_green.sh (full gateway with kit + vault suites); the chain aggregator sets it.
set -uo pipefail
unset TITAN_SESSION_ID TELEMETRY_DIR
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
VAULT="$(cd "$HERE/../../.." && pwd -P)"
KIT="${KIT_ROOT:-$HOME/AI_Workflow/claude-agent-kit}"
snap() {
  { shasum "$KIT/global/hooks/bash_write_task_section_only.sh" "$KIT"/global/agents/*.md "$KIT"/docs/cld/*.md \
      "$VAULT/02_Tasks/TiTan_LLM_OS/Write_Task_Section_Hook_Argument_Scope.md" 2>/dev/null
    cat "$VAULT"/04_Logs/Telemetry/*.jsonl 2>/dev/null | grep -c '"session_id": *"acc"'; } | shasum
}
before="$(snap)"
rc=0
for t in "$HERE"/test_*.sh; do
  n="$(basename "$t")"
  if [ "$n" = test_dod4_gateway_green.sh ] && [ "${ACC_SKIP_GATEWAY:-0}" = 1 ]; then echo "SKIP $n (ACC_SKIP_GATEWAY=1)"; continue; fi
  if bash "$t" >/dev/null 2>"$HERE/.last_err"; then echo "PASS $n"
  else echo "FAIL $n"; cat "$HERE/.last_err"; rc=1; fi
done
rm -f "$HERE/.last_err"
[ "$(snap)" = "$before" ] && echo "PASS kit / task file / live telemetry untouched" || { echo "FAIL real kit, task file or live telemetry changed"; rc=1; }
exit $rc

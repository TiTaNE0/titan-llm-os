#!/usr/bin/env bash
# Runs every Chain_Targeted_Tests_Per_Stage acceptance test, then proves the kit files under test,
# the vault gateways and the installed OpenCode files were not written.
# ACC_SKIP_GATEWAY=1 skips test_dod5_gateway_green.sh (the full gateway with all kit + vault
# suites); the exit code then reflects only the remaining checks. The chain aggregator sets it.
set -uo pipefail
unset TITAN_SESSION_ID
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
VAULT="$(cd "$HERE/../../.." && pwd -P)"
KIT="${KIT_ROOT:-$HOME/AI_Workflow/claude-agent-kit}"
OC_AGENT="${CTT_OC_AGENT_DIR:-$HOME/.config/opencode/agent}"
snap() {
  shasum "$KIT/project-template/.claude/commands/execute_task.md" "$KIT"/global/agents/*.md \
    "$VAULT"/tests/test_*.sh "$VAULT"/tests/acceptance/*/run_all.sh \
    "$OC_AGENT"/*.md "$(dirname "$OC_AGENT")/command/execute_task.md" 2>/dev/null | shasum
}
before="$(snap)"
rc=0
for t in "$HERE"/test_*.sh; do
  n="$(basename "$t")"
  if [ "$n" = test_dod5_gateway_green.sh ] && [ "${ACC_SKIP_GATEWAY:-0}" = 1 ]; then echo "SKIP $n (ACC_SKIP_GATEWAY=1)"; continue; fi
  if bash "$t" >/dev/null 2>"$HERE/.last_err"; then echo "PASS $n"
  else echo "FAIL $n"; cat "$HERE/.last_err"; rc=1; fi
done
rm -f "$HERE/.last_err"
[ "$(snap)" = "$before" ] && echo "PASS kit / gateways / OpenCode files untouched" || { echo "FAIL real kit, vault or OpenCode file changed"; rc=1; }
exit $rc

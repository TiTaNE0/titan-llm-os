#!/usr/bin/env bash
# Runs every PM_Reviewer_Single_Pass_Findings acceptance test, then proves the real task file
# and the kit files under test were not written.
# PMR_ACC_SKIP_GATEWAY=1 skips the full gateway run (all kit + vault suites) for local iteration; the run then fails.
set -uo pipefail
unset TITAN_SESSION_ID
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
VAULT="$(cd "$HERE/../../.." && pwd -P)"
KIT="${KIT_ROOT:-$HOME/AI_Workflow/claude-agent-kit}"
TASK="$VAULT/02_Tasks/TiTan_LLM_OS/PM_Reviewer_Single_Pass_Findings.md"
snap() {
  shasum "$TASK" "$VAULT/tests/test_pm_reviewer_single_pass.sh" "$VAULT/tests/test_chain_consolidation.sh" \
    "$KIT/global/agents/pm-reviewer.md" "$KIT/docs/cld/pm-reviewer.md" \
    "$KIT/project-template/.claude/commands/execute_task.md" 2>/dev/null | shasum
}
before="$(snap)"
rc=0
for t in "$HERE"/test_*.sh; do
  n="$(basename "$t")"
  if [ "$n" = test_dod3_gateway_green.sh ] && [ "${PMR_ACC_SKIP_GATEWAY:-0}" = 1 ]; then echo "SKIP $n"; rc=1; continue; fi
  if bash "$t" >/dev/null 2>"$HERE/.last_err"; then echo "PASS $n"
  else echo "FAIL $n"; cat "$HERE/.last_err"; rc=1; fi
done
rm -f "$HERE/.last_err"
[ "$(snap)" = "$before" ] && echo "PASS real task file / gateway / kit files untouched" || { echo "FAIL real vault or kit changed"; rc=1; }
exit $rc

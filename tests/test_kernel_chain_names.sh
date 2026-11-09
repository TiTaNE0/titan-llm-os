#!/usr/bin/env bash
# Gateway for Kernel_Graduate_Chain_Consolidation: 03_Brain describes the chain the kit runbook runs.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SA="$REPO_ROOT/03_Brain/System_Agents.md"
TR="$REPO_ROOT/03_Brain/Tool_Registry.md"
FAILS=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAILS=$((FAILS + 1)); }
has() { grep -qF -- "$2" "$1" && pass "$3" || fail "$3"; }
lacks() { grep -qF -- "$2" "$1" && fail "$3" || pass "$3"; }

# /execute_task section only (from its heading to the next ### heading).
EXEC="$(mktemp)"; trap 'rm -f "$EXEC"' EXIT
awk '/^### `\/execute_task/{on=1;print;next} on&&/^### /{exit} on' "$SA" > "$EXEC"
[ -s "$EXEC" ] && pass "execute_task section found" || fail "execute_task section found"

has "$EXEC" 'invoke_planner(task_path' "execute_task names invoke_planner"
lacks "$EXEC" 'invoke_spec_writer' "execute_task no longer names invoke_spec_writer"
lacks "$EXEC" 'invoke_researcher' "execute_task no longer names invoke_researcher"
has "$EXEC" 'Build split: backend-frontend' "builder default with backend-frontend split"
has "$EXEC" 'run only targeted tests' "targeted tests per stage"
has "$EXEC" 'Test-verifier and builders never write the vault' "test-verifier does not write the vault"

has "$SA" '<duration_ms|auto> <error_class|null> <persona> [task]' "lifecycle signature has auto and [task]"
has "$SA" 'telemetry_start.sh <macro> [task]' "lifecycle names telemetry_start.sh"
has "$SA" 'up to 3 reviewer rounds' "orchestrator spec gate revision loop"

has "$TR" '`--content-file -`' "Tool_Registry write_task_section documents --content-file -"
has "$TR" 'sec_heading_name' "Tool_Registry grep_section uses the template rule"
has "$TR" '### `invoke_planner`' "Tool_Registry registers invoke_planner"
has "$TR" '### `codemap_refresh`' "Tool_Registry registers codemap_refresh"

# Kit runbook agrees with the kernel default chain.
KIT="${KIT_ROOT:-$HOME/AI_Workflow/claude-agent-kit}"
RB="$KIT/project-template/.claude/commands/execute_task.md"
if [ -f "$RB" ]; then
  has "$RB" 'planner' "kit execute_task.md uses planner"
  has "$RB" 'Build split: backend-frontend' "kit execute_task.md has the build split"
else
  fail "kit execute_task.md present"
fi

[ "$FAILS" -eq 0 ] && { echo "ALL GREEN"; exit 0; } || { echo "$FAILS check(s) failed"; exit 1; }

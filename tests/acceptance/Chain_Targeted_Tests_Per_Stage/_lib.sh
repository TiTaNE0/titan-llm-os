#!/usr/bin/env bash
# Shared setup for Chain_Targeted_Tests_Per_Stage acceptance tests.
# Every write goes to mktemp dirs; the real vault, kit and ~/.config/opencode are only read.
set -uo pipefail
unset TITAN_SESSION_ID

VAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
KIT="$(cd "${KIT_ROOT:-$HOME/AI_Workflow/claude-agent-kit}" && pwd -P)"
EXEC="$KIT/project-template/.claude/commands/execute_task.md"
AG="$KIT/global/agents"
GATEWAY="$VAULT/tests/test_chain_targeted_tests.sh"
OC_AGENT="${CTT_OC_AGENT_DIR:-$HOME/.config/opencode/agent}"
OC_CMD="$(dirname "$OC_AGENT")/command"

# The verbatim sentences the spec fixes (the planner's contract with the builders).
S_BUILDER='Run only targeted tests: the tests for the files you changed plus the task'"'"'s Verification Gateway command in its skip mode (the skip env its header comment names; green means no `FAIL:` line; if it names none, do not run it). Do not run the full kit or vault suite loops; the Verification Gateway step runs them once.'
S_TV='Run only targeted tests: your acceptance tests, the tests for the files the builders changed, and the task'"'"'s Verification Gateway command in its skip mode (the skip env its header comment names; green means no `FAIL:` line; if it names none, do not run it). Do not run the full kit or vault suite loops; the Verification Gateway step runs them once.'
S_NESTED='No nested full-gateway run in an acceptance folder: a test that runs a gateway without its skip env, or any full kit or vault suite loop, is allowed only behind the shared `ACC_SKIP_GATEWAY=1` skip env, which the aggregator sets for every acceptance folder; run your folder with `ACC_SKIP_GATEWAY=1` set.'
S_VAL='Run only targeted tests: the tests for the files the builders changed plus the task'"'"'s Verification Gateway command in its skip mode (the skip env its header comment names; green means no `FAIL:` line; if it names none, do not run it). Do not run the full kit or vault suite loops; the Verification Gateway step runs them once.'
S_STEP13='Step 13 is the single full-suite run per task: the gateway command runs here without any skip env, and Steps 10-12 run only targeted tests.'
S_REMIND='- Steps 10-12 run only targeted tests (changed files plus the gateway in its skip mode); Step 13 is the single full-suite run per task.'
A_BUILDER='Under `/execute_task` (the briefing says so), run only targeted tests: the tests for the files you changed plus the task'"'"'s Verification Gateway command in its skip mode; do not run the full kit or vault suite loops, the gateway step runs them once.'
A_TV7='7. Under `/execute_task`, run only targeted tests: your acceptance tests, the tests for the files the builders changed, and the task'"'"'s Verification Gateway command in its skip mode; do not run the full kit or vault suite loops, the gateway step runs them once.'
A_TVNEST='- Under `/execute_task`, do not add a nested full-gateway run to an acceptance folder. A test that runs a gateway without its skip env, or any full kit or vault suite loop, is allowed only behind the shared `ACC_SKIP_GATEWAY=1` skip env, which the aggregator sets for every acceptance folder; run your folder with `ACC_SKIP_GATEWAY=1` set.'

# Physical path: darwin mktemp gives /var/..., which resolves to /private/var/...
TMP="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

FAILED=0
fail() { echo "FAIL: $1" >&2; FAILED=1; }
pass() { echo "ok: $1"; }
finish() { [ "$FAILED" -eq 0 ] && { echo "PASS"; exit 0; }; echo "FAILED" >&2; exit 1; }
expect() { [ "$3" = "$2" ] && pass "$1" || fail "$1: expected [$2], got [$3]"; }
has() { printf '%s\n' "$2" | grep -qF -- "$3" && pass "$1" || fail "$1 (missing: ${3:0:80})"; }
hasnt() { printf '%s\n' "$2" | grep -qF -- "$3" && fail "$1 (present: ${3:0:80})" || pass "$1"; }

# step <file> <n> <next>: body of "## Step n " up to "## Step next ".
step() { awk -v a="## Step $2 " -v b="## Step $3 " 'index($0,a)==1{on=1} index($0,b)==1{on=0} on' "$1"; }
# brief_line <text> <needle>: the single line holding needle.
line_with() { printf '%s\n' "$1" | grep -F -- "$2"; }

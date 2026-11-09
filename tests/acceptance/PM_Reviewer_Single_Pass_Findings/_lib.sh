#!/usr/bin/env bash
# Shared setup for PM_Reviewer_Single_Pass_Findings acceptance tests.
# Every write goes to mktemp dirs; the real vault and kit are only read.
set -uo pipefail
unset TITAN_SESSION_ID

VAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
KIT="${KIT_ROOT:-$HOME/AI_Workflow/claude-agent-kit}"
EXEC_MD="$KIT/project-template/.claude/commands/execute_task.md"
PMR="$KIT/global/agents/pm-reviewer.md"
PMR_DOC="$KIT/docs/cld/pm-reviewer.md"
GATEWAY="$VAULT/tests/test_pm_reviewer_single_pass.sh"
CLASSES='DoD fails on correct work
DoD passes without delivery
misreported result
internal contradiction
scope creep
03_Brain edit'

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

FAILED=0
fail() { echo "FAIL: $1" >&2; FAILED=1; }
pass() { echo "ok: $1"; }
finish() { [ "$FAILED" -eq 0 ] && { echo "PASS"; exit 0; }; echo "FAILED" >&2; exit 1; }
# expect <label> <expected> <actual>
expect() { [ "$3" = "$2" ] && pass "$1" || fail "$1: expected [$2], got [$3]"; }
# has <label> <haystack> <fixed-string>
has() { printf '%s\n' "$2" | grep -qF -- "$3" && pass "$1" || fail "$1 (missing: $3)"; }
lacks() { printf '%s\n' "$2" | grep -qF -- "$3" && fail "$1 (present: $3)" || pass "$1"; }

# step_body <N> [file]: lines from "## Step <N> —" up to the next "## " heading.
step_body() {
  awk -v h="## Step $1 —" 'index($0, h) == 1 { on = 1; print; next } on && /^## / { exit } on { print }' "${2:-$EXEC_MD}"
}
# block_body <heading> [file]: lines under an exact "## <heading>" up to the next "## " heading.
block_body() {
  awk -v h="## $1" '$0 == h { on = 1; next } on && /^## / { exit } on { print }' "${2:-$EXEC_MD}"
}
# md_section <file> <heading-prefix>: lines under "## <prefix>..." up to the next "## ".
md_section() {
  awk -v h="## $2" 'index($0, h) == 1 { on = 1; next } on && /^## / { exit } on { print }' "$1"
}

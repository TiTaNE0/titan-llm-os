#!/usr/bin/env bash
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 LC_ALL=C
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
VAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
K="${KIT_ROOT:-/Users/titane0/AI_Workflow/claude-agent-kit}"
CMD="$K/project-template/.claude/commands"
CLOSE="$CMD/close_task.md"; TICK="$CMD/orchestrator_tick.md"; EXEC="$CMD/execute_task.md"
TMP="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT
FAILED=0
fail() { echo "FAIL: $1" >&2; FAILED=1; }
pass() { echo "ok: $1"; }
eq() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (expected [$3] got [$2])"; fi; }
has() { if printf '%s' "$2" | grep -Fq -- "$3"; then pass "$1"; else fail "$1 (missing [$3])"; fi; }
hasnt() { if printf '%s' "$2" | grep -Fq -- "$3"; then fail "$1 (unexpected [$3])"; else pass "$1"; fi; }
finish() { [ "$FAILED" -eq 0 ] && { echo PASS; exit 0; }; echo FAILED >&2; exit 1; }
# slice FILE START_REGEX END_REGEX : lines from first START match up to (excl.) next END match
slice() { awk -v s="$2" -v e="$3" '$0~s&&!f{f=1;print;next} f&&$0~e{exit} f' "$1"; }
# fenced_lines FILE : only lines inside ``` fences
fenced() { awk '/^[[:space:]]*```/{f=!f;next} f' "$1"; }
fenced_lineno() { awk -v pat="$2" '/^[[:space:]]*```/{f=!f;next} f&&index($0,pat){print NR;exit}' "$1"; }

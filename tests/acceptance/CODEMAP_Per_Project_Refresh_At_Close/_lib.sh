# Shared helpers for CODEMAP_Per_Project_Refresh_At_Close acceptance tests. Sourced, not run.
set -uo pipefail
unset TITAN_SESSION_ID TELEMETRY_DIR
VAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
KIT="$(cd "${KIT_ROOT:-$HOME/AI_Workflow/claude-agent-kit}" && pwd -P)"
CT="$KIT/project-template/.claude/commands/close_task.md"
PL="$KIT/global/agents/planner.md"
TMP="$(cd "$(mktemp -d)" && pwd -P)"; trap 'rm -rf "$TMP"' EXIT
FAILS=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1" >&2; FAILS=$((FAILS + 1)); }
eq() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (got '$2', want '$3')"; fi; }
done_() { [ "$FAILS" -eq 0 ] && exit 0; echo "$FAILS failed" >&2; exit 1; }

# A kit-style project: mktemp git repo whose .vault_link points at the real vault (read-only use).
project() { # name -> path
  local d="$TMP/$1"; mkdir -p "$d"; git -C "$d" init -q
  git -C "$d" config user.name t; git -C "$d" config user.email t@t; git -C "$d" config commit.gpgsign false
  ln -s "$VAULT" "$d/.vault_link"; echo .vault_link >> "$d/.git/info/exclude"
  echo "$d"
}
commit() { git -C "$1" add -A -- . ':!CODEMAP.md' && git -C "$1" commit -qm "$2"; }
# The exact Step 4.6 command line from the kit runbook.
step46_cmd() { awk '/^## Step 4\.6/{f=1} /^## Step 5/{f=0} f' "$CT" | grep -F 'codemap_refresh.sh --sha' | head -n 1; }
# Run Step 4.6 as /close_task would, in project dir $1 with COMMIT_SHA=$2. Sets OUT, RC.
close_step46() { OUT="$(cd "$1" && COMMIT_SHA="$2" bash -c "$(step46_cmd)" 2>&1)"; RC=$?; }

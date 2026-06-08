#!/usr/bin/env bash
# in_progress_lock.sh
#
# Per-project In-Progress task lock check. Scans .vault_link/02_Tasks/<project>/*.md
# for YAML `status: in_progress` lines, excluding the current task being started.
# Enforces the macro spec invariant: at most one in-progress task per project.
#
# Contract: Tool_Registry.md § Subagent Engine Atoms § in_progress_lock
# Idempotent: Yes (read-only). Persona Gate: any. Telemetry: none.
#
# Exit codes:
#   0  - no other in-progress task in this project
#   3  - another in-progress task found (E3); offending basename printed to stdout

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $(basename "$0") <project_name> <current_task_basename>" >&2
  echo "E3: expected exactly 2 args" >&2
  exit 3
fi

PROJECT="$1"
CURRENT_TASK="$2"

# Resolve vault location (script lives in .vault_link/.scripts/).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
VAULT_DIR="$(dirname "$SCRIPT_DIR")"
TASKS_DIR="$VAULT_DIR/02_Tasks/$PROJECT"

if [[ ! -d "$TASKS_DIR" ]]; then
  echo "E3: tasks directory not found: $TASKS_DIR" >&2
  exit 3
fi

# Scan each task .md in the project's tasks folder.
# Only inspect YAML frontmatter (between the first two `---` markers) -
# the task body may legitimately mention `status: in_progress` in prose,
# which must NOT trip the lock.
for f in "$TASKS_DIR"/*.md; do
  [[ -e "$f" ]] || continue   # handles empty dir (glob expands to literal pattern)
  basename="$(basename "$f" .md)"
  if [[ "$basename" == "$CURRENT_TASK" ]]; then
    continue   # exclude self (allow resume of own in-progress task)
  fi
  # Inspect YAML frontmatter only (between the first two `---`).
  fm="$(awk '/^---$/{c++; if(c==2) exit} c==1' "$f")"
  if printf '%s\n' "$fm" | grep -qE '^status:[[:space:]]*in_progress[[:space:]]*$'; then
    # Epics are exempt: an umbrella epic legitimately stays in_progress across
    # many child tasks, so it must not trip the per-project lock.
    if printf '%s\n' "$fm" | grep -qE '^type:[[:space:]]*epic[[:space:]]*$'; then
      continue
    fi
    echo "$basename"
    exit 3
  fi
done

# Read-only tool, no telemetry per Composition Rule 4.
exit 0

#!/usr/bin/env bash
# fetch_next_task.sh
#
# Orchestrator Fetch primitive (PRD §4.1). Returns the next ELIGIBLE task from a
# project's board Todo column, in priority order. The board IS the backlog — no
# separate queue file. Read-only.
#
# Eligible = appears in the `## Todo` column AND its task .md has YAML
#   status: todo  (not blocked/in_progress/done)  AND
#   type:  != epic  (epics are umbrellas, not executable units)
# Ordering: priority high > medium > low; ties broken by board order (top first).
#
# "Unblocked" MVP definition: status == todo. Inter-task dependency blocking is not
# modeled in YAML yet; a task parked for a dependency should carry status: blocked.
#
# Contract: Tool_Registry.md § fetch_next_task (registration deferred to Phase C /graduate).
# Idempotent: ✅ (read-only).
# Persona Gate: any (read-only; the dispatching tick already runs as Orchestrator).
# Telemetry: none (read-only per Composition Rule 4).
#
# Output: the chosen task basename (no extension) on stdout, exit 0.
# Exit codes:
#   0  a task was selected (printed)
#   1  no eligible task (STOP signal for the loop)
#   2  invalid args / board missing (E-class)

set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") --project <name> [--board <path>] [--tasks-dir <path>]

Required:
  --project <name>     Project key (resolves board + tasks dir under the vault)

Optional (test overrides; bypass vault resolution):
  --board <path>       Board .md (default: <vault>/<project>_Board.md)
  --tasks-dir <path>   Task dir (default: <vault>/02_Tasks/<project>)

Exit codes:
  0  task selected (basename on stdout)
  1  no eligible task
  2  invalid args / board missing
EOF
}

PROJECT=""
BOARD=""
TASKS_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)    PROJECT="$2"; shift 2 ;;
    --board)      BOARD="$2"; shift 2 ;;
    --tasks-dir)  TASKS_DIR="$2"; shift 2 ;;
    -h|--help)    usage; exit 0 ;;
    *)            echo "E2: unknown arg: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ -z "$PROJECT" ]]; then
  echo "E2: --project is required" >&2; usage >&2; exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
VAULT_DIR="$(dirname "$SCRIPT_DIR")"
BOARD="${BOARD:-$VAULT_DIR/${PROJECT}_Board.md}"
TASKS_DIR="${TASKS_DIR:-$VAULT_DIR/02_Tasks/$PROJECT}"

if [[ ! -f "$BOARD" ]]; then
  echo "E2: board not found: $BOARD" >&2; exit 2
fi

# Read one YAML field from a task file's frontmatter (first --- .. --- block).
yaml_field() {
  local file="$1" key="$2"
  awk -v k="$key" '
    /^---$/ { c++; if (c == 2) exit; next }
    c == 1 && $0 ~ "^" k ":" {
      sub("^" k ":[[:space:]]*", ""); sub(/[[:space:]]*$/, ""); print; exit
    }
  ' "$file"
}

priority_rank() {
  case "$1" in
    critical) echo 0 ;;
    high)     echo 1 ;;
    medium)   echo 2 ;;
    low)      echo 3 ;;
    *)        echo 4 ;;
  esac
}

# Extract task links from the ## Todo column (until the next ## header), in order.
best_name=""
best_rank=99
order=0

while IFS= read -r name; do
  [[ -z "$name" ]] && continue
  order=$((order + 1))
  tf="$TASKS_DIR/$name.md"
  [[ -f "$tf" ]] || continue
  status="$(yaml_field "$tf" status)"
  type="$(yaml_field "$tf" type)"
  [[ "$status" == "todo" ]] || continue
  [[ "$type" == "epic" ]] && continue
  rank=$(priority_rank "$(yaml_field "$tf" priority)")
  # Strictly-less keeps the first (top-of-board) task on a priority tie.
  if [[ "$rank" -lt "$best_rank" ]]; then
    best_rank=$rank
    best_name="$name"
  fi
done < <(awk '
  /^## Todo[[:space:]]*$/ { inblock=1; next }
  /^## / { inblock=0 }
  inblock {
    while (match($0, /\[\[[^]]+\]\]/)) {
      link = substr($0, RSTART+2, RLENGTH-4)
      sub(/\|.*$/, "", link)   # strip display-text alias if present
      print link
      $0 = substr($0, RSTART + RLENGTH)
    }
  }
' "$BOARD")

if [[ -z "$best_name" ]]; then
  exit 1
fi

echo "$best_name"
exit 0

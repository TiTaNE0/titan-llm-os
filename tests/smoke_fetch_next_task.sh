#!/usr/bin/env bash
# smoke_fetch_next_task.sh
#
# Verification brick for Orchestrator_C1 — the Fetch primitive (PRD §4.1).
# Proves: priority ordering, epic skip, blocked skip, board-order tiebreak,
# exhaustion → exit 1. Runs against a temp fixture; touches no real vault state.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
FETCH="$REPO_ROOT/.scripts/fetch_next_task.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
TASKS="$TMP/tasks"; mkdir -p "$TASKS"
BOARD="$TMP/P_Board.md"
fail() { echo "FAIL: $1" >&2; exit 1; }

mk() { # name status type priority
  printf -- '---\nproject: [[P]]\nstatus: %s\ntype: %s\npriority: %s\n---\n# %s\n' \
    "$2" "$3" "$4" "$1" > "$TASKS/$1.md"
}

cat > "$BOARD" <<'EOF'
---
kanban-plugin: board
---

## Todo
- [ ] [[Epic_X]]
- [ ] [[Low_First]]
- [ ] [[High_Mid]]
- [ ] [[Blocked_High]]
- [ ] [[High_Late]]

## In Progress

## Done
- [ ] [[Done_High]]
EOF

mk Epic_X      todo  epic  high
mk Low_First   todo  task  low
mk High_Mid    todo  task  high
mk Blocked_High blocked task high
mk High_Late   todo  task  high
mk Done_High   done  task  high

run() { "$FETCH" --project P --board "$BOARD" --tasks-dir "$TASKS"; }

# 1. Highest priority wins, epic + blocked skipped, board-order breaks the High tie.
got="$(run)" || fail "fetch errored with eligible tasks present"
[[ "$got" == "High_Mid" ]] || fail "expected High_Mid, got '$got'"

# 2. Complete High_Mid -> next eligible is High_Late (still > Low_First by priority).
mk High_Mid done task high
got="$(run)" || fail "fetch errored after completing High_Mid"
[[ "$got" == "High_Late" ]] || fail "expected High_Late, got '$got'"

# 3. Complete High_Late -> only Low_First remains eligible.
mk High_Late done task high
got="$(run)" || fail "fetch errored with Low_First remaining"
[[ "$got" == "Low_First" ]] || fail "expected Low_First, got '$got'"

# 4. Exhaust -> exit 1 (STOP signal), no output.
mk Low_First done task low
rc=0; out="$(run)" || rc=$?
[[ "$rc" -eq 1 ]] || fail "exhausted board should exit 1, got $rc"
[[ -z "$out" ]] || fail "exit 1 should print nothing, got '$out'"

# 5. Done column never selected even though Done_High is high priority.
#    (Already implied above; assert explicitly with a Todo-empty board.)
cat > "$BOARD" <<'EOF'
## Todo

## Done
- [ ] [[Done_High]]
EOF
rc=0; run >/dev/null || rc=$?
[[ "$rc" -eq 1 ]] || fail "empty Todo should exit 1, got $rc"

echo "SMOKE: OK"

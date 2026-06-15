#!/usr/bin/env bash
# smoke_panel_guard.sh — once-per-task-per-run enforcement (C3, PRD §4.3). Temp-isolated.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
PG="$REPO_ROOT/.scripts/panel_guard.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
SF="$TMP/state"
fail() { echo "FAIL: $1" >&2; exit 1; }

# First convene for a task -> may-convene (0).
"$PG" --task Alpha --run-id r1 --state-file "$SF" >/dev/null || fail "first convene should exit 0"
# Second convene, same task+run -> already-convened (3).
rc=0; "$PG" --task Alpha --run-id r1 --state-file "$SF" 2>/dev/null || rc=$?
[[ "$rc" -eq 3 ]] || fail "re-panel same task should exit 3, got $rc"
# Different task, same run -> allowed (0).
"$PG" --task Beta --run-id r1 --state-file "$SF" >/dev/null || fail "different task should exit 0"
# Same task, DIFFERENT run -> allowed (fresh run, fresh state file).
"$PG" --task Alpha --run-id r2 --state-file "$TMP/state2" >/dev/null || fail "new run should exit 0"
# Bad args -> E2.
rc=0; "$PG" --task Alpha 2>/dev/null || rc=$?
[[ "$rc" -eq 2 ]] || fail "missing --run-id should exit 2, got $rc"

echo "SMOKE: OK"

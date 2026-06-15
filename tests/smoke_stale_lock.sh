#!/usr/bin/env bash
# smoke_stale_lock.sh
#
# Verification for Orchestrator_C4 — task_owner.sh (stamp/get) + stale_lock_scan.sh
# (orphan detection, PRD §6). Runs against a temp vault with copied scripts and an
# Executioner session state; touches no real vault state.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRIPTS="$REPO_ROOT/.scripts"

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/.scripts" "$TMP/02_Tasks/P" "$TMP/04_Logs/Telemetry"
cp "$SCRIPTS/task_owner.sh" "$SCRIPTS/stale_lock_scan.sh" "$SCRIPTS/persona_check.sh" "$SCRIPTS/emit_telemetry.sh" "$TMP/.scripts/"
printf '{\n  "persona": "Executioner",\n  "session_id": "smoke",\n  "started_at": "2026-06-15T00:00:00Z",\n  "agent_surface": "test"\n}\n' > "$TMP/.session_state.json"
S="$TMP/.scripts"; TD="$TMP/02_Tasks/P"
fail() { echo "FAIL: $1" >&2; exit 1; }

mk() { # name status type [run_id]
  { printf -- '---\nproject: [[P]]\nstatus: %s\ntype: %s\npriority: high\n' "$2" "$3"
    [[ -n "${4:-}" ]] && printf -- 'orchestrator_run_id: %s\n' "$4"
    printf -- '---\n# %s\n' "$1"; } > "$TD/$1.md"
}

# --- task_owner: get on unstamped -> empty ---------------------------------
mk Fresh in_progress task
[[ -z "$("$S/task_owner.sh" --task-path "$TD/Fresh.md" --get)" ]] || fail "unstamped get should be empty"

# --- task_owner: set then get -> value -------------------------------------
"$S/task_owner.sh" --task-path "$TD/Fresh.md" --run-id run-LIVE --source-persona Executioner >/dev/null || fail "stamp failed"
[[ "$("$S/task_owner.sh" --task-path "$TD/Fresh.md" --get)" == "run-LIVE" ]] || fail "get after stamp wrong"
# set again -> replaces (no duplicate field)
"$S/task_owner.sh" --task-path "$TD/Fresh.md" --run-id run-LIVE2 --source-persona Executioner >/dev/null || fail "restamp failed"
[[ "$("$S/task_owner.sh" --task-path "$TD/Fresh.md" --get)" == "run-LIVE2" ]] || fail "restamp not applied"
[[ "$(grep -c '^orchestrator_run_id:' "$TD/Fresh.md")" -eq 1 ]] || fail "duplicate run_id field"
# wrong persona -> E4
rc=0; "$S/task_owner.sh" --task-path "$TD/Fresh.md" --run-id x --source-persona Architect 2>/dev/null || rc=$?
[[ "$rc" -eq 4 ]] || fail "wrong persona should exit 4, got $rc"

# --- stale_lock_scan: orphan detection -------------------------------------
mk Live      in_progress task run-LIVE       # owned by live run -> resumable, NOT orphan
mk Orphan    in_progress task run-OLD-DEAD   # foreign/dead run id -> ORPHAN
mk Unstamped in_progress task                # human-started, no stamp -> NOT orphan
mk Todo      todo        task run-OLD-DEAD   # not in_progress -> skip
mk EpicOld   in_progress epic run-OLD-DEAD   # epic exempt -> skip
"$S/task_owner.sh" --task-path "$TD/Fresh.md" --run-id run-LIVE --source-persona Executioner >/dev/null  # back to live

orphans="$("$S/stale_lock_scan.sh" --project P --live-run-id run-LIVE --tasks-dir "$TD" | sort | tr '\n' ' ')"
[[ "$orphans" == "Orphan " ]] || fail "expected only 'Orphan', got '$orphans'"

# bad args -> E2
rc=0; "$S/stale_lock_scan.sh" --project P 2>/dev/null || rc=$?
[[ "$rc" -eq 2 ]] || fail "missing --live-run-id should exit 2, got $rc"

echo "SMOKE: OK"

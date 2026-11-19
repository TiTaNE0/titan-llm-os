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
unset TITAN_SESSION_ID
export TELEMETRY_DIR="$TMP/telemetry"
mkdir -p "$TMP/.scripts" "$TMP/02_Tasks/P" "$TMP/04_Logs/Telemetry"
cp "$SCRIPTS/task_owner.sh" "$SCRIPTS/stale_lock_scan.sh" "$SCRIPTS/persona_check.sh" "$SCRIPTS/emit_telemetry.sh" \
   "$SCRIPTS/in_progress_lock.sh" "$SCRIPTS/queue_attention.sh" "$SCRIPTS/resolve_attention.sh" "$SCRIPTS/panel_guard.sh" "$TMP/.scripts/"
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

# --- in_progress_lock: dead-run holder still blocks -------------------------
LD="$TMP/02_Tasks/L"; mkdir -p "$LD"
mkl() { # name status type [run_id] -- like mk, but into $TD
  TD="$1" mk "${@:2}"
}
mkl "$LD" Holder in_progress task run-DEAD
mkl "$LD" Other  todo        task
rc=0; out="$("$S/in_progress_lock.sh" L Other)" || rc=$?
[[ "$rc" -eq 3 && "$out" == "Holder" ]] || fail "L1: dead-run holder should block (rc=$rc out=$out)"
rc=0; "$S/in_progress_lock.sh" L Holder >/dev/null || rc=$?
[[ "$rc" -eq 0 ]] || fail "L2: self should be excluded, got $rc"
LE="$TMP/02_Tasks/LE"; mkdir -p "$LE"
mkl "$LE" Epic in_progress epic run-DEAD
rc=0; "$S/in_progress_lock.sh" LE Other >/dev/null || rc=$?
[[ "$rc" -eq 0 ]] || fail "L3: in_progress epic must not lock, got $rc"
LB="$TMP/02_Tasks/LB"; mkdir -p "$LB"
printf -- '---\nstatus: todo\ntype: task\n---\nnote: status: in_progress\nstatus: in_progress\n' > "$LB/Body.md"
rc=0; "$S/in_progress_lock.sh" LB Other >/dev/null || rc=$?
[[ "$rc" -eq 0 ]] || fail "L4: body-only status must not lock, got $rc"

# --- stale_lock_scan --route -------------------------------------------------
Q="$TMP/Needs_Attention.md"
TAB=$'\t'
route() { "$S/stale_lock_scan.sh" --project "$1" --live-run-id "${2:-run-B}" --route; }
newproj() { RD="$TMP/02_Tasks/$1"; rm -rf "$RD"; mkdir -p "$RD"; rm -f "$Q"; }
qa() { "$S/queue_attention.sh" --task "[[$1]]" --state "$2" --source orchestrator --run-id "$3" --reason "t" --source-persona Executioner >/dev/null; }
printf '# Needs Attention\n\n## Open\n' > "$TMP/seed"
seedq() { cp "$TMP/seed" "$Q"; }

newproj R1; mkl "$RD" Todo todo task
[[ "$(route R1)" == "free" ]] || fail "R1: expected free"

newproj R2; mkl "$RD" H in_progress task
[[ "$(route R2)" == "human${TAB}H" ]] || fail "R2: expected human, got '$(route R2)'"

newproj R3; mkl "$RD" H in_progress task run-A; qa H close_gate run-A
[[ "$(route R3)" == "escalated${TAB}H${TAB}close_gate" ]] || fail "R3: got '$(route R3)'"

newproj R4; mkl "$RD" H in_progress task run-OLD; qa H orphaned_lock run-OLD
[[ "$(route R4)" == "resume${TAB}H${TAB}run-OLD" ]] || fail "R4: got '$(route R4)'"

newproj R5; mkl "$RD" H in_progress task run-A; qa H close_gate run-A
"$S/resolve_attention.sh" --task H --state close_gate --run-id run-A --resolution fixed_code --source-persona Executioner >/dev/null
[[ "$(route R5)" == "resume${TAB}H${TAB}run-A" ]] || fail "R5: got '$(route R5)'"

newproj R6; mkl "$RD" H in_progress task run-B
[[ "$(route R6)" == "resume${TAB}H${TAB}run-B" ]] || fail "R6: got '$(route R6)'"

newproj R7; mkl "$RD" H in_progress task run-A
printf '# Needs Attention\n- [ ] [[H]] | state: close_gate | run_id: run-A | example\n\n## Open\n' > "$Q"
[[ "$(route R7)" == "resume${TAB}H${TAB}run-A" ]] || fail "R7: entry above ## Open must be ignored, got '$(route R7)'"

newproj R8; mkl "$RD" H in_progress task run-A; seedq
qa H2 close_gate run-A; qa H_x close_gate run-A
[[ "$(route R8)" == "resume${TAB}H${TAB}run-A" ]] || fail "R8: got '$(route R8)'"

newproj R9; mkl "$RD" H in_progress task run-A
[[ ! -e "$Q" && "$(route R9)" == "resume${TAB}H${TAB}run-A" ]] || fail "R9: missing queue file"

newproj R10; mkl "$RD" "Has Space" in_progress task run-A
[[ "$(route R10 | cut -f2)" == "Has Space" && "$(route R10 | cut -f3)" == "run-A" ]] || fail "R10: spaces round-trip"

rc=0; "$S/stale_lock_scan.sh" --project R1 --route 2>/dev/null || rc=$?
[[ "$rc" -eq 2 ]] || fail "R11: --route without --live-run-id should exit 2, got $rc"

# --- cross-run lifecycle -----------------------------------------------------
newproj X; XD="$RD"
mkl "$XD" H in_progress task; mkl "$XD" T todo task
"$S/task_owner.sh" --task-path "$XD/H.md" --run-id run-A --source-persona Executioner >/dev/null
rc=0; "$S/in_progress_lock.sh" X T >/dev/null || rc=$?
[[ "$rc" -eq 3 ]] || fail "X1: lock for T should be 3, got $rc"
qa H close_gate run-A
[[ "$(route X run-B)" == "escalated${TAB}H${TAB}close_gate" ]] || fail "X2: got '$(route X run-B)'"
"$S/resolve_attention.sh" --task H --state close_gate --run-id run-A --resolution fixed_code --source-persona Executioner >/dev/null
[[ "$(route X run-B)" == "resume${TAB}H${TAB}run-A" ]] || fail "X3: got '$(route X run-B)'"
DF="$TMP/04_Logs/Orchestrator/.dispatched.run-B"
rc=0; "$S/panel_guard.sh" --task H --run-id run-B --state-file "$DF" >/dev/null || rc=$?
[[ "$rc" -eq 0 ]] || fail "X4: first dispatch guard should be 0, got $rc"
"$S/task_owner.sh" --task-path "$XD/H.md" --run-id run-B --source-persona Executioner >/dev/null
[[ "$("$S/task_owner.sh" --task-path "$XD/H.md" --get)" == "run-B" ]] || fail "X4: re-stamp to run-B"
[[ "$(route X run-B)" == "resume${TAB}H${TAB}run-B" ]] || fail "X5: got '$(route X run-B)'"
rc=0; "$S/panel_guard.sh" --task H --run-id run-B --state-file "$DF" >/dev/null 2>&1 || rc=$?
[[ "$rc" -eq 3 ]] || fail "X5: second dispatch guard should be 3, got $rc"
qa H no_progress run-B
[[ "$(route X run-B)" == "escalated${TAB}H${TAB}no_progress" ]] || fail "X6: got '$(route X run-B)'"
rc=0; "$S/panel_guard.sh" --task H --run-id run-C --state-file "$TMP/04_Logs/Orchestrator/.dispatched.run-C" >/dev/null || rc=$?
[[ "$rc" -eq 0 ]] || fail "X7: new run guard should be 0, got $rc"
[[ "$("$S/stale_lock_scan.sh" --project X --live-run-id run-C)" == "H" ]] || fail "X8: plain scan should list H"

# --- review fixes: anchored escalation match, multi-holder precedence ---------
newproj R12; mkl "$RD" H in_progress task run-A; seedq
qa Other close_gate run-A
printf -- '- [ ] [[Other]] | state: spec_gate | source: orchestrator | run_id: run-A | queued: x | reason: blocked by [[H]] | state: close_gate \n' >> "$Q"
[[ "$(route R12)" == "resume${TAB}H${TAB}run-A" ]] || fail "R12: reason mentioning [[H]] must not escalate H, got '$(route R12)'"

newproj R13; mkl "$RD" H in_progress task run-A; seedq
"$S/queue_attention.sh" --task "[[H]]" --state orphaned_lock --source orchestrator --run-id run-A --reason "was | state: close_gate | x" --source-persona Executioner >/dev/null
[[ "$(route R13)" == "resume${TAB}H${TAB}run-A" ]] || fail "R13: spoofed state in reason, got '$(route R13)'"

newproj R14; mkl "$RD" A in_progress task run-A; mkl "$RD" B in_progress task
[[ "$(route R14)" == "human${TAB}B" ]] || fail "R14: any unstamped holder -> human, got '$(route R14)'"

newproj R15; mkl "$RD" 'Back\slash' in_progress task run-A; seedq; qa 'Back\slash' close_gate run-A
[[ "$(route R15)" == "escalated${TAB}Back\\slash${TAB}close_gate" ]] || fail "R15: backslash name, got '$(route R15)'"

newproj R16; mkl "$RD" A in_progress task run-A; mkl "$RD" B in_progress task run-A; seedq; qa B close_gate run-A
[[ "$(route R16)" == "escalated${TAB}B${TAB}close_gate" ]] || fail "R16: second holder escalated, got '$(route R16)'"

echo "SMOKE: OK"

#!/usr/bin/env bash
# smoke_session_isolation.sh
#
# Verification Gateway for Orchestrator_A2_Session_State_Isolation.
# Proves per-session state files are race-free: two concurrent sessions write
# distinct files; each session's persona_check resolves its OWN file; a cross-check
# fails E4; missing-file and malformed-JSON paths fail E4; the legacy singleton
# fallback still serves single-session callers; aggregate visibility works; and
# stale cleanup removes the right file.
#
# Runs against TEMP COPIES of the real scripts in an isolated temp vault — never
# clobbers the live .session_state*.json.
#
# Exit 0 = all assertions pass.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRIPTS="$REPO_ROOT/.scripts"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/.scripts" "$TMP/04_Logs/Telemetry"
cp "$SCRIPTS/session_state_write.sh" \
   "$SCRIPTS/persona_check.sh" \
   "$SCRIPTS/session_state_cleanup.sh" \
   "$SCRIPTS/emit_telemetry.sh" \
   "$TMP/.scripts/"
S="$TMP/.scripts"

fail() { echo "FAIL: $1" >&2; exit 1; }

# --- 1. Two concurrent sessions, distinct ids + personas -------------------
"$S/session_state_write.sh" --persona Executioner --session-id sess-A --started-at 2026-06-14T00:00:00Z >/dev/null
"$S/session_state_write.sh" --persona Architect   --session-id sess-B --started-at 2026-06-14T00:00:01Z >/dev/null

test -f "$TMP/.session_state.sess-A.json" || fail "keyed file for sess-A not written"
test -f "$TMP/.session_state.sess-B.json" || fail "keyed file for sess-B not written"

# --- 2. Each session resolves its OWN file via TITAN_SESSION_ID -------------
TITAN_SESSION_ID=sess-A "$S/persona_check.sh" Executioner || fail "sess-A should resolve Executioner"
TITAN_SESSION_ID=sess-B "$S/persona_check.sh" Architect   || fail "sess-B should resolve Architect"

# --- 3. Cross-check: sess-A checked against sess-B's persona must fail E4 ----
if TITAN_SESSION_ID=sess-A "$S/persona_check.sh" Architect; then
  fail "cross-session check passed but must fail (E4)"
fi
rc=0; TITAN_SESSION_ID=sess-A "$S/persona_check.sh" Architect || rc=$?
[[ "$rc" -eq 4 ]] || fail "cross-session mismatch should exit 4, got $rc"

# Prove no clobber: each keyed file still holds its own persona.
[[ "$(jq -r .persona "$TMP/.session_state.sess-A.json")" == "Executioner" ]] || fail "sess-A clobbered"
[[ "$(jq -r .persona "$TMP/.session_state.sess-B.json")" == "Architect" ]]   || fail "sess-B clobbered"

# --- 4. Error paths ---------------------------------------------------------
# Missing file.
rc=0; TITAN_SESSION_ID=sess-NONE "$S/persona_check.sh" Executioner 2>/dev/null || rc=$?
[[ "$rc" -eq 4 ]] || fail "missing state file should exit 4, got $rc"
# Malformed JSON.
echo "{ not valid json" > "$TMP/.session_state.sess-C.json"
rc=0; TITAN_SESSION_ID=sess-C "$S/persona_check.sh" Executioner 2>/dev/null || rc=$?
[[ "$rc" -eq 4 ]] || fail "malformed JSON should exit 4, got $rc"

# --- 5. Backward compat: legacy singleton fallback (no env var) -------------
# session_state_write wrote the singleton mirror; last writer was sess-B (Architect).
[[ "$(jq -r .persona "$TMP/.session_state.json")" == "Architect" ]] || fail "singleton mirror not written"
"$S/persona_check.sh" Architect || fail "single-session fallback (no env var) should pass"

# --no-legacy-mirror suppresses the singleton write.
"$S/session_state_write.sh" --persona Researcher --session-id sess-D --started-at 2026-06-14T00:00:02Z --no-legacy-mirror >/dev/null
[[ "$(jq -r .persona "$TMP/.session_state.json")" == "Architect" ]] || fail "--no-legacy-mirror must not touch singleton"
test -f "$TMP/.session_state.sess-D.json" || fail "keyed file written even with --no-legacy-mirror"

# --- 6. Aggregate visibility (documented glob) ------------------------------
COUNT=$(ls "$TMP"/.session_state.*.json 2>/dev/null | wc -l | tr -d ' ')
[[ "$COUNT" -ge 4 ]] || fail "expected >=4 keyed files for visibility glob, got $COUNT"

# --- 7. Stale cleanup -------------------------------------------------------
# Explicit removal by id (age-independent).
"$S/session_state_cleanup.sh" --session-id sess-A >/dev/null
test ! -f "$TMP/.session_state.sess-A.json" || fail "cleanup --session-id did not remove sess-A"
test -f "$TMP/.session_state.sess-B.json"   || fail "cleanup --session-id removed the wrong file"
# Missing id → E3.
rc=0; "$S/session_state_cleanup.sh" --session-id sess-GONE 2>/dev/null || rc=$?
[[ "$rc" -eq 3 ]] || fail "cleanup of missing id should exit 3, got $rc"
# Age sweep: backdate sess-C two days, sweep >24h, confirm it goes and a fresh one stays.
touch -t 202606120000 "$TMP/.session_state.sess-C.json"
"$S/session_state_cleanup.sh" --max-age-hours 24 >/dev/null
test ! -f "$TMP/.session_state.sess-C.json" || fail "age sweep did not remove backdated sess-C"
test -f "$TMP/.session_state.sess-B.json"   || fail "age sweep removed a fresh file"
# Singleton must survive every sweep.
test -f "$TMP/.session_state.json" || fail "cleanup removed the legacy singleton"

echo "SMOKE: OK"

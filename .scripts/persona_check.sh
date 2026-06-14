#!/usr/bin/env bash
# persona_check.sh
#
# Standalone persona gate - verifies the active session persona matches the
# expected value by reading .vault_link/.session_state.json. Used as a
# precondition by mutating atoms (e.g., write_task_section.sh) and may be
# invoked directly by the slash command for pre-flight checks.
#
# Contract: Tool_Registry.md § Subagent Engine Atoms § persona_check
# Idempotent: Yes (read-only).
# Persona Gate: any (this script IS the persona gate).
#
# Exit codes:
#   0  - persona matches
#   4  - mismatch OR state file missing OR malformed (E4)

set -euo pipefail

if [[ $# -ne 1 || -z "${1:-}" ]]; then
  echo "Usage: $(basename "$0") <expected-persona>" >&2
  echo "E4: missing or empty expected-persona arg" >&2
  exit 4
fi

EXPECTED="$1"

# Resolve vault state file (script lives in .vault_link/.scripts/).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
VAULT_DIR="$(dirname "$SCRIPT_DIR")"

# Session resolution: a session exports TITAN_SESSION_ID and reads its OWN
# per-session state file (race-free under concurrency). When unset, fall back to
# the legacy singleton mirror — the back-compat path for the current handshake and
# the existing atoms, none of which set the env var yet (Phase B wires this in via
# /graduate on Context_Injection_Protocol.md § 1.5). Session id is sanitized to
# match session_state_write.sh's filename rule.
SESSION_ID="${TITAN_SESSION_ID:-}"
if [[ -n "$SESSION_ID" ]]; then
  SAFE_ID="${SESSION_ID//[^A-Za-z0-9._-]/_}"
  STATE_FILE="$VAULT_DIR/.session_state.$SAFE_ID.json"
else
  STATE_FILE="$VAULT_DIR/.session_state.json"
fi

if [[ ! -f "$STATE_FILE" ]]; then
  echo "E4: no session state at $STATE_FILE - run handshake first" >&2
  exit 4
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "E4: jq not installed (required for persona_check.sh; see kit prerequisites)" >&2
  exit 4
fi

ACTUAL="$(jq -r '.persona // empty' "$STATE_FILE" 2>/dev/null || true)"

if [[ -z "$ACTUAL" ]]; then
  echo "E4: persona field missing or empty in $STATE_FILE" >&2
  exit 4
fi

if [[ "$ACTUAL" != "$EXPECTED" ]]; then
  echo "E4: persona mismatch - expected '$EXPECTED', live session is '$ACTUAL'" >&2
  exit 4
fi

# Read-only tool, no telemetry per Composition Rule 4.
exit 0

#!/usr/bin/env bash
# session_state_write.sh
#
# Persists the active session identity to .vault_link/.session_state.json.
# Called at the end of the boot handshake (Post-Boot Ritual per
# Context_Injection_Protocol.md § 1.5) and again at every refresh trigger.
#
# Contract: Tool_Registry.md § Subagent Engine Atoms § session_state_write
# Idempotent: No (each call overwrites - new session, new state).
# Persona Gate: any (handshake context - no live persona to check yet).
#
# Exit codes:
#   0  - state file written
#   2  - filesystem failure (E2)

set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") --persona <name> --session-id <id> --started-at <ISO ts> [--surface <name>]

Writes .vault_link/.session_state.json.

Required:
  --persona <name>       Active persona (Executioner | Architect | Researcher | Synthesizer | Content_Producer)
  --session-id <id>      Opaque session identifier (UUID, epoch, or composite)
  --started-at <ISO>     ISO 8601 timestamp when this session began

Optional:
  --surface <name>       Agent surface (default: claude-code; others: opencode, chatgpt, ...)

Exit codes:
  0  success
  2  filesystem write failure (E2)
EOF
}

PERSONA=""
SESSION_ID=""
STARTED_AT=""
AGENT_SURFACE="claude-code"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --persona)     PERSONA="$2"; shift 2 ;;
    --session-id)  SESSION_ID="$2"; shift 2 ;;
    --started-at)  STARTED_AT="$2"; shift 2 ;;
    --surface)     AGENT_SURFACE="$2"; shift 2 ;;
    -h|--help)     usage; exit 0 ;;
    *)             echo "Unknown arg: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ -z "$PERSONA" || -z "$SESSION_ID" || -z "$STARTED_AT" ]]; then
  echo "E2: missing required arg" >&2
  usage >&2
  exit 2
fi

START_TS_MS=$(($(date +%s) * 1000))

# Script lives at .vault_link/.scripts/; vault is one dir up.
# pwd -P resolves the .vault_link symlink to its iCloud target.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
VAULT_DIR="$(dirname "$SCRIPT_DIR")"
STATE_FILE="$VAULT_DIR/.session_state.json"

# Atomic write: temp file in same dir, then rename.
TMP_FILE="$(mktemp "$VAULT_DIR/.session_state.XXXXXX" 2>/dev/null)" || {
  echo "E2: failed to create temp file in $VAULT_DIR" >&2
  exit 2
}
trap 'rm -f "$TMP_FILE"' EXIT

cat > "$TMP_FILE" <<EOF
{
  "persona": "$PERSONA",
  "session_id": "$SESSION_ID",
  "started_at": "$STARTED_AT",
  "agent_surface": "$AGENT_SURFACE"
}
EOF

if ! mv "$TMP_FILE" "$STATE_FILE"; then
  echo "E2: failed to install state file at $STATE_FILE" >&2
  END_TS_MS=$(($(date +%s) * 1000))
  "$SCRIPT_DIR/emit_telemetry.sh" session_state_write error $((END_TS_MS - START_TS_MS)) E2 "$PERSONA" 2>/dev/null || true
  exit 2
fi
trap - EXIT

# Telemetry per Composition Rule 3 (write tool emits) + Rule 1 carve-out (emit_telemetry is the exempt callee).
END_TS_MS=$(($(date +%s) * 1000))
"$SCRIPT_DIR/emit_telemetry.sh" session_state_write success $((END_TS_MS - START_TS_MS)) null "$PERSONA" 2>/dev/null || true

exit 0

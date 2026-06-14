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
  --no-legacy-mirror     Skip writing the singleton .session_state.json mirror.
                         The mirror is the back-compat bridge for callers that do
                         not yet set TITAN_SESSION_ID (current handshake + atoms).
                         Phase B passes this once every reader resolves by session id,
                         fully eliminating the shared-file write (and its iCloud
                         conflicted-copy risk).

State files:
  Canonical, per-session:  .session_state.<session-id>.json  (race-free by construction)
  Legacy mirror (default): .session_state.json               (last-writer-wins; bridge only)

Exit codes:
  0  success
  2  filesystem write failure (E2)
EOF
}

PERSONA=""
SESSION_ID=""
STARTED_AT=""
AGENT_SURFACE="claude-code"
LEGACY_MIRROR=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --persona)           PERSONA="$2"; shift 2 ;;
    --session-id)        SESSION_ID="$2"; shift 2 ;;
    --started-at)        STARTED_AT="$2"; shift 2 ;;
    --surface)           AGENT_SURFACE="$2"; shift 2 ;;
    --no-legacy-mirror)  LEGACY_MIRROR=0; shift ;;
    -h|--help)           usage; exit 0 ;;
    *)                   echo "Unknown arg: $1" >&2; usage >&2; exit 2 ;;
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

# Filename-safe session id (opaque ids may carry composite separators; guard
# against path traversal and odd chars by collapsing to [A-Za-z0-9._-]).
SAFE_ID="${SESSION_ID//[^A-Za-z0-9._-]/_}"
KEYED_FILE="$VAULT_DIR/.session_state.$SAFE_ID.json"
LEGACY_FILE="$VAULT_DIR/.session_state.json"

write_fail() {
  echo "E2: $1" >&2
  local end=$(($(date +%s) * 1000))
  "$SCRIPT_DIR/emit_telemetry.sh" session_state_write error $((end - START_TS_MS)) E2 "$PERSONA" 2>/dev/null || true
  exit 2
}

# Atomic write of one target: temp file in the same dir, then rename.
write_state() {
  local target="$1"
  local tmp
  tmp="$(mktemp "$VAULT_DIR/.session_state.XXXXXX" 2>/dev/null)" || write_fail "failed to create temp file in $VAULT_DIR"
  cat > "$tmp" <<EOF
{
  "persona": "$PERSONA",
  "session_id": "$SESSION_ID",
  "started_at": "$STARTED_AT",
  "agent_surface": "$AGENT_SURFACE"
}
EOF
  mv "$tmp" "$target" || { rm -f "$tmp"; write_fail "failed to install state file at $target"; }
}

# Canonical per-session file (always). Legacy singleton mirror (default on).
write_state "$KEYED_FILE"
if [[ "$LEGACY_MIRROR" -eq 1 ]]; then
  write_state "$LEGACY_FILE"
fi

# Telemetry per Composition Rule 3 (write tool emits) + Rule 1 carve-out (emit_telemetry is the exempt callee).
END_TS_MS=$(($(date +%s) * 1000))
"$SCRIPT_DIR/emit_telemetry.sh" session_state_write success $((END_TS_MS - START_TS_MS)) null "$PERSONA" 2>/dev/null || true

exit 0

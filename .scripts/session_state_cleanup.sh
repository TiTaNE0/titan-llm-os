#!/usr/bin/env bash
# session_state_cleanup.sh
#
# Housekeeping atom: remove stale per-session state files
# (.session_state.<id>.json) orphaned by crashed or ended sessions. NEVER touches
# the legacy singleton .session_state.json — that is the active back-compat mirror.
#
# Staleness policy: a keyed file is stale when its mtime is older than
# --max-age-hours (default 24). Live sessions rewrite their file at every handshake
# / refresh, so a cold mtime means the session is gone. Either sweep by age (no
# args) or delete one file explicitly via --session-id (age-independent).
#
# Contract: Tool_Registry.md § session_state_cleanup (registration deferred to the
#           Phase B /graduate session per Orchestrator A2 — Brain file not edited here).
# Idempotent: Yes (a second run after a sweep removes nothing new).
# Persona Gate: any (pure housekeeping; only ever touches the .session_state.<id>.json pattern).
# Telemetry: MANDATORY per Composition Rule 3.
#
# Exit codes:
#   0  success (including nothing-to-remove)
#   2  invalid args (E2)
#   3  --session-id given but no matching file (E3)

set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [--session-id <id>] [--max-age-hours <N>] [--dry-run]

Modes:
  (no --session-id)   Sweep all .session_state.<id>.json files older than
                      --max-age-hours (default 24). The legacy singleton is skipped.
  --session-id <id>   Remove exactly that session's file, regardless of age.

Options:
  --max-age-hours <N> Age threshold in hours for the sweep mode (default 24).
  --dry-run           Print what would be removed; remove nothing.

Exit codes:
  0  success (including nothing to remove)
  2  invalid args (E2)
  3  --session-id given but no such file (E3)
EOF
}

SESSION_ID=""
MAX_AGE_HOURS=24
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --session-id)    SESSION_ID="$2"; shift 2 ;;
    --max-age-hours) MAX_AGE_HOURS="$2"; shift 2 ;;
    --dry-run)       DRY_RUN=1; shift ;;
    -h|--help)       usage; exit 0 ;;
    *)               echo "E2: unknown arg: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if ! [[ "$MAX_AGE_HOURS" =~ ^[0-9]+$ ]]; then
  echo "E2: --max-age-hours must be a non-negative integer; got '$MAX_AGE_HOURS'" >&2
  exit 2
fi

START_TS_MS=$(($(date +%s) * 1000))
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
VAULT_DIR="$(dirname "$SCRIPT_DIR")"

emit() {
  local status="$1" eclass="$2"
  local end=$(($(date +%s) * 1000))
  "$SCRIPT_DIR/emit_telemetry.sh" session_state_cleanup "$status" $((end - START_TS_MS)) "$eclass" system 2>/dev/null || true
}

remove_one() {
  local f="$1"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "would remove $f"
  else
    rm -f "$f"
    echo "removed $f"
  fi
}

if [[ -n "$SESSION_ID" ]]; then
  SAFE_ID="${SESSION_ID//[^A-Za-z0-9._-]/_}"
  F="$VAULT_DIR/.session_state.$SAFE_ID.json"
  if [[ ! -f "$F" ]]; then
    echo "E3: no session state file for id '$SESSION_ID' at $F" >&2
    emit error E3
    exit 3
  fi
  remove_one "$F"
  emit success null
  exit 0
fi

# Sweep mode: keyed files older than the threshold; singleton is never matched
# by the pattern, but guard explicitly in case of an odd filesystem.
removed=0
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  [[ "$(basename "$f")" == ".session_state.json" ]] && continue
  remove_one "$f"
  removed=$((removed + 1))
done < <(find "$VAULT_DIR" -maxdepth 1 -type f -name '.session_state.*.json' -mmin +$((MAX_AGE_HOURS * 60)) 2>/dev/null || true)

echo "swept $removed stale session file(s) older than ${MAX_AGE_HOURS}h"
emit success null
exit 0

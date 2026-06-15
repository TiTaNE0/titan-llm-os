#!/usr/bin/env bash
# run_digest.sh
#
# Orchestrator REPORT primitive (C1, PRD §3 REPORT). Appends one line to a per-run
# digest note so a whole run is auditable end to end (tasks touched, verdicts, queue
# entries, stops). One digest file per run id.
#
# Writes `04_Logs/Orchestrator/<run_id>.md` (created with a header if absent).
# Distinct from append_log (date-keyed daily journal) — this is run-keyed.
#
# Contract: Tool_Registry.md § run_digest (registration deferred to Phase C /graduate).
# Idempotent: ❌ (always appends).
# Persona Gate: any (operational logging, like append_log).
# Telemetry: none (logging primitive; best-effort, never the macro's telemetry).
#
# Exit codes:
#   0  appended
#   2  invalid args OR filesystem write failure (E2)

set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") --run-id <id> --line <text> [--digest-dir <path>]

Required:
  --run-id <id>        Orchestrator run id (sanitized for the filename)
  --line <text>        One digest line (e.g. "dispatch [[Task]] execute_task -> queued spec_gate")

Optional:
  --digest-dir <path>  Override digest dir (default: <vault>/04_Logs/Orchestrator). For tests.

Exit codes:
  0  appended
  2  invalid args OR write failure (E2)
EOF
}

RUN_ID=""
LINE=""
DIGEST_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)     RUN_ID="$2"; shift 2 ;;
    --line)       LINE="$2"; shift 2 ;;
    --digest-dir) DIGEST_DIR="$2"; shift 2 ;;
    -h|--help)    usage; exit 0 ;;
    *)            echo "E2: unknown arg: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ -z "$RUN_ID" || -z "$LINE" ]]; then
  echo "E2: --run-id and --line are required" >&2; usage >&2; exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
VAULT_DIR="$(dirname "$SCRIPT_DIR")"
DIGEST_DIR="${DIGEST_DIR:-$VAULT_DIR/04_Logs/Orchestrator}"

SAFE_ID="${RUN_ID//[^A-Za-z0-9._-]/_}"

mkdir -p "$DIGEST_DIR" 2>/dev/null || { echo "E2: cannot create digest dir $DIGEST_DIR" >&2; exit 2; }
F="$DIGEST_DIR/$SAFE_ID.md"

if [[ ! -f "$F" ]]; then
  printf '# Orchestrator Run %s\n\n' "$RUN_ID" > "$F" 2>/dev/null || { echo "E2: cannot create digest $F" >&2; exit 2; }
fi

ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf -- '- %s | %s\n' "$ISO" "$LINE" >> "$F" 2>/dev/null || { echo "E2: append failed to $F" >&2; exit 2; }

echo "$F"
exit 0

#!/usr/bin/env bash
# budget_check.sh
#
# Purpose: Measure wall-clock elapsed time for an Orchestrator run and enforce
# the budget.max_minutes ceiling. Reads the first '- ' digest line's timestamp,
# computes elapsed minutes since that anchor, and exits 3 if the ceiling is
# breached. This makes the budget knob in Orchestrator_Config.yaml measurable.
#
# BSD date (macOS): epoch conversion MUST use TZ=UTC — without it, BSD date
# parses the literal-Z suffix in LOCAL time, skewing the epoch by the UTC
# offset (hours) and falsely breaching a 60m ceiling immediately.
#
# Contract: Tool_Registry.md § Orchestrator Loop Atoms § budget_check (registered /graduate 2026-10-30).
# Persona Gate: any (read-only operational guard).
# Telemetry: none.
#
# Exit codes:
#   0  elapsed < ceiling (or no digest lines yet — not yet measurable)
#   2  invalid args / missing digest file / unparseable timestamp (E2)
#   3  budget ceiling reached (E3) — elapsed >= ceiling

set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") --run-id <id> --ceiling <minutes> [--digest-dir <path>]

Required:
  --run-id <id>         Orchestrator run id
  --ceiling <minutes>   Budget ceiling in wall-clock minutes

Optional:
  --digest-dir <path>   Directory containing run digest files
                        (default: <vault>/04_Logs/Orchestrator)
EOF
}

RUN_ID=""; CEILING=""; DIGEST_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)      RUN_ID="$2";     shift 2 ;;
    --ceiling)     CEILING="$2";    shift 2 ;;
    --digest-dir)  DIGEST_DIR="$2"; shift 2 ;;
    -h|--help)     usage; exit 0 ;;
    *)             echo "E2: unknown arg: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -z "$RUN_ID" ]]   && { echo "E2: --run-id required" >&2;  usage >&2; exit 2; }
[[ -z "$CEILING" ]]  && { echo "E2: --ceiling required" >&2; usage >&2; exit 2; }

# Validate ceiling is an integer
if ! [[ "$CEILING" =~ ^[0-9]+$ ]]; then
  echo "E2: --ceiling must be a non-negative integer" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
VAULT_DIR="$(dirname "$SCRIPT_DIR")"
SAFE_RID="${RUN_ID//[^A-Za-z0-9._-]/_}"
DIGEST_DIR="${DIGEST_DIR:-$VAULT_DIR/04_Logs/Orchestrator}"
DIGEST_FILE="$DIGEST_DIR/$SAFE_RID.md"

if [[ ! -f "$DIGEST_FILE" ]]; then
  echo "E2: digest file not found: $DIGEST_FILE" >&2
  exit 2
fi

# Extract the first '- ' line timestamp using the pinned awk incantation
TS=$(awk '/^- /{sub(/^- /,""); sub(/ \|.*/,""); print; exit}' "$DIGEST_FILE")

if [[ -z "$TS" ]]; then
  echo "elapsed: n/a (no digest lines yet)"
  exit 0
fi

# Epoch conversion: TZ=UTC is load-bearing — BSD date without it parses the
# literal-Z suffix in local time, skewing elapsed by the UTC offset.
NOW=$(TZ=UTC date -u +%s)
START=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%SZ" "$TS" +%s 2>/dev/null) || {
  echo "E2: unparseable timestamp: $TS" >&2
  exit 2
}

ELAPSED_MIN=$(( (NOW - START) / 60 ))

if [[ "$ELAPSED_MIN" -ge "$CEILING" ]]; then
  echo "E3: budget ceiling reached (${ELAPSED_MIN}m elapsed >= ${CEILING}m)" >&2
  exit 3
fi

echo "elapsed: ${ELAPSED_MIN}m (ceiling ${CEILING}m, run ${RUN_ID})"
exit 0

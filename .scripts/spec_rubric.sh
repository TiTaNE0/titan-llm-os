#!/usr/bin/env bash
# spec_rubric.sh
#
# Deterministic FORM layer of the Orchestrator spec gate (C2, PRD §4.4 layer 1).
# Checks only the scriptable form items:
#   (a) ## Spec is populated (not just the template blockquote)
#   (b) a file-change list is present in the spec
#   (c) zero open-question markers remain
#
# The semantic item — "every acceptance criterion maps to a spec section" — is NOT
# scriptable here; it is delegated to the PM-reviewer subagent (layer 2). The gate
# composes them asymmetrically: a rubric FAIL can never be rescued by the reviewer;
# the reviewer can only FLAG a rubric PASS (PRD §4.4 / §8.2).
#
# Contract: Tool_Registry.md § spec_rubric (registration deferred to Phase C /graduate).
# Read-only. Persona Gate: any. Telemetry: none (the gate emits flag-rate telemetry).
#
# Exit codes:
#   0  rubric PASS ("RUBRIC: PASS" on stdout)
#   2  bad args / task file missing (E2)
#   3  rubric FAIL (one-line reason on stderr)

set -euo pipefail

usage() { echo "Usage: $(basename "$0") --task-path <abs>"; }

TASK_PATH=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --task-path) TASK_PATH="$2"; shift 2 ;;
    -h|--help)   usage; exit 0 ;;
    *)           echo "E2: unknown arg: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -z "$TASK_PATH" ]] && { echo "E2: --task-path required" >&2; usage >&2; exit 2; }
[[ -f "$TASK_PATH" ]] || { echo "E2: task file not found: $TASK_PATH" >&2; exit 2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# (a) spec populated — reuse the canonical emoji-tolerant section matcher.
if ! "$SCRIPT_DIR/grep_section.sh" "$TASK_PATH" "Spec" populated >/dev/null 2>&1; then
  echo "RUBRIC FAIL: ## Spec is empty" >&2; exit 3
fi

# Extract the Spec section body (from the Spec header to the next ## header).
BODY="$(awk '
  /^##[[:space:]]/ {
    if (inspec) exit
    if ($0 ~ /Spec[[:space:]]*$/) { inspec=1; next }
  }
  inspec { print }
' "$TASK_PATH")"

# (b) file-change list present: a path-like token or an explicit "file" mention.
if ! printf '%s' "$BODY" | grep -qiE '\.(sh|md|ya?ml|json|py|ts|js|tsx|jsx)\b|/[A-Za-z0-9_]|file'; then
  echo "RUBRIC FAIL: no file-change list in spec" >&2; exit 3
fi

# (c) zero open-question markers.
if printf '%s' "$BODY" | grep -qiE 'open question|[[:space:]]TBD\b|\?\?\?|[[:space:]]TODO\b|FIXME'; then
  echo "RUBRIC FAIL: open questions remain in spec" >&2; exit 3
fi

echo "RUBRIC: PASS"
exit 0

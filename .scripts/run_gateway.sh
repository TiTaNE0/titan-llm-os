#!/usr/bin/env bash
# run_gateway.sh
#
# Guarded execution atom for the § Verification Gateway Test Command.
# Self-extracts the Test Command from the task file (never accepts it as an arg),
# validates it against an allowlist, and under --orchestrator-mode refuses any
# task whose gateway_provenance frontmatter is not 'human'.
#
# Contract: Layer-2 atom; called by /execute_task Step 13.
# Persona Gate: Executioner.
# Telemetry: MANDATORY (success + error).
#
# Exit codes:
#   0  gateway ran (inner exit code reported on stdout via GATEWAY_EXIT=)
#   1  task file, Verification Gateway section, or Test Command line missing (E1)
#   3  allowlist or provenance refusal (E3; distinct reason on stderr)
#   4  source_persona != Executioner or live persona != Executioner (E4)
#
# stdout contract (exit 0 only, pinned — callers parse these markers):
#   GATEWAY_CMD=<extracted command>
#   GATEWAY_EXIT=<exit code of inner bash -c>
#   --- GATEWAY OUTPUT ---
#   <combined stdout+stderr of inner command>

set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") --task-path <abs> --source-persona <name> [--orchestrator-mode]

Exit codes: 0 ran; 1 file/section/cmd missing (E1); 3 allowlist/provenance refusal (E3); 4 persona (E4)
EOF
}

TASK_PATH=""; SOURCE_PERSONA=""; ORCH_MODE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --task-path)        TASK_PATH="$2";        shift 2 ;;
    --source-persona)   SOURCE_PERSONA="$2";   shift 2 ;;
    --orchestrator-mode) ORCH_MODE=1;          shift ;;
    -h|--help)          usage; exit 0 ;;
    *) echo "E3: unknown arg: $1" >&2; usage >&2; exit 3 ;;
  esac
done

START_TS_MS=$(($(date +%s) * 1000))
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
. "$SCRIPT_DIR/lib_section.sh"
emit_err() {
  local e=$(($(date +%s) * 1000))
  "$SCRIPT_DIR/emit_telemetry.sh" run_gateway error $((e - START_TS_MS)) "$1" \
    "${SOURCE_PERSONA:-unknown}" 2>/dev/null || true
}

if [[ -z "$TASK_PATH" || -z "$SOURCE_PERSONA" ]]; then
  echo "E3: missing required arg (--task-path and --source-persona are required)" >&2
  usage >&2; emit_err E3; exit 3
fi

# Persona gate
if [[ "$SOURCE_PERSONA" != "Executioner" ]]; then
  echo "E4: source_persona must be 'Executioner'; got '$SOURCE_PERSONA'" >&2
  emit_err E4; exit 4
fi
if ! "$SCRIPT_DIR/persona_check.sh" "Executioner"; then
  echo "E4: run_gateway requires Executioner persona; persona_check failed" >&2
  emit_err E4; exit 4
fi

# File guard
if [[ ! -f "$TASK_PATH" ]]; then
  echo "E1: task file not found: $TASK_PATH" >&2; emit_err E1; exit 1
fi

# Read gateway_provenance from first frontmatter block (absent → human)
PROV="$(awk '
  /^---$/ { c++; if (c==2) exit }
  c==1 && /^gateway_provenance:/ {
    sub(/^gateway_provenance:[[:space:]]*/, "")
    print
    exit
  }
' "$TASK_PATH")"
[[ -z "$PROV" ]] && PROV="human"

# Extract the raw **Test Command:** value from the § Verification Gateway section.
# Scoped to the section (starts at "## ... Verification Gateway", ends at the
# next template "## " header or EOF). Returns the portion of the line after the prefix.
CMDLINE="$(awk "$SECTION_AWK"'
  /^## / && /Verification Gateway/ { in_gw=1; next }
  in_gw && sec_is_template($0)     { in_gw=0 }
  in_gw && /\*\*Test Command:\*\*/ {
    sub(/.*\*\*Test Command:\*\*[[:space:]]*/, "")
    print; exit
  }
' "$TASK_PATH")"

if [[ -z "$CMDLINE" ]]; then
  echo "E1: Verification Gateway section or Test Command not found in $TASK_PATH" >&2
  emit_err E1; exit 1
fi

# Strip one outer backtick pair when the value uses the standard `cmd` format.
# This exposes any backtick command substitution inside for the denial check below.
if [[ "$CMDLINE" == '`'*'`' ]]; then
  TEST_CMD="${CMDLINE#\`}"
  TEST_CMD="${TEST_CMD%\`}"
else
  TEST_CMD="$CMDLINE"
fi

if [[ -z "$TEST_CMD" ]]; then
  echo "E1: Test Command is empty in $TASK_PATH" >&2
  emit_err E1; exit 1
fi

# --- Validation chain ---

# 1. Deny command substitution: $(
if [[ "$TEST_CMD" == *'$('* ]]; then
  echo "E3: command substitution '\$(' denied in gateway command: $TEST_CMD" >&2
  emit_err E3; exit 3
fi

# 2. Deny backtick command substitution
if [[ "$TEST_CMD" == *'`'* ]]; then
  echo "E3: backtick command substitution denied in gateway command: $TEST_CMD" >&2
  emit_err E3; exit 3
fi

# 3. Deny absolute-path leading token
if [[ "$TEST_CMD" == /* ]]; then
  echo "E3: absolute-path leading token denied in gateway command: $TEST_CMD" >&2
  emit_err E3; exit 3
fi

# 4. Deny destructive leading token
FIRST_TOKEN="$(printf '%s' "$TEST_CMD" | awk '{print $1}')"
if [[ "$FIRST_TOKEN" =~ ^(rm|dd|mkfs|shred|truncate|kill)$ ]]; then
  echo "E3: destructive leading token '$FIRST_TOKEN' denied in gateway command: $TEST_CMD" >&2
  emit_err E3; exit 3
fi

# 5. Allowlist: command must start with a recognized safe leading binary, bounded
# by whitespace or end-of-string so prefix matches are impossible (e.g. 'shutdown'
# must not pass via '^sh', 'dockerd' via '^docker', 'gitleaks' via '^git').
ALLOWLIST='^((bash|sh|npm|pnpm|npx|uv|make|go|grep|git|curl|docker|python3?|pytest|xcodebuild|sqlite3|test|cd)([[:space:]]|$)|\./|\.vault_link/)'
if ! [[ "$TEST_CMD" =~ $ALLOWLIST ]]; then
  echo "E3: gateway command does not match allowlist; refused: $TEST_CMD" >&2
  emit_err E3; exit 3
fi

# --- Provenance gate (orchestrator-mode only) ---
if [[ "$ORCH_MODE" -eq 1 && "$PROV" != "human" ]]; then
  echo "E3: gateway provenance '$PROV' is not human-authored; refused under --orchestrator-mode" >&2
  emit_err E3; exit 3
fi

# --- Execute ---
set +e
INNER_OUT="$(bash -c "$TEST_CMD" 2>&1)"
GATEWAY_EXIT=$?
set -e

# Emit stdout contract markers (pinned — callers sed-parse these)
printf 'GATEWAY_CMD=%s\n' "$TEST_CMD"
printf 'GATEWAY_EXIT=%s\n' "$GATEWAY_EXIT"
printf -- '--- GATEWAY OUTPUT ---\n'
printf '%s\n' "$INNER_OUT"

# Telemetry
END_TS_MS=$(($(date +%s) * 1000))
"$SCRIPT_DIR/emit_telemetry.sh" run_gateway success $((END_TS_MS - START_TS_MS)) null \
  "$SOURCE_PERSONA" 2>/dev/null || true

exit 0

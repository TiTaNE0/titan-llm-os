#!/usr/bin/env bash
# task_contract_check.sh
#
# Refuse to execute a task whose header contract is still template placeholders
# (Task_Contract_Population_And_Guard). `/new_task` scaffolds Objective / DoD /
# Verification-Gateway as placeholders; `/execute_task` consumes them (spec-writer,
# validator, the gateway step) but never populates them — so an unfilled task would
# run against a hollow contract and the real contract would leak into the Spec. This
# guard makes that fail loudly instead.
#
# Checks for the exact Task_Template placeholder strings in the three header sections.
#
# Contract: Tool_Registry.md § task_contract_check (registration deferred to /graduate).
# Read-only. Persona Gate: any. Telemetry: none (read-only per Composition Rule 4).
#
# Exit codes:
#   0  contract authored (all three sections non-placeholder) — "CONTRACT: OK"
#   2  bad args / task file missing (E2)
#   3  a placeholder remains (one line per offending section on stderr)

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

fail=0
# Match the EXACT placeholder LINE (grep -x), not a substring — so a task that merely
# *mentions* a placeholder string in prose (e.g. a task about the placeholders) is not
# a false positive. A populated section no longer contains the verbatim placeholder line.
check() { # section-label  placeholder-line
  if grep -qxF -- "$2" "$TASK_PATH"; then
    echo "CONTRACT FAIL: § $1 is still a template placeholder — author it before executing" >&2
    fail=1
  fi
}

check "Declarative Objective"          "- [ ] (What we want to achieve)"
check "Definition of Done"             "- [ ] (Success criteria)"
check "Verification Gateway"           "- [ ] **Test Command:** (Command to run)"

if [[ "$fail" -eq 1 ]]; then
  exit 3
fi

echo "CONTRACT: OK"
exit 0

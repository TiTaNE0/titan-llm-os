#!/usr/bin/env bash
# Shared setup for Chain_Consolidation_Planner_Context_Pack acceptance tests.
# Every write goes to a mktemp vault; the real vault and kit are only read.
set -uo pipefail
unset TITAN_SESSION_ID

VAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
KIT="${KIT_ROOT:-$HOME/AI_Workflow/claude-agent-kit}"
EXEC_MD="$KIT/project-template/.claude/commands/execute_task.md"
AGENTS="$KIT/global/agents"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

FAILED=0
fail() { echo "FAIL: $1" >&2; FAILED=1; }
pass() { echo "ok: $1"; }
finish() { [ "$FAILED" -eq 0 ] && { echo "PASS"; exit 0; }; echo "FAILED" >&2; exit 1; }
# expect <label> <expected> <actual>
expect() { [ "$3" = "$2" ] && pass "$1" || fail "$1: expected [$2], got [$3]"; }

# step_body <N>: lines of execute_task.md from "## Step <N> —" up to the next "## " heading.
step_body() {
  awk -v h="## Step $1 —" 'index($0, h) == 1 { on = 1; print; next } on && /^## / { exit } on { print }' "$EXEC_MD"
}
# block_body <heading>: lines under an exact "## <heading>" up to the next "## " heading.
block_body() {
  awk -v h="## $1" '$0 == h { on = 1; next } on && /^## / { exit } on { print }' "$EXEC_MD"
}

# mk_vault <dir>: minimal vault with real copies of the scripts under test, .vault_link -> .
mk_vault() {
  local d="$1" s
  mkdir -p "$d/.scripts" "$d/04_Logs/Telemetry" "$d/02_Tasks/P"
  for s in write_task_section lib_section persona_check emit_telemetry grep_section \
           spec_rubric telemetry_task_report telemetry_start task_owner; do
    cp "$VAULT/.scripts/$s.sh" "$d/.scripts/"
  done
  chmod +x "$d/.scripts/"*.sh
  ln -s . "$d/.vault_link"
  printf '{\n  "persona": "Executioner",\n  "session_id": "acc",\n  "started_at": "2026-11-08T00:00:00Z",\n  "agent_surface": "test"\n}\n' > "$d/.session_state.json"
}

# mk_task <file> [run_id]: template task file; optional orchestrator_run_id in frontmatter.
mk_task() {
  {
    printf -- '---\nproject: [[P]]\nstatus: in_progress\ntype: task\n'
    [ -n "${2:-}" ] && printf 'orchestrator_run_id: %s\n' "$2"
    cat <<'T_EOF'
---
# ⚡ Task: T

## 📋 Declarative Objective
- [ ] objective

## 🎯 Definition of Done (Success Criteria)
- [ ] criteria

## 🧪 Verification Gateway
**Test Command:** `bash tests/x.sh`

## 📝 Agent Implementation Plan
> placeholder

## 🔬 Research Notes
> placeholder
<!-- write_task_section section=research_notes -->

## 📐 Spec
> placeholder
<!-- write_task_section section=spec -->

## ✅ Validator Report
> placeholder
<!-- write_task_section section=validator_report -->

## 📊 Verification Output
> placeholder
<!-- write_task_section section=verification_output -->

## 🏁 COMPLETION SUMMARY (Post-Mortem)
> gate
T_EOF
  } > "$1"
}

# write_spec <vault> <task> <content-file>: persist a spec through the real write path.
write_spec() {
  "$1/.scripts/write_task_section.sh" --task-path "$2" --section spec \
    --source-persona Executioner --content-file "$3" >/dev/null 2>"$TMP/wts_err" \
    || { echo "write_task_section failed: $(cat "$TMP/wts_err")" >&2; return 1; }
}

section_body() {
  awk -v a="<!-- write_task_section section=$2 -->" '
    $0 == a { on = 1; next }
    on && /^## (📋|🎯|🧪|📝|🔬|📐|✅|📊|🏁)/ { exit }
    on { print }' "$1"
}

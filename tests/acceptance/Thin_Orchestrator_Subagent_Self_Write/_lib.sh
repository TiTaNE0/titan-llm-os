#!/usr/bin/env bash
# Shared setup for Thin_Orchestrator_Subagent_Self_Write acceptance tests.
# Every write goes to a mktemp vault; the real vault is only read.
set -uo pipefail

VAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
KIT="${KIT_ROOT:-$HOME/AI_Workflow/claude-agent-kit}"
HOOK="$KIT/global/hooks/bash_write_task_section_only.sh"
EXEC_MD="$KIT/project-template/.claude/commands/execute_task.md"
# Shell that runs the hook; run_all.sh repeats the suite under /bin/bash (3.2).
HOOK_BASH="${HOOK_BASH:-bash}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export TMPDIR="$TMP/tmpdir"; mkdir -p "$TMPDIR"

FAILED=0
fail() { echo "FAIL: $1" >&2; FAILED=1; }
pass() { echo "ok: $1"; }
finish() { [ "$FAILED" -eq 0 ] && { echo "PASS"; exit 0; }; echo "FAILED" >&2; exit 1; }

hook_json() { jq -n --arg c "$1" --arg a "${2:-researcher}" '{tool_name:"Bash",agent_type:$a,tool_input:{command:$c}}'; }
# hook_rc <command>: exit code of the hook deciding on a Bash call with that command.
hook_rc() { hook_json "$1" | "$HOOK_BASH" "$HOOK" >/dev/null 2>"$TMP/hook_err"; echo $?; }
allow() { local rc; rc="$(hook_rc "$2")"; [ "$rc" = 0 ] && pass "ALLOW $1" || fail "ALLOW $1 (rc=$rc): $(cat "$TMP/hook_err")"; }
refuse() { local rc; rc="$(hook_rc "$2")"; [ "$rc" = 2 ] && pass "REFUSE $1" || fail "REFUSE $1 (rc=$rc, expected 2)"; }

# mk_vault <dir>: minimal vault with the real write path, .vault_link -> . and an Executioner session.
mk_vault() {
  local d="$1" s
  mkdir -p "$d/.scripts" "$d/04_Logs/Telemetry" "$d/02_Tasks/P"
  for s in write_task_section lib_section persona_check emit_telemetry grep_section; do
    cp "$VAULT/.scripts/$s.sh" "$d/.scripts/"
  done
  chmod +x "$d/.scripts/"*.sh
  ln -s . "$d/.vault_link"
  printf '{\n  "persona": "Executioner",\n  "session_id": "acc",\n  "started_at": "2026-11-08T00:00:00Z",\n  "agent_surface": "test"\n}\n' > "$d/.session_state.json"
  mk_task "$d/02_Tasks/P/T.md"
}

mk_task() {
  cat > "$1" <<'T_EOF'
---
project: [[P]]
status: in_progress
type: task
---
# ⚡ Task: T

## 📋 Declarative Objective
- [ ] objective

## 🎯 Definition of Done (Success Criteria)
- [ ] criteria

## 🧪 Verification Gateway
- [ ] **Test Command:** none

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
}

# section_body <task> <section>: lines between the anchor and the next template heading.
section_body() {
  awk -v a="<!-- write_task_section section=$2 -->" '
    $0 == a { on = 1; next }
    on && /^## (📋|🎯|🧪|📝|🔬|📐|✅|📊|🏁)/ { exit }
    on { print }' "$1"
}

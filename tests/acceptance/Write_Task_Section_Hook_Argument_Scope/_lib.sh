#!/usr/bin/env bash
# Shared setup for Write_Task_Section_Hook_Argument_Scope acceptance tests.
# Hook input is JSON on stdin only; every write lands in a mktemp vault.
set -uo pipefail
unset TITAN_SESSION_ID TELEMETRY_DIR

VAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
KIT="${KIT_ROOT:-$HOME/AI_Workflow/claude-agent-kit}"
HOOK="$KIT/global/hooks/bash_write_task_section_only.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export TMPDIR="$TMP/tmpdir"; mkdir -p "$TMPDIR"

FAILED=0
fail() { echo "FAIL: $1" >&2; FAILED=1; }
pass() { echo "ok: $1"; }
finish() { [ "$FAILED" -eq 0 ] && { echo "PASS"; exit 0; }; echo "FAILED" >&2; exit 1; }

# hook_json <cmd> [agent_type]: agent_type omitted when empty.
hook_json() {
  if [ -n "${2:-}" ]; then jq -n --arg c "$1" --arg a "$2" '{tool_name:"Bash",agent_type:$a,tool_input:{command:$c}}'
  else jq -n --arg c "$1" '{tool_name:"Bash",tool_input:{command:$c}}'; fi
}

# A fake HOME whose ~/.claude/hooks holds the kit hook, as install.sh setup-global links it.
FAKE_HOME="$TMP/home"; mkdir -p "$FAKE_HOME/.claude/hooks"
ln -s "$HOOK" "$FAKE_HOME/.claude/hooks/bash_write_task_section_only.sh"

frontmatter() { awk 'NR==1 && /^---$/ {on=1; next} on && /^---$/ {exit} on {print}' "$1"; }
# The hook command Claude Code runs for that agent, YAML single quotes removed.
hook_cmd() { frontmatter "$1" | sed -n "s/^ *command: '\(.*\)'$/\1/p" | head -1; }
# declared_rc <agent.md> <bash cmd> [agent_type]: exit code of the agent's registered hook; stderr in $TMP/err.
declared_rc() { hook_json "$2" "${3:-}" | HOME="$FAKE_HOME" sh -c "$(hook_cmd "$1")" >/dev/null 2>"$TMP/err"; echo $?; }
# direct_rc <shell> <roleArg|""> <agent_type|""> <bash cmd>: hook run directly.
direct_rc() { hook_json "$4" "$3" | "$1" "$HOOK" $2 >/dev/null 2>"$TMP/err"; echo $?; }

W=.vault_link/.scripts/write_task_section.sh
# persist <task path> <section>: the execute_task.md-shaped stdin persist call.
persist() { printf '%s --task-path "%s" --section %s --source-persona Executioner --content-file - <<'"'"'SPEC_EOF'"'"'\nbody from %s\nSPEC_EOF' "$W" "$1" "$2" "$2"; }

# mk_vault <dir>: minimal vault with the real write path, .vault_link -> . and an Executioner session.
mk_vault() {
  local d="$1" s
  mkdir -p "$d/.scripts" "$d/04_Logs/Telemetry" "$d/02_Tasks/P" "$d/02_Tasks/Other" "$d/03_Brain"
  for s in write_task_section lib_section persona_check emit_telemetry grep_section; do
    cp "$VAULT/.scripts/$s.sh" "$d/.scripts/"
  done
  chmod +x "$d/.scripts/"*.sh
  ln -s . "$d/.vault_link"
  printf '{\n  "persona": "Executioner",\n  "session_id": "acc",\n  "started_at": "2026-11-09T00:00:00Z",\n  "agent_surface": "test"\n}\n' > "$d/.session_state.json"
  mk_task "$d/02_Tasks/P/T.md"
}

mk_task() {
  cat > "$1" <<'T_EOF'
---
project: [[P]]
status: in_progress
type: task
---
# Task: T

## 🔬 Research Notes
<!-- write_task_section section=research_notes -->

## 📐 Spec
<!-- write_task_section section=spec -->

## ✅ Validator Report
<!-- write_task_section section=validator_report -->

## 📊 Verification Output
<!-- write_task_section section=verification_output -->

## 🏁 COMPLETION SUMMARY (Post-Mortem)
> gate
T_EOF
}

# run_in <vault> <cmd>: execute the Bash call the hook just judged, from the vault root.
run_in() { (cd "$1" && bash -c "$2") >/dev/null 2>"$TMP/run_err"; echo $?; }

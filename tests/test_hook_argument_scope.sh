#!/usr/bin/env bash
# test_hook_argument_scope.sh - gateway for Write_Task_Section_Hook_Argument_Scope.
# Block/allow matrix for bash_write_task_section_only.sh argument scope (--task-path shape, role-owned --section),
# declared frontmatter role arguments, then kit and vault suites.
# HAS_SKIP_SUITES=1 skips the suite loops (the aggregators use it to avoid recursion).
set -uo pipefail
unset TITAN_SESSION_ID ACC_SKIP_GATEWAY TELEMETRY_DIR

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
KIT="${KIT_ROOT:-$HOME/AI_Workflow/claude-agent-kit}"
HOOK="$KIT/global/hooks/bash_write_task_section_only.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
FAILS=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAILS=$((FAILS + 1)); }

# rc <roleArg> <agentType> <cmd> -> hook exit code; stderr in $TMP/err
rc() {
  local role="$1" at="$2" cmd="$3"
  if [ -n "$at" ]; then
    jq -n --arg c "$cmd" --arg a "$at" '{tool_name:"Bash",agent_type:$a,tool_input:{command:$c}}'
  else
    jq -n --arg c "$cmd" '{tool_name:"Bash",tool_input:{command:$c}}'
  fi | bash "$HOOK" $role >/dev/null 2>"$TMP/err"
  echo $?
}
allow() { local r; r="$(rc "$2" "$3" "$4")"; [ "$r" = 0 ] && pass "ALLOW $1" || fail "ALLOW $1 (rc=$r) $(cat "$TMP/err")"; }
block() { local r; r="$(rc "$2" "$3" "$4")"; [ "$r" = 2 ] && pass "BLOCK $1" || fail "BLOCK $1 (rc=$r)"; }

W='.vault_link/.scripts/write_task_section.sh'
P='.vault_link/02_Tasks/P/T.md'
# cmd <script> <path-args...>: heredoc-form persist call with raw argument text
mk() { printf '%s %s --source-persona Executioner --content-file - <<'"'"'E_EOF'"'"'\nbody\nE_EOF' "$1" "$2"; }
tp() { mk "$W" "--task-path $1 --section spec"; }
sc() { mk "$W" "--task-path $P --section $1"; }

if ! [ -f "$HOOK" ] || ! command -v jq >/dev/null 2>&1; then fail "hook or jq missing"; fi

# --- DoD1: path scope (planner, spec) -----------------------------------------
allow "valid path heredoc" planner "" "$(tp "$P")"
allow "script form .scripts/" planner "" "$(mk .scripts/write_task_section.sh "--task-path $P --section spec")"
allow "script form with bash prefix" planner "" "bash $(tp "$P")"
allow "quoted path with spaces" planner "" "$(tp '".vault_link/02_Tasks/stagepass/C11.17 Event wizard.md"')"
for bad in /tmp/02_Tasks/P/T.md 02_Tasks/P/T.md .vault_link/02_Tasks/T.md .vault_link/02_Tasks/P/S/T.md \
  .vault_link/03_Brain/System_Agents.md .vault_link/02_Tasks/P/T.txt .vault_link/02_Tasks/P/.T.md \
  .vault_link/02_Tasks/../01_Projects/X.md '""'; do
  block "path $bad" planner "" "$(tp "$bad")"
done
block "--task-path=" planner "" "$(mk "$W" "--task-path=$P --section spec")"
block "two --task-path (valid then foreign)" planner "" "$(mk "$W" "--task-path $P --task-path .vault_link/03_Brain/X.md --section spec")"
block "missing --task-path" planner "" "$(mk "$W" "--section spec")"
block "--task-path last token" planner "" "$W --section spec --task-path <<'E_EOF'
body
E_EOF"

# --- DoD2: section scope --------------------------------------------------------
for r in planner spec-writer; do
  allow "$r spec" "$r" "" "$(sc spec)"
  for s in research_notes validator_report verification_output; do block "$r $s" "$r" "" "$(sc $s)"; done
done
allow "researcher research_notes" researcher "" "$(sc research_notes)"
block "researcher spec" researcher "" "$(sc spec)"
block "researcher validator_report" researcher "" "$(sc validator_report)"
allow "validator validator_report" validator "" "$(sc validator_report)"
block "validator spec" validator "" "$(sc spec)"
block "unknown role builder" builder "" "$(sc spec)"
block "no arg, no agent_type" "" "" "$(sc spec)"
allow "fallback agent_type planner" "" planner "$(sc spec)"
block "fallback agent_type researcher spec" "" researcher "$(sc spec)"
allow "arg planner beats agent_type researcher" planner researcher "$(sc spec)"
block "arg researcher beats agent_type planner" researcher planner "$(sc spec)"
block "duplicate --section" planner "" "$(mk "$W" "--task-path $P --section spec --section validator_report")"
block "--section=spec" planner "" "$(mk "$W" "--task-path $P --section=spec")"
block "quoted \"--section\" \"validator_report\"" planner "" "$(mk "$W" "--task-path $P \"--section\" \"validator_report\"")"
block "dequoted --sec\"tion\" duplicate" planner "" "$(mk "$W" "--task-path $P --section spec --sec\"tion\" validator_report")"
allow "read-only ls without role" "" "" "ls -la"
rc planner "" "$(sc validator_report)" >/dev/null
head -c 62 "$TMP/err" | grep -qF 'BLOCKED (Bash limited to one write_task_section.sh call): ' && pass "section block stderr prefix" || fail "section block stderr prefix"

# --- Declared frontmatter -------------------------------------------------------
frontmatter() { awk 'NR==1 && /^---$/ {on=1; next} on && /^---$/ {exit} on {print}' "$1"; }
hook_cmd() { frontmatter "$1" | sed -n "s/^ *command: '\(.*\)'$/\1/p" | head -1; }
mkdir -p "$TMP/home/.claude/hooks"; ln -s "$HOOK" "$TMP/home/.claude/hooks/bash_write_task_section_only.sh"
declared() { # <agent.md> <cmd> -> rc
  jq -n --arg c "$2" '{tool_name:"Bash",tool_input:{command:$c}}' | HOME="$TMP/home" sh -c "$(hook_cmd "$1")" >/dev/null 2>&1; echo $?
}
for pair in global/agents/planner.md:planner:validator_report global/agents/researcher.md:researcher:spec global/agents/spec-writer.md:spec-writer:validator_report \
  docs/cld/researcher.md:researcher:spec docs/cld/spec-writer.md:spec-writer:validator_report; do
  f="${pair%%:*}"; rest="${pair#*:}"; name="${rest%%:*}"; foreign="${rest#*:}"
  own=spec; [ "$name" = researcher ] && own=research_notes
  if hook_cmd "$KIT/$f" | grep -qF "bash_write_task_section_only.sh\" $name || exit 2"; then pass "$f declares role $name"; else fail "$f role arg"; fi
  [ "$(declared "$KIT/$f" "$(sc $own)")" = 0 ] && pass "$f declared hook allows $own" || fail "$f declared allow $own"
  [ "$(declared "$KIT/$f" "$(sc $foreign)")" = 2 ] && pass "$f declared hook blocks $foreign" || fail "$f declared block $foreign"
done

# RED: a permissive stub must be detected by the block assertions.
printf 'cat >/dev/null; exit 0\n' > "$TMP/stub.sh"
r="$(jq -n --arg c "$(tp /tmp/02_Tasks/P/T.md)" '{tool_name:"Bash",tool_input:{command:$c}}' | bash "$TMP/stub.sh" planner >/dev/null 2>&1; echo $?)"
[ "$r" = 0 ] && pass "RED: always-allow stub passes foreign path (assertions can fail)" || fail "RED setup broken"

# --- Aggregator wiring pins -----------------------------------------------------
for f in test_chain_consolidation test_chain_targeted_tests test_pm_reviewer_single_pass test_kit_telemetry_isolation test_macro_start_timestamp; do
  grep -qF '[ "$b" = test_hook_argument_scope.sh ] && envp="HAS_SKIP_SUITES=1"' "$REPO_ROOT/tests/$f.sh" && pass "$f wires HAS_SKIP_SUITES" || fail "$f missing HAS_SKIP_SUITES wiring"
done

# --- Suites ---------------------------------------------------------------------
if [ "${HAS_SKIP_SUITES:-0}" = 1 ]; then
  echo "SKIP: suites"
else
  n=0
  for t in "$KIT"/tests/test_*.sh; do
    [ -f "$t" ] || continue
    n=$((n + 1))
    if ( cd "$KIT" && CLAUDE_BIN=__nonexistent__ bash "$t" >/dev/null 2>&1 ); then pass "kit $(basename "$t")"; else fail "kit $(basename "$t")"; fi
  done
  [ "$n" -ge 1 ] || fail "kit suite glob matched nothing"
  n=0
  for t in "$REPO_ROOT"/tests/test_*.sh "$REPO_ROOT"/tests/smoke_*.sh; do
    [ -f "$t" ] || continue
    b="$(basename "$t")"
    [ "$b" = test_hook_argument_scope.sh ] && continue
    n=$((n + 1))
    if [ "$b" = test_chain_consolidation.sh ]; then
      out="$( cd "$REPO_ROOT" && CHAIN_SKIP_SUITES=1 bash "tests/$b" 2>&1 )"
      if ! printf '%s\n' "$out" | grep -q '^FAIL:' && printf '%s\n' "$out" | grep -qF 'suites skipped: not a gateway pass'; then
        pass "vault $b (skip mode)"; else fail "vault $b (skip mode)"; fi
      continue
    fi
    envp=""; [ "$b" = test_thin_orchestrator.sh ] && envp="THIN_ORCH_SKIP_SUITES=1"; [ "$b" = test_pm_reviewer_single_pass.sh ] && envp="PMR_SKIP_SUITES=1"; [ "$b" = test_kit_telemetry_isolation.sh ] && envp="KTI_SKIP_SUITES=1"; [ "$b" = test_chain_targeted_tests.sh ] && envp="CTT_SKIP_SUITES=1"; [ "$b" = test_macro_start_timestamp.sh ] && envp="MST_SKIP_SUITES=1"; [ "$b" = test_spec_gate_hardening.sh ] && envp="SGH_SKIP_SUITES=1"
    if ( cd "$REPO_ROOT" && env $envp bash "tests/$b" >/dev/null 2>&1 ); then pass "vault $b"; else fail "vault $b"; fi
  done
  [ "$n" -ge 1 ] || fail "vault suite glob matched nothing"
  if ( cd "$REPO_ROOT" && ACC_SKIP_GATEWAY=1 bash tests/acceptance/Thin_Orchestrator_Subagent_Self_Write/run_all.sh >/dev/null 2>&1 ); then pass "acceptance Thin_Orchestrator_Subagent_Self_Write"; else fail "acceptance Thin_Orchestrator_Subagent_Self_Write"; fi
  if ( cd "$REPO_ROOT" && bash tests/acceptance/Chain_Consolidation_Planner_Context_Pack/test_dod3_agents_models_install.sh >/dev/null 2>&1 ); then pass "acceptance Chain_Consolidation agents/models"; else fail "acceptance Chain_Consolidation agents/models"; fi
fi

if [ "$FAILS" -eq 0 ]; then echo "ALL GREEN"; exit 0; fi
echo "$FAILS check(s) failed"; exit 1

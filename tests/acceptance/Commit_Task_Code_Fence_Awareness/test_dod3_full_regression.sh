#!/usr/bin/env bash
# DoD 3 (full): the gateway (incl. its fence RED loop) and every regression suite the spec lists
# stay green. Heavy; skipped by run_all.sh
# under ACC_SKIP_GATEWAY=1 (the chain aggregator sets it).
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
cd "$VAULT"
run() { if "$@" >"$TMP/o" 2>&1; then pass "$*"; else fail "$*"; tail -15 "$TMP/o" >&2; fi; }
if bash tests/test_section_extent.sh >"$TMP/g" 2>&1 && grep -q "RED fails:  ct_fence_backtick" "$TMP/g"; then pass "gateway green with fence RED loop"; else fail "gateway"; tail -15 "$TMP/g" >&2; fi
run bash tests/test_commit_task.sh
run /bin/bash tests/acceptance_commit_task.sh
for s in tests/smoke_*.sh; do run bash "$s"; done
run bash tests/test_thin_orchestrator.sh
for a in Chain_Consolidation_Planner_Context_Pack Thin_Orchestrator_Subagent_Self_Write Write_Task_Section_Hook_Argument_Scope; do
  run env ACC_SKIP_GATEWAY=1 bash "tests/acceptance/$a/run_all.sh"
done
KIT="${KIT_ROOT:-$HOME/AI_Workflow/claude-agent-kit}"
[ -f "$KIT/tests/test_gate_mode_contract.sh" ] && run bash "$KIT/tests/test_gate_mode_contract.sh"
finish

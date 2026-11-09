#!/usr/bin/env bash
# DoD 3: the pre-existing Step 8 pins the spec names still pass against the changed files
# (kit contract tests, and the Chain_Consolidation acceptance checks on spawns and spec_gate timing).
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

for t in test_gate_mode_contract.sh test_no_inline_mutations.sh test_agent_models.sh; do
  if ( cd "$KIT" && CLAUDE_BIN=__nonexistent__ bash "tests/$t" >"$TMP/o" 2>&1 ); then pass "kit $t"; else fail "kit $t: $(grep -m3 -i fail "$TMP/o")"; fi
done
for t in test_dod2_default_chain.sh test_dod4_step14_guard_and_timing.sh; do
  if ( cd "$VAULT" && bash "tests/acceptance/Chain_Consolidation_Planner_Context_Pack/$t" >"$TMP/o" 2>&1 ); then pass "Chain acceptance $t"; else fail "Chain acceptance $t: $(grep -m3 '^FAIL' "$TMP/o")"; fi
done
if ( cd "$VAULT" && THIN_ORCH_SKIP_SUITES=1 bash tests/test_thin_orchestrator.sh >"$TMP/o" 2>&1 ); then pass "vault test_thin_orchestrator.sh"; else fail "vault test_thin_orchestrator.sh: $(grep -m3 '^FAIL' "$TMP/o")"; fi
( cd "$VAULT" && CHAIN_SKIP_SUITES=1 bash tests/test_chain_consolidation.sh >"$TMP/o" 2>&1 )
! grep -q '^FAIL:' "$TMP/o" && grep -qF 'suites skipped: not a gateway pass' "$TMP/o" \
  && pass "vault test_chain_consolidation.sh own checks (skip mode)" || fail "test_chain_consolidation.sh skip mode: $(grep -m3 '^FAIL' "$TMP/o")"
finish

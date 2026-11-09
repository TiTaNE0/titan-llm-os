#!/usr/bin/env bash
# DoD 3 (slow, skipped by run_all.sh under ACC_SKIP_GATEWAY=1): the prior rubric suites stay
# green and the aggregate kit + vault suite runner exits 0.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
for s in tests/test_section_extent.sh tests/test_spec_gate_hardening.sh \
         tests/acceptance/Chain_Consolidation_Planner_Context_Pack/test_dod3_spec_rubric.sh \
         tests/test_chain_consolidation.sh; do
  ( cd "$VAULT" && bash "$s" >"$TMP/s.out" 2>&1 ) && pass "$s green" || fail "$s red: $(tail -5 "$TMP/s.out")"
done
finish

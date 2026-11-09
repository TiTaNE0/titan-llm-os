#!/usr/bin/env bash
# DoD 3 (light, always runs): both changed scripts parse under bash 3.2, lib_section has no
# regex interval braces (BSD awk), and every harness copying commit_task also copies
# lib_section.sh (commit_task now sources it). The suites themselves run in
# test_dod3_full_regression.sh, skipped under ACC_SKIP_GATEWAY=1.
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
cd "$VAULT"
/bin/bash -n .scripts/lib_section.sh && /bin/bash -n .scripts/commit_task.sh && pass "bash 3.2 parses both scripts" || fail "bash 3.2 syntax error"
grep -nE '\{[0-9]+(,[0-9]*)?\}' .scripts/lib_section.sh && fail "regex interval braces in lib_section" || pass "no interval braces"
grep -q 'source "\$SCRIPT_DIR/lib_section.sh"' .scripts/commit_task.sh && pass "commit_task sources lib_section" || fail "commit_task does not source lib_section"
for t in tests/test_commit_task.sh tests/acceptance_commit_task.sh tests/test_section_extent.sh; do
  grep -q 'lib_section' "$t" && pass "$t copies lib_section" || fail "$t does not copy lib_section"
done
grep -q 'sec_fence' tests/test_section_extent.sh && grep -q 'ct_fence_backtick' tests/test_section_extent.sh \
  && pass "gateway carries fence cases" || fail "gateway lacks fence cases"
finish

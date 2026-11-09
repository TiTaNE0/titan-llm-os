#!/usr/bin/env bash
# DoD4 (static): every aggregator skips the gateway's suite run via CMR_SKIP_SUITES; contracts unchanged.
. "$(dirname "$0")/_lib.sh"
for f in test_chain_consolidation test_chain_targeted_tests test_spec_gate_hardening test_pm_reviewer_single_pass test_macro_start_timestamp test_hook_argument_scope test_kit_telemetry_isolation; do
  n="$(grep -cF '[ "$b" = test_codemap_refresh.sh ] && envp="CMR_SKIP_SUITES=1"' "$VAULT/tests/$f.sh")"
  eq "$f wires CMR_SKIP_SUITES once" "$n" 1
done
grep -q 'CMR_SKIP_SUITES' "$VAULT/tests/test_codemap_refresh.sh" && pass "gateway honours CMR_SKIP_SUITES" || fail "gateway honours CMR_SKIP_SUITES"
git -C "$VAULT" diff --quiet HEAD -- .scripts/commit_task.sh && pass "commit_task.sh unchanged" || fail "commit_task.sh unchanged"
( cd "$KIT" && bash tests/test_no_inline_mutations.sh project-template/.claude/commands/close_task.md >/dev/null 2>&1 ) && pass "kit no-inline-mutations guard" || fail "kit no-inline-mutations guard"
# Step order: 4.5 < 4.6 < 5, and Step 4.5's fatality text unchanged (still HALT on non-zero).
o="$(grep -n '^## Step ' "$CT" | cut -d: -f2- | grep -E '^## Step (4\.5|4\.6|5) ' | cut -c1-12 | tr '\n' '|')"
eq "step order" "$o" "## Step 4.5 |## Step 4.6 |## Step 5 — |"
awk '/^## Step 4\.5/{f=1} /^## Step 4\.6/{f=0} f' "$CT" | grep -q 'HALT' && pass "Step 4.5 still fatal" || fail "Step 4.5 still fatal"
done_

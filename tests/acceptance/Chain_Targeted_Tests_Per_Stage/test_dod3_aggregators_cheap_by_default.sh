#!/usr/bin/env bash
# DoD 3 (behaviour): run the real suite loops of the three vault aggregators against a scratch
# repo of probe tests. The chain aggregator hands ACC_SKIP_GATEWAY=1 to every acceptance folder
# (its own folder excluded), and every aggregator runs this task's gateway only in its
# CTT_SKIP_SUITES=1 skip mode, so neither path recurses into a full suite run.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
R="$TMP/repo"; mkdir -p "$R/tests/acceptance"
probe() { printf '#!/usr/bin/env bash\necho "${%s:-unset}" > "%s"\nexit 0\n' "$2" "$1"; }

# extract <file> <start-regex>: the block from the loop header to its closing "  done".
extract() { awk -v re="$2" '$0 ~ re {on=1} on {print} on && /^  done$/ {exit}' "$1"; }
pass() { echo "ok: $1"; }

# --- chain aggregator acceptance loop -------------------------------------------
for d in Folder_A Folder_B Chain_Consolidation_Planner_Context_Pack; do
  mkdir -p "$R/tests/acceptance/$d"; probe "$TMP/acc_$d" ACC_SKIP_GATEWAY > "$R/tests/acceptance/$d/run_all.sh"
done
LOOP="$(extract "$VAULT/tests/test_chain_consolidation.sh" '^  for ra in ')"
[ -n "$LOOP" ] && pass "chain acceptance loop extracted" || fail "chain acceptance loop not found"
( REPO_ROOT="$R"; fail() { echo "FAIL: $1"; }; unset ACC_SKIP_GATEWAY; eval "$LOOP" ) >"$TMP/chain_acc.out" 2>&1
for d in Folder_A Folder_B; do expect "chain gives $d ACC_SKIP_GATEWAY" 1 "$(cat "$TMP/acc_$d" 2>/dev/null)"; done
[ ! -e "$TMP/acc_Chain_Consolidation_Planner_Context_Pack" ] && pass "chain still skips its own folder" || fail "chain ran its own acceptance folder"

# --- vault loops of all three aggregators ---------------------------------------
probe "$TMP/ctt_env" CTT_SKIP_SUITES > "$R/tests/test_chain_targeted_tests.sh"
printf '#!/usr/bin/env bash\necho "SKIP: suites"\necho "suites skipped: not a gateway pass"\nexit 1\n' > "$R/tests/test_chain_consolidation.sh"
for f in test_pm_reviewer_single_pass.sh test_kit_telemetry_isolation.sh test_thin_orchestrator.sh; do
  printf '#!/usr/bin/env bash\nexit 0\n' > "$R/tests/$f"
done
for agg in test_chain_consolidation.sh test_pm_reviewer_single_pass.sh test_kit_telemetry_isolation.sh; do
  rm -f "$TMP/ctt_env"
  LOOP="$(extract "$VAULT/tests/$agg" '^  for t in "\\$REPO_ROOT"/tests/test_\\*\\.sh ')"
  [ -n "$LOOP" ] || { fail "$agg vault loop not found"; continue; }
  ( REPO_ROOT="$R"; n=0; fail() { echo "FAIL: $1"; }; unset CTT_SKIP_SUITES; eval "$LOOP" ) >"$TMP/$agg.out" 2>&1
  expect "$agg runs this gateway with CTT_SKIP_SUITES=1" 1 "$(cat "$TMP/ctt_env" 2>/dev/null)"
  grep -q '^FAIL:' "$TMP/$agg.out" && fail "$agg loop reported: $(grep '^FAIL:' "$TMP/$agg.out" | tr '\n' ';')" || pass "$agg loop green on probes"
done
finish

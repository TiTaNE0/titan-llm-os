#!/usr/bin/env bash
# DoD 3: "kit and vault suites green" is enforced by the gateway's suite loop. Run a copy of the
# gateway in a scratch vault against stub suites: green only when every kit and vault suite passes,
# Chain_Consolidation counted in skip mode, no self-recursion, acceptance folders not run.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

mk_kit() {
  mkdir -p "$1/global/agents" "$1/docs/cld" "$1/project-template/.claude/commands" "$1/tests"
  cp "$PMR" "$1/global/agents/"; cp "$PMR_DOC" "$1/docs/cld/"; cp "$EXEC_MD" "$1/project-template/.claude/commands/"
}
mk_vault() {
  mkdir -p "$1/tests/acceptance/X"
  cp "$GATEWAY" "$1/tests/"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$1/tests/test_ok.sh"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$1/tests/smoke_ok.sh"
  printf '#!/usr/bin/env bash\n[ "${THIN_ORCH_SKIP_SUITES:-}" = 1 ] || exit 1\n' > "$1/tests/test_thin_orchestrator.sh"
  printf '#!/usr/bin/env bash\n[ "${CHAIN_SKIP_SUITES:-}" = 1 ] || { touch "%s/chain_full_run"; exit 0; }\necho "SKIP: suites"\necho "suites skipped: not a gateway pass"\nexit 1\n' "$1" > "$1/tests/test_chain_consolidation.sh"
  printf '#!/usr/bin/env bash\ntouch "%s/acceptance_ran"\n' "$1" > "$1/tests/acceptance/X/run_all.sh"
  printf '#!/usr/bin/env bash\necho "$PWD" > "%s/kit_cwd"; [ "${CLAUDE_BIN:-}" = __nonexistent__ ] || exit 1\n' "$1" > "$2/tests/test_kit_ok.sh"
}
gw() { ( cd "$1" && KIT_ROOT="$2" bash "$1/tests/test_pm_reviewer_single_pass.sh" >"$TMP/out" 2>&1 ); echo $?; }

V="$TMP/v1"; K="$TMP/k1"; mk_kit "$K"; mk_vault "$V" "$K"
expect "all suites green -> gateway exit 0" 0 "$(gw "$V" "$K")"
grep -qx 'ALL GREEN' "$TMP/out" && pass "ALL GREEN printed" || fail "ALL GREEN missing: $(grep '^FAIL' "$TMP/out")"
grep -qx 'PASS: kit test_kit_ok.sh' "$TMP/out" && pass "kit suite ran" || fail "kit suite did not run"
expect "kit suite runs from the kit root" "$(cd "$K" && pwd -P)" "$(cd "$(cat "$V/kit_cwd" 2>/dev/null || echo /nonexistent)" 2>/dev/null && pwd -P)"
for b in test_ok.sh smoke_ok.sh test_thin_orchestrator.sh; do
  grep -qx "PASS: vault $b" "$TMP/out" && pass "vault $b ran and passed" || fail "vault $b not reported as PASS"
done
grep -qx 'PASS: vault test_chain_consolidation.sh (skip mode)' "$TMP/out" && pass "Chain gateway counted green in skip mode" || fail "Chain gateway not counted in skip mode"
[ ! -f "$V/chain_full_run" ] && pass "Chain gateway never run in full (no recursion)" || fail "Chain gateway run in full"
[ ! -f "$V/acceptance_ran" ] && pass "acceptance folders not run" || fail "gateway ran an acceptance folder"
expect "gateway does not run itself" 0 "$(grep -c 'test_pm_reviewer_single_pass.sh' "$TMP/out")"

# A failing vault suite turns the gateway red.
V="$TMP/v2"; K="$TMP/k2"; mk_kit "$K"; mk_vault "$V" "$K"
printf '#!/usr/bin/env bash\nexit 1\n' > "$V/tests/test_broken.sh"
expect "failing vault suite -> exit 1" 1 "$(gw "$V" "$K")"
grep -qx 'FAIL: vault test_broken.sh' "$TMP/out" && pass "failing vault suite named" || fail "failing vault suite not named"

# A failing kit suite turns the gateway red.
V="$TMP/v3"; K="$TMP/k3"; mk_kit "$K"; mk_vault "$V" "$K"
printf '#!/usr/bin/env bash\nexit 1\n' > "$K/tests/test_kit_broken.sh"
expect "failing kit suite -> exit 1" 1 "$(gw "$V" "$K")"
grep -qx 'FAIL: kit test_kit_broken.sh' "$TMP/out" && pass "failing kit suite named" || fail "failing kit suite not named"

# Chain gateway with its own FAIL in skip mode is red.
V="$TMP/v4"; K="$TMP/k4"; mk_kit "$K"; mk_vault "$V" "$K"
printf '#!/usr/bin/env bash\necho "FAIL: something"\necho "suites skipped: not a gateway pass"\nexit 1\n' > "$V/tests/test_chain_consolidation.sh"
expect "Chain skip-mode FAIL -> exit 1" 1 "$(gw "$V" "$K")"

# Empty kit suite glob is red (a vacuous suite run is not green).
V="$TMP/v5"; K="$TMP/k5"; mk_kit "$K"; mk_vault "$V" "$K"; rm -f "$K"/tests/test_*.sh
expect "empty kit glob -> exit 1" 1 "$(gw "$V" "$K")"
grep -qF 'kit suite glob matched nothing' "$TMP/out" && pass "empty kit glob reported" || fail "empty kit glob not reported"
finish

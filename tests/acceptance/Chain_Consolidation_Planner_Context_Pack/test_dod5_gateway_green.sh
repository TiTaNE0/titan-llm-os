#!/usr/bin/env bash
# DoD 5: kit and vault suites green. Runs the Verification Gateway exactly as Step 13 does (from the
# vault root) and checks it ran every kit and vault suite; skipping suites can never pass.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
GW="$VAULT/tests/test_chain_consolidation.sh"
[ -f "$GW" ] || { fail "gateway script missing: $GW"; finish; }

rc=0; ( cd "$VAULT" && bash tests/test_chain_consolidation.sh ) >"$TMP/gw" 2>&1 || rc=$?
expect "gateway exit" 0 "$rc"
tail -n 1 "$TMP/gw" | grep -qx 'ALL GREEN' && pass "gateway ends ALL GREEN" || fail "gateway tail: $(tail -n 3 "$TMP/gw" | tr '\n' '|')"
grep -E '^FAIL' "$TMP/gw" >&2 && fail "gateway printed FAIL lines" || pass "no FAIL lines"

for t in "$KIT"/tests/test_*.sh; do
  n="$(basename "$t")"; grep -qx "PASS: kit $n" "$TMP/gw" && pass "kit suite $n ran green" || fail "kit suite $n not reported PASS"
done
for t in "$VAULT"/tests/test_*.sh "$VAULT"/tests/smoke_*.sh; do
  n="$(basename "$t")"; [ "$n" = test_chain_consolidation.sh ] && continue
  grep -qx "PASS: vault $n" "$TMP/gw" && pass "vault suite $n ran green" || fail "vault suite $n not reported PASS"
done
grep -qF 'not in suite glob: tests/acceptance_commit_task.sh, tests/acceptance/' "$TMP/gw" && pass "suite boundary printed" || fail "suite boundary line missing"

rc=0; ( cd "$VAULT" && CHAIN_SKIP_SUITES=1 bash tests/test_chain_consolidation.sh ) >"$TMP/gw_skip" 2>&1 || rc=$?
expect "CHAIN_SKIP_SUITES=1 forces failure" 1 "$rc"
grep -qF 'suites skipped: not a gateway pass' "$TMP/gw_skip" && pass "skip run states it is not a gateway pass" || fail "skip run message missing"
grep -qE '^PASS: (kit|vault) ' "$TMP/gw_skip" && fail "skip run still ran suites" || pass "skip run ran no suites"
finish

#!/usr/bin/env bash
# DoD 3: tests/smoke_spec_rubric.sh (the gateway) is green, contains a backticked-mention
# fixture and a bare-TBD fixture, and goes RED when run against the pre-fix rubric.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
build_vaults
SM="$VAULT/tests/smoke_spec_rubric.sh"
( cd "$VAULT" && bash tests/smoke_spec_rubric.sh >"$TMP/sm.out" 2>&1 ) && grep -q '^SMOKE: OK$' "$TMP/sm.out" \
  && pass "smoke green on working tree" || fail "smoke red: $(tail -3 "$TMP/sm.out")"
grep -qF '`### Open questions`' "$SM" && pass "smoke has a backticked marker mention fixture" || fail "no backticked mention fixture"
grep -qE "^mk_task .*'- TBD: " "$SM" && pass "smoke has a bare TBD item fixture" || fail "no bare TBD fixture"
# Smoke placed in a scratch vault whose .scripts is the pre-fix ref must fail.
mkdir -p "$R/tests"; cp "$SM" "$R/tests/"
( cd "$R" && bash tests/smoke_spec_rubric.sh >"$TMP/smr.out" 2>&1 ); rc=$?
[ "$rc" != 0 ] && pass "smoke fails against pre-fix rubric (rc=$rc)" || fail "smoke passes against pre-fix rubric"
grep -q '4d' "$TMP/smr.out" && pass "pre-fix failure is the mention case" || fail "pre-fix failure not at 4d: $(tail -2 "$TMP/smr.out")"
finish

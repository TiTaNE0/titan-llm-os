#!/usr/bin/env bash
# DoD 7: the updated rubric smoke regression stays green and pins the (b) message; the
# section-extent fixture and the kit bindings regression gained the new cases. (The slow
# section-extent and kit install suites are executed by test_dod7_full_gateway.sh.)
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
( cd "$VAULT" && bash tests/smoke_spec_rubric.sh >"$TMP/smoke.out" 2>&1 ) && pass "smoke_spec_rubric green" \
  || fail "smoke_spec_rubric red: $(tail -5 "$TMP/smoke.out")"
grep -q 'no file-change list' "$VAULT/tests/smoke_spec_rubric.sh" && pass "smoke asserts (b) message" \
  || fail "smoke does not assert the (b) message"
grep -qF -- '- [EDIT]' "$VAULT/tests/test_section_extent.sh" && pass "section_extent fixture carries a marked Files touched entry" \
  || fail "section_extent fixture lacks a [EDIT] entry"
grep -qF "spaces around" "$KIT/tests/test_install_opencode.sh" && pass "kit bindings regression covers spaces case" \
  || fail "kit test lacks spaces case"
finish

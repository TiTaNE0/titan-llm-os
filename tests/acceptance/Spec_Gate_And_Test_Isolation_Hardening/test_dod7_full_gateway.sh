#!/usr/bin/env bash
# DoD 7 (slow, skipped by run_all.sh under ACC_SKIP_GATEWAY=1): the vault and kit suites the
# task changed stay green, and the task's full Verification Gateway (suite loops + live
# telemetry window) exits 0.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
( cd "$VAULT" && bash tests/test_section_extent.sh >"$TMP/ext.out" 2>&1 ) && pass "test_section_extent green" \
  || fail "test_section_extent red: $(tail -5 "$TMP/ext.out")"
( cd "$KIT" && bash tests/test_install_opencode.sh >"$TMP/kit.out" 2>&1 ) && pass "kit test_install_opencode green" \
  || fail "kit test_install_opencode red: $(tail -5 "$TMP/kit.out")"
( cd "$VAULT" && bash tests/test_spec_gate_hardening.sh >"$TMP/gw.out" 2>&1 ) && pass "gateway exit 0" \
  || fail "gateway red: $(grep -E '^FAIL' "$TMP/gw.out" | head -10)"
finish

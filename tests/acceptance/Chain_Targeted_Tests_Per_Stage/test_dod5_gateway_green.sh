#!/usr/bin/env bash
# DoD 5 (full): the gateway with every kit and vault suite is green. This is a nested
# full-gateway run, so run_all.sh skips it under ACC_SKIP_GATEWAY=1 (the chain aggregator sets it).
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
( cd "$VAULT" && bash tests/test_chain_targeted_tests.sh >"$TMP/gw" 2>&1 ); rc=$?
expect "bash tests/test_chain_targeted_tests.sh exit code" 0 "$rc"
[ "$rc" -eq 0 ] || grep '^FAIL:' "$TMP/gw" >&2
finish

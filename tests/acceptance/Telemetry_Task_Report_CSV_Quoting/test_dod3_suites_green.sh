#!/usr/bin/env bash
# DoD 3: kit and vault suites green (gateway test always; full aggregator skippable).
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
bash "$REPO_ROOT/tests/test_telemetry_report_csv.sh" >"$TMP/gw.log" 2>&1 && grep -q '^ALL PASS$' "$TMP/gw.log" \
  && pass "gateway test_telemetry_report_csv.sh green" || { cat "$TMP/gw.log"; fail "gateway test"; }
if [ "${ACC_SKIP_GATEWAY:-0}" = 1 ]; then
  echo "SKIP full kit+vault aggregator (ACC_SKIP_GATEWAY=1)"
else
  bash "$REPO_ROOT/tests/test_chain_consolidation.sh" >"$TMP/agg.log" 2>&1 \
    && pass "kit+vault aggregator green" || { tail -40 "$TMP/agg.log"; fail "aggregator"; }
fi
finish

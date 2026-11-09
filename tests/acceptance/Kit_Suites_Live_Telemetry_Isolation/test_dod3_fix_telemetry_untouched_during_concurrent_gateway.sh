#!/usr/bin/env bash
# DoD 3 (and the gateway-result checks for DoD 1 and DoD 4): one full gateway run, with the
# Fix_Telemetry acceptance run (bounded, at most 2 times) while it is still running.
# Fix_Telemetry's "real telemetry untouched" check greps only its own sentinels, so DoD3
# proves non-interference, not leak detection; leak detection is the gateway's mirror pass,
# whose results are reused here (DoD1) instead of re-running every kit suite.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
( cd "$VAULT" && bash tests/test_kit_telemetry_isolation.sh >"$TMP/gw" 2>&1; echo $? >"$TMP/gw.rc" ) &
bg=$!
runs=0
while [ "$runs" -lt 2 ] && kill -0 "$bg" 2>/dev/null; do
  runs=$((runs + 1))
  out="$(bash "$FIXTEL_RUN_ALL" 2>&1)"; rc=$?
  if [ "$rc" = 0 ] && printf '%s\n' "$out" | grep -qx 'PASS DoD4 real telemetry untouched'; then pass "Fix_Telemetry run $runs during gateway"
  else fail "Fix_Telemetry run $runs during gateway: rc=$rc; $(printf '%s\n' "$out" | grep '^FAIL' | tr '\n' ';')"; fi
done
wait "$bg"
[ "$runs" -ge 1 ] && pass "Fix_Telemetry ran $runs time(s) while the gateway ran" || fail "gateway finished before any concurrent Fix_Telemetry run"

expect "gateway exit code" 0 "$(cat "$TMP/gw.rc")"
grep -qx 'ALL GREEN' "$TMP/gw" && pass "gateway ALL GREEN" || fail "gateway not green: $(grep '^FAIL' "$TMP/gw" | tr '\n' ';')"
grep -qx 'SKIP: suites' "$TMP/gw" && fail "gateway skipped suites" || pass "gateway did not skip suites"

# DoD1: every real kit suite appears in the gateway mirror pass with zero rows, none leaked.
nkit=0
for t in "$KIT"/tests/test_*.sh; do
  [ -f "$t" ] || continue; nkit=$((nkit + 1)); name="$(basename "$t")"
  grep -qF "PASS: kit $name wrote 0 rows to the vault default telemetry dir" "$TMP/gw" || fail "DoD1: no zero-row result for $name"
  grep -qF "PASS: kit green $name" "$TMP/gw" || fail "DoD4: $name not judged green"
done
[ "$nkit" -ge 1 ] && pass "$nkit kit suites checked against the gateway results" || fail "kit suite glob matched nothing"
grep -q '^FAIL: kit .* leaked' "$TMP/gw" && fail "gateway reports a leak" || pass "gateway reports no leak"
for name in $EMITTING; do
  grep -q "^PASS: kit $name emitted [0-9]* times" "$TMP/gw" && pass "positive control $name" || fail "positive control missing: $name"
done
grep -q '^PASS: vault ' "$TMP/gw" && pass "gateway ran vault suites" || fail "gateway ran no vault suite"
finish

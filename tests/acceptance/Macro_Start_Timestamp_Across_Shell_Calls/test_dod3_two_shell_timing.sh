#!/usr/bin/env bash
# DoD 3: (a) a start/emit pair in two separate shells, using the real vault scripts against a
# mktemp TELEMETRY_DIR, gives 0 < duration_ms < 3600000; (b) the gateway contains such a test and
# it discriminates: pointed at a scratch vault whose telemetry_start.sh records nothing, the
# gateway's two-shell check fails.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
TD="$TMP/td"
env -i PATH="$PATH" HOME="$HOME" TELEMETRY_DIR="$TD" bash -c '"$0" acc_mst_probe "ACC Task"' "$VAULT/.scripts/telemetry_start.sh"
sleep 1
env -i PATH="$PATH" HOME="$HOME" TELEMETRY_DIR="$TD" bash -c '"$0" acc_mst_probe success auto null Executioner "ACC Task"' "$VAULT/.scripts/emit_telemetry.sh" >/dev/null 2>&1
row="$(lastrow "$TD")"
printf '%s' "$row" | jq -e '.macro=="acc_mst_probe" and .task=="ACC Task" and .duration_ms > 0 and .duration_ms < 3600000' >/dev/null 2>&1 \
  && pass "two-shell duration $(printf '%s' "$row" | jq -r .duration_ms) ms" || fail "two-shell duration: $row"
cat "$VAULT"/04_Logs/Telemetry/*.jsonl 2>/dev/null | grep -q acc_mst_probe && fail "probe row leaked into live telemetry" || pass "live telemetry untouched"

# Gateway discrimination: scratch vault with the real gateway and a no-op telemetry_start.sh.
V="$TMP/v"; mkdir -p "$V/tests" "$V/.scripts"
cp "$GATEWAY" "$V/tests/"
cp "$VAULT/.scripts/emit_telemetry.sh" "$V/.scripts/"
printf '#!/usr/bin/env bash\nexit 0\n' > "$V/.scripts/telemetry_start.sh"; chmod +x "$V/.scripts/"*.sh
out="$(cd "$V" && MST_SKIP_SUITES=1 bash tests/test_macro_start_timestamp.sh 2>&1)"
printf '%s\n' "$out" | grep -q '^FAIL: two-shell start/emit duration' \
  && pass "gateway two-shell check fails when the start is not persisted" || fail "gateway two-shell check did not catch a no-op start"
out="$(cd "$VAULT" && MST_SKIP_SUITES=1 bash tests/test_macro_start_timestamp.sh 2>&1)"
printf '%s\n' "$out" | grep -q '^PASS: two-shell start/emit duration in (0, 3600000)' \
  && pass "gateway two-shell check passes on the real scripts" || fail "gateway two-shell check not green on real scripts"
finish

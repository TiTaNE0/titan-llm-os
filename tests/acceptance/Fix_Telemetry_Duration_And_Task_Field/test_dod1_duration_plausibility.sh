#!/usr/bin/env bash
# DoD 1: emit_telemetry.sh clamps any duration_ms that is not a plausible elapsed
# time (negative or > 24 h) — the row survives with duration 0, the clamp is logged,
# and the macro is never blocked.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

# A real elapsed time passes through untouched.
emit "${SENTINEL}_ok" success 4500 null Executioner T >/dev/null 2>&1
assert "plausible 4500 ms kept" sh -c "echo '$(last_row)' | jq -e '.duration_ms == 4500'"

# The original bug: epoch-ms (END - empty START) passed as a duration.
EPOCH_MS="$(( $(date +%s) * 1000 ))"
before="$(row_count)"
emit "${SENTINEL}_epoch" success "$EPOCH_MS" null Executioner T 2>"$TMP/err"; rc=$?
assert "epoch-ms call exits 0" test "$rc" -eq 0
assert "epoch-ms row still written" test "$(row_count)" -eq $((before + 1))
assert "epoch-ms clamped to 0" sh -c "echo '$(last_row)' | jq -e '.duration_ms == 0 and .macro == \"${SENTINEL}_epoch\"'"
assert "epoch-ms clamp logged with original value" grep -q "clamp-duration:$EPOCH_MS" "$FAILS"
assert "epoch-ms no stderr noise" test ! -s "$TMP/err"

# Boundaries of the 24 h window.
emit "${SENTINEL}_b0" success 0 >/dev/null 2>&1
assert "0 ms kept" sh -c "echo '$(last_row)' | jq -e '.duration_ms == 0'"
emit "${SENTINEL}_b24" success 86400000 >/dev/null 2>&1
assert "exactly 24 h kept" sh -c "echo '$(last_row)' | jq -e '.duration_ms == 86400000'"
emit "${SENTINEL}_b24p" success 86400001 >/dev/null 2>&1
assert "24 h + 1 ms clamped" sh -c "echo '$(last_row)' | jq -e '.duration_ms == 0'"
emit "${SENTINEL}_b9" success 100000000 >/dev/null 2>&1
assert "9-digit value clamped" sh -c "echo '$(last_row)' | jq -e '.duration_ms == 0'"

# Negative durations (e.g. clock skew) become 0 rather than vanishing.
before="$(row_count)"
emit "${SENTINEL}_neg" success -1500 >/dev/null 2>&1; rc=$?
assert "negative exits 0" test "$rc" -eq 0
assert "negative row written" test "$(row_count)" -eq $((before + 1))
assert "negative clamped to 0" sh -c "echo '$(last_row)' | jq -e '.duration_ms == 0'"
assert "negative clamp logged" grep -q -- "clamp-duration:-1500" "$FAILS"

# Huge digit strings do not trip bash arithmetic.
emit "${SENTINEL}_huge" success 99999999999999999999999999 >/dev/null 2>"$TMP/err"; rc=$?
assert "26-digit exits 0" test "$rc" -eq 0
assert "26-digit no stderr" test ! -s "$TMP/err"
assert "26-digit clamped" sh -c "echo '$(last_row)' | jq -e '.duration_ms == 0'"

# Leading zeros must not produce invalid JSON numbers or octal surprises.
emit "${SENTINEL}_lz" success 0089 >/dev/null 2>&1
assert "0089 normalised to 89" sh -c "echo '$(last_row)' | jq -e '.duration_ms == 89'"

# Garbage is still rejected (no corrupt row), and still exit 0.
before="$(row_count)"
emit "${SENTINEL}_bad" success 12ms >/dev/null 2>&1; rc=$?
assert "non-numeric exits 0" test "$rc" -eq 0
assert "non-numeric writes no row" test "$(row_count)" -eq "$before"
assert "non-numeric logged as reject" grep -q "reject.*non-numeric-duration:12ms" "$FAILS"

# Every row ever written in this run is valid JSON with an in-range integer duration.
assert "all rows valid + in range" sh -c "cat '$TDIR'/*.jsonl | jq -e -s 'all(.[]; (.duration_ms|type)==\"number\" and .duration_ms>=0 and .duration_ms<=86400000 and (.duration_ms|floor)==.duration_ms)'"

finish

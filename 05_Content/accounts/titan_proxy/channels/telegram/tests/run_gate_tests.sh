#!/usr/bin/env bash
# run_gate_tests.sh — Test suite for gate_telegram.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHANNEL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
GATE="$CHANNEL_DIR/bin/gate_telegram.sh"
FIXTURES="$SCRIPT_DIR/fixtures"

PASSED=0
FAILED=0

assert_pass() {
  local fixture="$1"
  local name
  name="$(basename "$fixture")"
  if "$GATE" "$fixture" > /dev/null 2>&1; then
    echo "✓ $name correctly passed"
    PASSED=$((PASSED + 1))
  else
    echo "✗ $name expected to pass, but failed" >&2
    "$GATE" "$fixture" >&2 || true
    FAILED=$((FAILED + 1))
  fi
}

assert_fail() {
  local fixture="$1"
  local expected_msg="$2"
  local name
  name="$(basename "$fixture")"
  output=$("$GATE" "$fixture" 2>&1 || true)
  if echo "$output" | grep -qi "$expected_msg"; then
    echo "✓ $name correctly failed with message containing '$expected_msg'"
    PASSED=$((PASSED + 1))
  else
    echo "✗ $name expected to fail with '$expected_msg', but output was:" >&2
    echo "$output" >&2
    FAILED=$((FAILED + 1))
  fi
}

echo "Running gate_telegram.sh test suite..."

assert_pass "$FIXTURES/valid_posts.json"
assert_pass "$FIXTURES/valid_offer_with_limitation.json"
assert_pass "$FIXTURES/valid_blockquote.json"
assert_pass "$FIXTURES/valid_holiday_window.json"
assert_pass "$FIXTURES/valid_news_connectivity.json"
assert_fail "$FIXTURES/fail_exclamation.json" "contains banned '!'"
assert_fail "$FIXTURES/fail_trigger_word.json" "prohibited regulatory trigger"
assert_fail "$FIXTURES/fail_infra_city.json" "prohibited infrastructure"
assert_fail "$FIXTURES/fail_banned_voice.json" "banned business_ru/brand term"
assert_fail "$FIXTURES/fail_technical_bs.json" "banned technical-BS"
assert_fail "$FIXTURES/fail_holiday_no_window.json" "requires both publish_from and publish_until"
assert_fail "$FIXTURES/fail_hardcoded_price.json" "hardcoded Star price"
assert_fail "$FIXTURES/fail_missing_limitation.json" "mandatory HARD_LIMITATION"
assert_fail "$FIXTURES/fail_bad_html.json" "unclosed HTML"
assert_fail "$FIXTURES/fail_too_long.json" "outside allowed standard range"
assert_fail "$FIXTURES/fail_missing_image.json" "image"
assert_fail "$FIXTURES/fail_news_beta_offtopic.json" "off-topic/beta"
assert_fail "$FIXTURES/fail_news_offtopic_no_domain.json" "lacks connectivity/Stars domain relevance"

echo "----------------------------------------"
echo "Results: $PASSED passed, $FAILED failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi

echo "All gate_telegram.sh tests passed."
exit 0

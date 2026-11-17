#!/usr/bin/env bash
# run_gate_tests.sh — Test suite for gate_article.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHANNEL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
GATE="$CHANNEL_DIR/bin/gate_article.sh"
FIXTURES="$SCRIPT_DIR/fixtures"

PASSED=0
FAILED=0

assert_pass() {
  local fixture="$1"
  local name="$(basename "$fixture")"
  if "$GATE" "$fixture" > /dev/null 2>&1; then
    echo "✓ $name correctly passed"
    PASSED=$((PASSED + 1))
  else
    echo "✗ $name expected to pass, but failed" >&2
    FAILED=$((FAILED + 1))
  fi
}

assert_fail() {
  local fixture="$1"
  local expected_msg="$2"
  local name="$(basename "$fixture")"
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

echo "Running gate_article.sh test suite..."

# 1. Valid fixture must pass
assert_pass "$FIXTURES/valid_article.md"

# 2. Exclamation mark must fail
assert_fail "$FIXTURES/fail_exclamation.md" "contains banned '!'"

# 3. Regulatory trigger word must fail
assert_fail "$FIXTURES/fail_trigger_word.md" "prohibited regulatory trigger"

# 4. Infrastructure city / provider leak must fail
assert_fail "$FIXTURES/fail_infra_city.md" "prohibited infrastructure"

# 5. Unverified markers must fail
assert_fail "$FIXTURES/fail_unverified_todo.md" "unverified marker"

# 6. HTML in frontmatter must fail
assert_fail "$FIXTURES/fail_frontmatter_html.md" "Frontmatter contains forbidden '<'"

echo "----------------------------------------"
echo "Results: $PASSED passed, $FAILED failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi

echo "All gate_article.sh tests passed."
exit 0

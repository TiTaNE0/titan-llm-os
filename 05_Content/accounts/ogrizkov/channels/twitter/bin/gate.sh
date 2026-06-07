#!/usr/bin/env bash
# gate.sh — deterministic code gate for @ogrizkov X reply drafts (PRD v2.1 Stage 3).
#
# Called IN-LOOP by the draft agent BEFORE it finalizes a reply — not as a
# post-write hook on a closed session. Contract: exit 0 = accept, exit 1 = rewrite.
# The retry loop lives in the agent's reasoning; this script is only the check.
#
# Usage:
#   gate.sh <draft_file>      # check a file
#   echo "draft" | gate.sh    # or pipe via stdin (defaults to /dev/stdin)
#
# Rules (from PRD v2.1 / drafting_contract code gate):
#   - word count must be 25..45 inclusive
#   - zero "!" characters
set -uo pipefail

MIN=25
MAX=45

file="${1:-/dev/stdin}"
draft="$(cat "$file")"

words=$(printf '%s' "$draft" | wc -w | tr -d ' ')

fail() { echo "GATE FAIL: $1 (words=$words)" >&2; exit 1; }

[ "$words" -ge "$MIN" ] || fail "word count below $MIN"
[ "$words" -le "$MAX" ] || fail "word count above $MAX"
case "$draft" in
  *"!"*) fail "contains banned '!'";;
esac

echo "GATE PASS: $words words, no '!'"
exit 0

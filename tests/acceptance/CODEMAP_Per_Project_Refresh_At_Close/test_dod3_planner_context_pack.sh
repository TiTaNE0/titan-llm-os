#!/usr/bin/env bash
# DoD3: the planner's Context pack lists CODEMAP.md as its first read when it exists.
. "$(dirname "$0")/_lib.sh"
CP="$(awk '/^### Context pack/{f=1} /^### Build split/{f=0} f' "$PL")"
[ -n "$CP" ] && pass "Context pack section found" || fail "Context pack section found"
printf '%s\n' "$CP" | grep -F -- '- Read: CODEMAP.md' | grep -qw first && pass "rule: first line is Read CODEMAP.md" || fail "rule: first line is Read CODEMAP.md"
printf '%s\n' "$CP" | grep -F 'CODEMAP.md' | grep -qi 'exists' && pass "rule is conditional on existence" || fail "rule is conditional on existence"
# The CODEMAP rule sits before the Contracts/Do-not-touch format bullets.
a="$(printf '%s\n' "$CP" | grep -n 'CODEMAP.md' | head -n1 | cut -d: -f1)"; b="$(printf '%s\n' "$CP" | grep -n -- '- `- Contracts:' | head -n1 | cut -d: -f1)"
[ -n "$a" ] && [ -n "$b" ] && [ "$a" -lt "$b" ] && pass "rule precedes Contracts bullet" || fail "rule precedes Contracts bullet"
grep -F 'What you do' -A12 "$PL" | grep -F 'CODEMAP.md' | grep -qi 'read it first' && pass "What-you-do reads CODEMAP first" || fail "What-you-do reads CODEMAP first"
done_

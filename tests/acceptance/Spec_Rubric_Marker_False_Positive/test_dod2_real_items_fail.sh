#!/usr/bin/env bash
# DoD 2: real unresolved items (bare TBD/TODO/FIXME/???, prose open question, or a
# non-empty open-questions list) still fail check (c), with the unchanged message.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
build_vaults
expect_c_fail "bare TBD bullet"       '- TBD: which retry policy applies?'
expect_c_fail "bare TODO mid-line"    'The writer path is a TODO for now.'
expect_c_fail "bare FIXME"            'FIXME the timeout is guessed.'
expect_c_fail "bare ???"              'Retry budget: ???'
expect_c_fail "prose open question"   'One open question is whether retries are bounded.'
expect_c_fail "token after a span, separated by a space (stripping is local)" \
  'See `.scripts/foo.sh` TBD before shipping.'
expect_c_fail "token between two spans" \
  'Edit `a.sh` and "b" TODO later.'
expect_c_fail "unmatched backtick leaves the rest scanned" \
  'Edit `a.sh then TBD decide.'
expect_c_fail "unmatched double quote leaves the rest scanned" \
  'He said "maybe TBD later.'
expect_c_fail "single-quoted mention is not exempt (conservative)" \
  "The gate says 'open questions remain' here."
expect_c_fail "item after a closed fence is scanned" \
  $'```\ncode\n```\n- TBD: pick a timeout'
# Non-empty open-questions list: no marker words, caught by (c2) with the (c) prefix.
f="$TMP/oq.md"
task "$f" $'Prose.\n### Open questions\n1. Which retry policy applies?'
rubric "$G" "$f"; expect "non-empty OQ list: exit" 3 "$RC"
case "$ERR" in "$MSG"*) pass "non-empty OQ list: (c) message prefix" ;; *) fail "non-empty OQ list: message [$ERR]" ;; esac
finish

#!/usr/bin/env bash
# DoD 2: an "### Open questions" subsection with anything other than None fails, including
# content with no marker words. stderr keeps the existing (c) message as its prefix.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
build_vaults
PFX="RUBRIC FAIL: open questions remain in spec"
run_case() { # <label> <oq-body> <red-expected-or-empty>
  local f="$TMP/oq.md"
  task "$f" "$PROSE$MAP$PACK$FILES"$'### Open questions\n'"$2"$'\n'
  rubric "$G" "$f"; expect "$1: GREEN exit" 3 "$RC"
  case "$ERR" in "$PFX"*) pass "$1: message prefix" ;; *) fail "$1: message [$ERR]" ;; esac
  [ -n "$3" ] && { rubric "$R" "$f"; expect "$1: RED (pre-fix) exit" "$3" "$RC"; }
  return 0
}
run_case numbered '1. Which file owns the retry path' 0
run_case none_prose 'None blocking.' 0
run_case bullet '- Ship behind a flag or not' 0
run_case none_then_content $'None.\n- But also the retry budget' 0
run_case none_explained 'None. The planner settled it.' 0
# Second OQ block (with a suffix) is checked too, even when the first is None.
f="$TMP/two.md"
task "$f" "$PROSE$MAP$PACK$FILES$OQ_NONE"$'### Risks\n- low\n### Open questions (for spec gate)\n- Pick a timeout\n'
rubric "$G" "$f"; expect "two_blocks: GREEN exit" 3 "$RC"
case "$ERR" in "$PFX"*) pass "two_blocks: message prefix" ;; *) fail "two_blocks: message [$ERR]" ;; esac
finish

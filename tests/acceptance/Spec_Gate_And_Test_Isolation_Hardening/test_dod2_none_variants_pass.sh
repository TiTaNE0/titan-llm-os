#!/usr/bin/env bash
# DoD 2: None in any case with an optional trailing period passes, as do surrounding blank
# lines and whitespace, a missing OQ subsection, and OQ-looking text inside a code fence.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
build_vaults
for b in 'None' 'None.' 'none' 'NONE.' 'nOnE' $'None.\n\n\n' $'\n  None.  \n'; do
  f="$TMP/none.md"
  task "$f" "$PROSE$MAP$PACK$FILES"$'### Open questions\n'"$b"$'\n'
  rubric "$G" "$f"; expect "OQ body [$(printf %s "$b" | tr '\n' '|')]: exit" 0 "$RC"
done
f="$TMP/absent.md"; task "$f" "$PROSE$MAP$PACK$FILES"
rubric "$G" "$f"; expect "no OQ subsection: exit" 0 "$RC"
f="$TMP/fence.md"
task "$f" "$PROSE$MAP$PACK$FILES$OQ_NONE"$'### Risks\n- low\n```\n### Open questions\n1. quoted example\n```\n'
rubric "$G" "$f"; expect "fenced OQ example after None.: exit" 0 "$RC"
finish

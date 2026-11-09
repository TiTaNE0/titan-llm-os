#!/usr/bin/env bash
# DoD 1: a Files touched heading at level 2, 3 or 4 holding any of [NEW]/[EDIT]/[DELETE] passes.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
build_vaults
for h in '##' '###' '####'; do
  for m in NEW EDIT DELETE; do
    f="$TMP/ok.md"
    task "$f" "$PROSE$MAP$PACK$h Files touched"$'\n'"- [$m] \`.scripts/foo.sh\`"$'\n'"$OQ_NONE"
    rubric "$G" "$f"; expect "'$h Files touched' with [$m]: exit" 0 "$RC"
  done
done
# Nested sub-heading inside a level-2 block keeps the block open.
f="$TMP/nested.md"
task "$f" "$PROSE$MAP$PACK"$'## Files touched\n### Vault\n- [NEW] tests/x.sh\n'"$OQ_NONE"
rubric "$G" "$f"; expect "level-2 block with nested ### entry: exit" 0 "$RC"
finish

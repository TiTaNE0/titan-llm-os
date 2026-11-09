#!/usr/bin/env bash
# DoD 1: the marker must sit inside a real Files touched block. A fenced heading does not
# open a block, a level-5 heading is out of range, and the block closes at the next
# same-level heading (a marker under ### Risks does not count).
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
build_vaults
f="$TMP/fenced.md"
task "$f" "$PROSE$MAP$PACK"$'```\n### Files touched\n- [EDIT] `.scripts/foo.sh`\n```\n'"$OQ_NONE"
rubric "$G" "$f"; expect "fenced heading: GREEN exit" 3 "$RC"
f="$TMP/lvl5.md"
task "$f" "$PROSE$MAP$PACK"$'##### Files touched\n- [EDIT] `.scripts/foo.sh`\n'"$OQ_NONE"
rubric "$G" "$f"; expect "level-5 heading: GREEN exit" 3 "$RC"
f="$TMP/closed.md"
task "$f" "$PROSE$MAP$PACK"$'### Files touched\n- foo\n### Risks\n- [EDIT] not a file entry\n'"$OQ_NONE"
rubric "$G" "$f"; expect "marker after block close: GREEN exit" 3 "$RC"
expect "marker after block close: message" "RUBRIC FAIL: no file-change list in spec" "$ERR"
finish

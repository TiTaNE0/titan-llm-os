#!/usr/bin/env bash
# DoD 1: a Files touched block whose entries carry no [NEW]/[EDIT]/[DELETE] marker fails.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
build_vaults
f="$TMP/nomark.md"
task "$f" "$PROSE$MAP$PACK"$'### Files touched\n- EDIT `.scripts/foo.sh`\n- NEW tests/x.sh\n'"$OQ_NONE"
rubric "$G" "$f"; expect "GREEN exit" 3 "$RC"
expect "GREEN message" "RUBRIC FAIL: no file-change list in spec" "$ERR"
rubric "$R" "$f"; expect "RED (pre-fix) exit" 0 "$RC"
finish

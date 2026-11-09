#!/usr/bin/env bash
# DoD 1: a spec with no "Files touched" block fails check (b), even though the template
# placeholder (containing /execute_task) and a prose path are present. RED (pre-fix) passed it.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
build_vaults
f="$TMP/nofiles.md"; task "$f" "$PROSE$MAP$PACK$OQ_NONE"
grep -q '/execute_task' "$f" || fail "fixture lacks placeholder text"
rubric "$G" "$f"; expect "GREEN exit" 3 "$RC"
expect "GREEN exact message" "RUBRIC FAIL: no file-change list in spec" "$ERR"
rubric "$R" "$f"; expect "RED (pre-fix) exit" 0 "$RC"
finish

#!/usr/bin/env bash
# DoD 3: spec_rubric.sh requires a non-empty Responsibility map and a Context pack block with a
# "- Read:" line inside it. Specs are persisted through the real write_task_section path in a temp vault.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
V="$TMP/v"; mk_vault "$V"

SUMMARY=$'### Summary\nChange .scripts/foo.sh to add a flag.'
MAP=$'### Responsibility map\n- Flag parsing: `.scripts/foo.sh` (current owner).'
PACK=$'### Context pack\n- Read: .scripts/foo.sh:1-20 - argument loop\n- Contracts: exit codes unchanged\n- Do not touch: 03_Brain/'
FILES=$'### Files touched\n- [EDIT] `.scripts/foo.sh`'
OQ=$'### Open questions\nNone.'

# rubric <label> <spec-text>: persist spec, run rubric; sets RC and ERR.
N=0
rubric() {
  N=$((N + 1)); local t="$TMP/case$N.md"
  mk_task "$t"; printf '%s\n' "$2" > "$TMP/case$N.spec"
  write_spec "$V" "$t" "$TMP/case$N.spec" || { RC=99; ERR="write failed"; return; }
  RC=0; ERR="$("$V/.scripts/spec_rubric.sh" --task-path "$t" 2>&1 >/dev/null)" || RC=$?
}
want_rc() { # <label> <rc> <stderr> <spec>
  rubric "$1" "$4"
  [ "$RC" = "$2" ] && [ "$ERR" = "$3" ] && pass "$1 -> exit $2" || fail "$1: expected exit $2 [$3], got exit $RC [$ERR]"
}
MAPMSG="RUBRIC FAIL: no Responsibility map in spec"
PACKMSG="RUBRIC FAIL: no context pack in spec"

want_rc "full spec"                   0 "" "$SUMMARY"$'\n'"$MAP"$'\n'"$PACK"$'\n'"$FILES"$'\n'"$OQ"
want_rc "map + pack as last block"    0 "" "$SUMMARY"$'\n'"$FILES"$'\n'"$MAP"$'\n'"$PACK"
want_rc "'* Read:' bullet accepted"   0 "" "$SUMMARY"$'\n'"$MAP"$'\n### Context pack\n* Read: .scripts/foo.sh:1-5 - x\n'"$FILES"
want_rc "missing Responsibility map"  3 "$MAPMSG" "$SUMMARY"$'\n'"$PACK"$'\n'"$FILES"$'\n'"$OQ"
want_rc "empty Responsibility map (next heading follows)" 3 "$MAPMSG" "$SUMMARY"$'\n### Responsibility map\n'"$PACK"$'\n'"$FILES"
want_rc "blank-only Responsibility map" 3 "$MAPMSG" "$SUMMARY"$'\n### Responsibility map\n\n   \n'"$PACK"$'\n'"$FILES"
want_rc "Responsibility map in prose only (no heading)" 3 "$MAPMSG" "$SUMMARY"$'\nThe Responsibility map is below.\n'"$PACK"$'\n'"$FILES"
want_rc "missing Context pack"        3 "$PACKMSG" "$SUMMARY"$'\n'"$MAP"$'\n'"$FILES"$'\n'"$OQ"
want_rc "empty Context pack block"    3 "$PACKMSG" "$SUMMARY"$'\n'"$MAP"$'\n### Context pack\n'"$FILES"$'\n'"$OQ"
want_rc "Context pack without Read line" 3 "$PACKMSG" "$SUMMARY"$'\n'"$MAP"$'\n### Context pack\n- Contracts: none\n'"$FILES"
want_rc "Read line before the Context pack block" 3 "$PACKMSG" "$SUMMARY"$'\n- Read: .scripts/foo.sh:1-5 - x\n'"$MAP"$'\n### Context pack\n- Contracts: none\n'"$FILES"
want_rc "Read line after the Context pack block" 3 "$PACKMSG" "$SUMMARY"$'\n'"$MAP"$'\n### Context pack\n- Contracts: none\n'"$FILES"$'\n- Read: .scripts/foo.sh:1-5 - x'
want_rc "Read line under a sub-heading inside the pack" 3 "$PACKMSG" "$SUMMARY"$'\n'"$MAP"$'\n### Context pack\n#### Reads\n- Read: .scripts/foo.sh:1-5 - x\n'"$FILES"

# Existing checks keep precedence and exit codes: (c) fires before (d)/(e); E2 unchanged.
want_rc "open-question marker precedes map check" 3 "RUBRIC FAIL: open questions remain in spec" "$SUMMARY"$'\nDecision is TBD here.\n'"$FILES"
t="$TMP/empty.md"; mk_task "$t"; rc=0; "$V/.scripts/spec_rubric.sh" --task-path "$t" >/dev/null 2>&1 || rc=$?
expect "empty spec still exit 3" 3 "$rc"
rc=0; "$V/.scripts/spec_rubric.sh" --task-path "$TMP/nope.md" >/dev/null 2>&1 || rc=$?
expect "missing task file still exit 2" 2 "$rc"

# Large specs (~240 KB of body after the blocks) on the real script: exit codes stay 0/2/3, no
# SIGPIPE abort (141), and the right message for each failure. TMPDIR is private so leftovers show.
BIG="$(awk 'BEGIN{for(i=0;i<4000;i++) print "- detail line " i " padding padding padding padding"}')"
export TMPDIR="$TMP/rubric_tmp"; mkdir -p "$TMPDIR"
want_rc "large spec passes" 0 "" "$SUMMARY"$'\n'"$MAP"$'\n'"$PACK"$'\n### Details\n'"$BIG"$'\n'"$FILES"
want_rc "large spec, file list only at the very end" 0 "" $'### Summary\nChange things.\n'"$MAP"$'\n'"$PACK"$'\n### Details\n'"$BIG"$'\n'"$FILES"
want_rc "large spec without Responsibility map" 3 "$MAPMSG" "$SUMMARY"$'\n'"$PACK"$'\n### Details\n'"$BIG"$'\n'"$FILES"
want_rc "large spec, empty map then big block" 3 "$MAPMSG" "$SUMMARY"$'\n### Responsibility map\n### Details\n'"$BIG"$'\n'"$PACK"
want_rc "large spec, Read line only after the pack block" 3 "$PACKMSG" "$SUMMARY"$'\n'"$MAP"$'\n### Context pack\n- Contracts: x\n### Details\n'"$BIG"$'\n- Read: .scripts/foo.sh:1-5 - x'
want_rc "large spec, open-question marker at the very end" 3 "RUBRIC FAIL: open questions remain in spec" "$SUMMARY"$'\n'"$MAP"$'\n'"$PACK"$'\n### Details\n'"$BIG"$'\nThis is TBD later.'
want_rc "large spec, no file list anywhere" 3 "RUBRIC FAIL: no file-change list in spec" $'### Summary\nChange things.\n### Responsibility map\n- owner: none\n### Context pack\n- Read: x\n### Details\n'"$(printf '%s\n' "$BIG" | sed 's/padding/pad/g')"
expect "rubric leaves no temp files behind" "" "$(ls -A "$TMPDIR")"
unset TMPDIR

# The real rubric check is load-bearing: stripping (d)/(e) makes the map-less spec pass.
cp "$V/.scripts/spec_rubric.sh" "$TMP/rubric_orig.sh"
awk '/^# \(d\) Responsibility map heading/{skip=1} /^echo "RUBRIC: PASS"/{skip=0} !skip' "$TMP/rubric_orig.sh" > "$V/.scripts/spec_rubric.sh"
rubric "red_no_map" "$SUMMARY"$'\n'"$FILES"
expect "RED: rubric without (d)/(e) accepts map-less spec" 0 "$RC"
cp "$TMP/rubric_orig.sh" "$V/.scripts/spec_rubric.sh"
rubric "green_no_map" "$SUMMARY"$'\n'"$FILES"
expect "GREEN: real rubric rejects the same spec" 3 "$RC"
finish

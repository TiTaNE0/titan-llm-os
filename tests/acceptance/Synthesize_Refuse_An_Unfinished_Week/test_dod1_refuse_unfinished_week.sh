#!/usr/bin/env bash
# DoD 1: plan exits 3 with a "not finished" stderr line and writes nothing when the week's Sunday >= Israel today.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
SB="$TMP/sb"; mk_sandbox "$SB"; before="$(manifest "$SB")"
plan "$SB" --week 2026-W48 --today 2026-11-27
eq "current week (Friday) exits 3" "$RC" 3
eq "current week: exact stderr" "$ERR" "E3: week 2026-W48 is not finished: its Sunday 2026-11-29 is on or after today 2026-11-27 (Asia/Jerusalem)"
eq "current week: stdout empty" "$OUT" ""
plan "$SB" --week 2026-W48 --today 2026-11-29
eq "boundary: today is the Sunday exits 3" "$RC" 3
case "$ERR" in *"is not finished"*) pass "boundary: stderr names not finished";; *) fail "boundary stderr: $ERR";; esac
plan "$SB" --week 2026-W48 --today 2026-11-23
eq "Monday of the same week exits 3" "$RC" 3
plan "$SB" --week 2026-W53 --today 2026-11-27
eq "future week exits 3" "$RC" 3
case "$ERR" in *"week 2026-W53 is not finished"*) pass "future: stderr names the week";; *) fail "future stderr: $ERR";; esac
plan "$SB" --week 2099-W01
eq "default Israel date: far-future week exits 3" "$RC" 3
case "$ERR" in *"is not finished"*) pass "default date: stderr names not finished";; *) fail "default date stderr: $ERR";; esac
eq "refusals write nothing (manifest identical)" "$(manifest "$SB")" "$before"
eq "Weekly_Synthesis still only facts.jsonl" "$(ls "$SB/03_Brain/Weekly_Synthesis")" "facts.jsonl"
# Refusal is input validation: it wins over exit 6 and over E1.
touch "$SB/03_Brain/Weekly_Synthesis/2026-W48.synthesis.md" "$SB/03_Brain/Weekly_Synthesis/2026-W48.synthesis.json"
plan "$SB" --week 2026-W48 --today 2026-11-27; eq "unfinished + already outputs: still exit 3" "$RC" 3
plan "$SB" --week 2026-W48 --today 2026-11-30; eq "same week finished + outputs: exit 6 unchanged" "$RC" 6
rm "$SB/03_Brain/Weekly_Synthesis/2026-W48."*
rm "$SB/03_Brain/Weekly_Synthesis/facts.jsonl"
plan "$SB" --week 2026-W48 --today 2026-11-27; eq "unfinished + missing facts.jsonl: exit 3 not 1" "$RC" 3
plan "$SB" --week 2026-W48 --today 2026-11-30; eq "finished + missing facts.jsonl: exit 1 unchanged" "$RC" 1
finish

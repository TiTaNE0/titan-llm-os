#!/usr/bin/env bash
# DoD 2: plan still exits 0 for finished weeks; existing exits 6/1/3 and --today validation behave.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
SB="$TMP/sb"; mk_sandbox "$SB"
plan "$SB" --week 2026-W48 --today 2026-11-30
eq "day after Sunday: exit 0" "$RC" 0
echo "$OUT" | grep -qx 'week=2026-W48' && echo "$OUT" | grep -qx 'sunday=2026-11-29' && pass "stdout has week= and sunday=" || fail "stdout: $OUT"
echo "$OUT" | grep -qx 'logs=3' && pass "W48 logs=3 (Mon+Fri+Sat)" || fail "W48 logs: $OUT"
plan "$SB" --week 2026-W47 --today 2026-11-23
eq "W47 on 2026-11-23: exit 0" "$RC" 0
echo "$OUT" | grep -qx 'logs=2' && pass "W47 logs=2" || fail "W47 logs: $OUT"
for k in week monday sunday log logs out_md out_json facts; do echo "$OUT" | grep -q "^$k=" && pass "stdout key $k" || fail "stdout key $k missing"; done
plan "$SB" --week 2025-W53 --today 2027-01-01; eq "nonexistent week still exit 3" "$RC" 3
plan "$SB" --week 2026-47 --today 2027-01-01;  eq "malformed week still exit 3" "$RC" 3
plan "$SB" --week 2026-W47 --today 2026-13-01; eq "impossible --today exit 3" "$RC" 3
case "$ERR" in *"impossible --today '2026-13-01'"*) pass "impossible --today message";; *) fail "msg: $ERR";; esac
plan "$SB" --week 2026-W47 --today nope; eq "malformed --today exit 3" "$RC" 3
case "$ERR" in *"malformed --today 'nope'"*) pass "malformed --today message";; *) fail "msg: $ERR";; esac
plan "$SB" --week 2026-W47 --today; eq "--today without value exit 3" "$RC" 3
case "$ERR" in *"--today needs a value"*) pass "missing value message";; *) fail "msg: $ERR";; esac
# stale .next on a finished week still exit 3 with its own text
cp "$SB/03_Brain/Weekly_Synthesis/facts.jsonl" "$SB/03_Brain/Weekly_Synthesis/facts.jsonl.next"
plan "$SB" --week 2026-W47 --today 2026-11-30; eq "finished + stale .next: exit 3" "$RC" 3
case "$ERR" in *"unresolved facts.jsonl.next"*) pass "stale .next text unchanged";; *) fail "msg: $ERR";; esac
rm "$SB/03_Brain/Weekly_Synthesis/facts.jsonl.next"
touch "$SB/03_Brain/Weekly_Synthesis/2026-W47.synthesis.md"
plan "$SB" --week 2026-W47 --today 2026-11-30; eq "finished + exactly one output: exit 3" "$RC" 3
touch "$SB/03_Brain/Weekly_Synthesis/2026-W47.synthesis.json"
plan "$SB" --week 2026-W47 --today 2026-11-30; eq "finished + both outputs: exit 6" "$RC" 6
echo "$OUT" | grep -q 'status=already_synthesized' && pass "exit 6 prints already_synthesized" || fail "exit 6 stdout: $OUT"
# week subcommand is the interactive default and never hits the refusal
for t in 2026-11-27 2026-11-29 2026-11-30 2027-01-04; do
  w="$(cd "$SB" && ./.vault_link/.scripts/synthesize_run.sh week --today $t)"
  plan "$SB" --week "$w" --today "$t"; case "$RC" in 0|6) pass "week($t)=$w accepted by plan";; *) fail "week($t)=$w plan rc=$RC";; esac
done
finish

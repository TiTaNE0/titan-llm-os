#!/usr/bin/env bash
# DoD 2 / Spec Summary property: span replacement never joins text into a new match, so the
# set of lines failing (c) can only shrink versus the pre-fix script.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
build_vaults
for c in 'word `x`TODO more' '?`x`??' 'a "x"TBD b' '??"q"?' 'x`a`?`b`?? y' 'FIX`m`ME' 'open`x` question'; do
  f="$TMP/nj.md"; task "$f" "$c"
  rubric "$G" "$f"; expect "no-join [$c]: GREEN passes" 0 "$RC"
done
# Pseudo-random fuzz: every line GREEN fails (c) on must also fail on RED.
RANDOM=7
atoms=('`' '"' ' ' '?' '??' 'TBD' 'TODO' 'FIXME' 'open' 'question' 'x' '`x`' '"q"' '|' ' TBD')
n=0; bad=0
while [ $n -lt 80 ]; do
  line="w"; k=0
  while [ $k -lt 6 ]; do line="$line${atoms[$((RANDOM % ${#atoms[@]}))]}"; k=$((k+1)); done
  f="$TMP/fz.md"; task "$f" "$line"
  rubric "$G" "$f"; g=$RC
  rubric "$R" "$f"; r=$RC
  if [ "$g" != 0 ] && [ "$r" = 0 ]; then fail "new failure on [$line]: GREEN=$g RED=$r"; bad=1; fi
  n=$((n+1))
done
[ $bad = 0 ] && pass "fuzz: 80 lines, no GREEN-only failures"
finish

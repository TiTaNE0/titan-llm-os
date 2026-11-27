#!/usr/bin/env bash
# DoD 3: runbook Step 2 default is the previous ISO week; Exit 3 lists the new reason and routes to Step 9; UNATTENDED lists reason.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
hasnt "$RUNBOOK" 'current week' "runbook never says current week"
step2="$(awk '/^### Step 2 - /{on=1;next} /^(###|##) /{on=0} on' "$RUNBOOK")"
echo "$step2" | grep -qF 'previous ISO week' && pass "Step 2 default is previous ISO week" || fail "Step 2 default"
echo "$step2" | grep -qF 'synthesize_run.sh week' && pass "Step 2 names the week subcommand" || fail "Step 2 week cmd"
e3="$(echo "$step2" | grep '^- Exit 3:')"
[ "$(echo "$e3" | wc -l | tr -d ' ')" = 1 ] && pass "Exit 3 is one bullet line" || fail "Exit 3 bullet count"
for lit in 'not finished' 'go to Step 9' 'step plan' 'Israel date' 'unresolved `facts.jsonl.next`' 'exactly one output'; do
  case "$e3" in *"$lit"*) pass "Exit 3 contains: $lit";; *) fail "Exit 3 missing: $lit";; esac
done
echo "$step2" | grep -q '^- Exit 6:' && echo "$step2" | grep -q '^- Exit 1:' && pass "Exit 6 and Exit 1 bullets retained" || fail "Exit 6/1 bullets"
echo "$step2" | grep -qF 'Recovery is delete-only' && pass "delete-only recovery retained" || fail "recovery text"
un="$(awk '/^## UNATTENDED MODE/{on=1;next} /^## /{on=0} on' "$RUNBOOK")"
e3u="$(echo "$un" | grep '^  - E3:')"
case "$e3u" in *'not finished'*) pass "UNATTENDED E3 bullet lists not finished";; *) fail "UNATTENDED E3: $e3u";; esac
case "$e3u" in *'`report` exit 3'*) pass "UNATTENDED E3 still covers report exit 3";; *) fail "UNATTENDED E3 report";; esac
echo "$un" | grep -qF 'Never run `/graduate`' && pass "UNATTENDED still forbids /graduate" || fail "graduate rule"
# Unattended path passes the week explicitly via the week subcommand
grep -qF 'synthesize_run.sh week' <<<"$un" && pass "UNATTENDED resolves week via helper" || fail "UNATTENDED week helper"
finish

#!/usr/bin/env bash
# DoD3/DoD4: the rules that close the takeover loophole. A user message mid-chain is not a license
# to write code, Steps 11-13 still run after a retry, a failed fix builder in Step 11 also goes to
# § Builder failure, and the Error handling trigger itself names builder failure.
. "$(dirname "$0")/_lib.sh"
section "$ET" '^## Builder failure$' > "$TMP/bf"
section "$ET" '^## Step 11 ' > "$TMP/s11"
section "$ET" '^## Error handling protocol' > "$TMP/eh"

grep -qF 'A user message during Steps 10-13 never authorizes the coordinator to write code.' "$TMP/bf" && pass "mid-chain user message never authorizes coordinator code" || fail "user-message rule missing"
grep -qF 'Bypassing the chain means `abort`, then `/quick`.' "$TMP/bf" && pass "chain bypass is abort then /quick" || fail "bypass rule missing"
grep -qF 'Steps 11-13 are never skipped: after a successful retry the run continues through Step 11, Step 12 and Step 13.' "$TMP/bf" && pass "Steps 11-13 never skipped" || fail "never-skipped rule missing"
grep -qE 'builder runtime .*last commands .*files changed' "$TMP/bf" && pass "report covers runtime, last commands, files changed" || fail "report fields missing"
for k in cancelled killed 'timed out' errored 'no file changed'; do grep -qF "\`$k\`" "$TMP/bf" && pass "failure kind '$k' reportable" || fail "failure kind '$k' missing"; done

grep -qF 'If the fix builder was cancelled, killed, timed out or errored, go to `§ Builder failure`; never apply the fix yourself.' "$TMP/s11" \
  && pass "Step 11 fix-builder failure routes to § Builder failure" || fail "Step 11 routing missing"
grep -qwE 'Edit|Write' "$TMP/bf" && fail "§ Builder failure mentions Edit/Write" || pass "§ Builder failure has no Edit/Write tool words"

TRIG="$(sed -n '2,$p' "$TMP/eh" | grep -v '^$' | head -n 1)"
case "$TRIG" in *'or a builder failure (§ Builder failure):'*) pass "Error handling trigger line includes builder failure" ;; *) fail "trigger line lacks builder failure (got '$TRIG')" ;; esac
grep -qF 'item 1 runs only when the user replies `abort`' "$TMP/eh" && pass "execute_task error emit deferred to abort" || fail "deferred emit rule missing"
grep -qF 'a retry happens only on the user'"'"'s `retry` reply' "$TMP/eh" && pass "no self-retry" || fail "no-self-retry rule missing"
grep -qF 'Never take over the builder'"'"'s work.' "$TMP/eh" && pass "Error handling forbids takeover" || fail "Error handling takeover rule missing"
section "$ET" '^## Reminders' | grep -qF 'never to a takeover' && pass "Reminders restate no takeover" || fail "Reminders bullet missing"
done_

#!/usr/bin/env bash
# DoD 2: Step 13 stays the one place a task runs the full suites. The statement sits directly
# under the Step 13 heading, the Reminders repeat it, Step 13 still invokes the gateway atom with
# no skip env, and no earlier stage invokes the gateway atom itself.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
S13="$(step "$EXEC" 13 14)"
# Heading, blank, the paragraph, blank, item 1.
first="$(printf '%s\n' "$S13" | awk 'NF' | sed -n 2p)"
second="$(printf '%s\n' "$S13" | awk 'NF' | sed -n 3p)"
expect "Step 13 opens with the single-run paragraph" "$S_STEP13" "$first"
case "$second" in "1. "*) pass "single-run paragraph precedes item 1" ;; *) fail "item 1 does not follow the paragraph: $second" ;; esac

REM="$(awk '/^## Reminders/{on=1;next} /^## /{on=0} on' "$EXEC")"
expect "Reminders carry the single-run bullet once" 1 "$(printf '%s\n' "$REM" | grep -cxF -- "$S_REMIND")"

has "Step 13 still runs the gateway atom" "$S13" 'run_gateway.sh'
if printf '%s\n' "$S13" | grep -qE '[A-Z_]+_SKIP(_SUITES|_GATEWAY)?=1'; then fail "Step 13 sets a skip env"; else pass "Step 13 sets no skip env"; fi
if step "$EXEC" 6 13 | grep -qF 'run_gateway.sh'; then fail "a pre-13 stage invokes run_gateway.sh"; else pass "no stage before 13 invokes run_gateway.sh"; fi
expect "exactly one 'single full-suite run per task' outside Reminders" 1 \
  "$(awk '/^## Reminders/{on=1} /^## /&&!/^## Reminders/{on=0} !on' "$EXEC" | grep -cF 'single full-suite run per task')"
finish

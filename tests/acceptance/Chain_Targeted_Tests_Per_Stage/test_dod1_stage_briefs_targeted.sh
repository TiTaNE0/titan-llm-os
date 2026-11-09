#!/usr/bin/env bash
# DoD 1 (execute_task.md): every agent the orchestrator spawns in Steps 10-12 is told, inside its
# italic brief and right after the degradation sentence, to run only targeted tests and not the
# full kit/vault suite loops. Includes the Step 11 fix-builder respawn.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
ABS='If absent, proceed with standard typecheck/lint/test.'
S10="$(step "$EXEC" 10 11)"; S11="$(step "$EXEC" 11 12)"; S12="$(step "$EXEC" 12 13)"

# brief_ok <label> <line> <sentence> <must-follow-with>: sentence sits right after ABS, inside the quote.
brief_ok() {
  if [[ "$2" == *"$ABS $3$4"* ]]; then pass "$1 targeted sentence follows degradation sentence"
  else fail "$1 targeted sentence not directly after '$ABS' (or wrong tail)"; fi
}
L_B="$(line_with "$S10" 'spawn `builder`. Brief:')"
L_BE="$(line_with "$S10" 'Spawn `backend-builder`. Brief:')"
L_FE="$(line_with "$S10" 'Spawn `frontend-builder`. Brief:')"
expect "Step 10 single-builder brief found once" 1 "$(printf '%s\n' "$L_B" | grep -c .)"
brief_ok "Step 10 builder" "$L_B" "$S_BUILDER" ' In your final report, list the exact files you changed."*'
brief_ok "Step 10 backend-builder" "$L_BE" "$S_BUILDER" ' In your final report, list the exact files you changed."*'
brief_ok "Step 10 frontend-builder" "$L_FE" "$S_BUILDER" '"*'

L_TV="$(line_with "$S11" 'Spawn `test-verifier` subagent. Brief:')"
brief_ok "Step 11 test-verifier" "$L_TV" "$S_TV" " $S_NESTED"'"*'
L_FIX="$(line_with "$S11" 'Spawn `builder` with the bug list')"
has "Step 11 fix-builder spawn phrase unchanged" "$L_FIX" 'Spawn `builder` with the bug list (under a split, the builder(s) owning the failing files).'
has "Step 11 fix-builder brief carries targeted rule" "$L_FIX" 'Its brief carries the same Run only targeted tests sentence as Step 10.'

L_VAL="$(line_with "$S12" 'Return at most 3 lines: line 1 `VERDICT:')"
brief_ok "Step 12 validator" "$L_VAL" "$S_VAL" '"*'

# A stage brief that still says to run "the full test suite" would contradict the rule.
hasnt "Steps 10-12 never ask for the full test suite" "$S10$S11$S12" 'full test suite'
# The degradation sentence is still present in all five briefs (kit pins rely on it).
expect "degradation sentence count in Steps 10-12" 5 "$(printf '%s\n%s\n%s\n' "$S10" "$S11" "$S12" | grep -cF "$ABS")"
finish

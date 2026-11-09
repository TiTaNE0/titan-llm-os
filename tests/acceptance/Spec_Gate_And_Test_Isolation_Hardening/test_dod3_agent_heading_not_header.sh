#!/usr/bin/env bash
# DoD 3: an agent heading "## Spec: Validator Report" inside the Spec is never taken as the
# Validator Report header; the real (empty) "## ✅ Validator Report" is. RED mis-matched it.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
build_vaults
f="$TMP/agent.md"
task "$f" "$PROSE$MAP$PACK$FILES$OQ_NONE"$'## Spec: Validator Report\nSHIP. No issues found.\n'
expect "GREEN empty" 0 "$(gsec "$G" "$f" "Validator Report" empty)"
expect "GREEN populated" 1 "$(gsec "$G" "$f" "Validator Report" populated)"
expect "RED (pre-fix) empty" 1 "$(gsec "$R" "$f" "Validator Report" empty)"
# Any alphanumeric leading token is no longer stripped.
for tok in 'Spec:' 'Task:' '1.' 'v2'; do
  g="$TMP/only.md"
  printf '# T\n\n## %s Validator Report\nbody\n' "$tok" > "$g"
  expect "'## $tok Validator Report' alone: header not found" 3 "$(gsec "$G" "$g" "Validator Report" present)"
done
# Two-token prefix inside the Spec also never matches.
f="$TMP/two.md"
task "$f" "$PROSE$MAP$PACK$FILES$OQ_NONE"$'## ⚡ Task: Validator Report\nSHIP.\n'
expect "GREEN two-token prefix: empty" 0 "$(gsec "$G" "$f" "Validator Report" empty)"
# The rubric (which locates Spec via grep_section) still passes on the agent-heading task.
f="$TMP/agent.md"; rubric "$G" "$f"; expect "rubric on agent-heading task" 0 "$RC"
finish

#!/usr/bin/env bash
# Runs every Spec_Rubric_Marker_False_Positive acceptance test, then proves the task file and
# the scripts under test were not written.
# ACC_SKIP_GATEWAY=1 skips the slow test_dod3_full_gateway.sh (it runs the full suites).
set -uo pipefail
unset TITAN_SESSION_ID TELEMETRY_DIR
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
VAULT="$(cd "$HERE/../../.." && pwd -P)"
snap() {
  shasum "$VAULT/.scripts/spec_rubric.sh" "$VAULT/.scripts/lib_section.sh" \
    "$VAULT/02_Tasks/TiTan_LLM_OS/Spec_Rubric_Marker_False_Positive.md" 2>/dev/null | shasum
  git -C "$VAULT" rev-parse HEAD 2>/dev/null
}
before="$(snap)"
ERR="$(mktemp)"
rc=0
for t in "$HERE"/test_*.sh; do
  n="$(basename "$t")"
  if [ "$n" = test_dod3_full_gateway.sh ] && [ "${ACC_SKIP_GATEWAY:-0}" = 1 ]; then echo "SKIP $n (ACC_SKIP_GATEWAY=1)"; continue; fi
  if bash "$t" >/dev/null 2>"$ERR"; then echo "PASS $n"
  else echo "FAIL $n"; cat "$ERR"; rc=1; fi
done
rm -f "$ERR"
[ "$(snap)" = "$before" ] && echo "PASS task file / scripts / HEAD untouched" || { echo "FAIL task file, scripts or HEAD changed"; rc=1; }
exit $rc

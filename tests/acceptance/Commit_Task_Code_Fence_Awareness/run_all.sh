#!/usr/bin/env bash
# Runs every Commit_Task_Code_Fence_Awareness acceptance test, then proves the real task file,
# real scripts and live telemetry were not written and no real repo gained a commit.
# ACC_SKIP_GATEWAY=1 skips test_dod3_full_regression.sh (all smoke/kit/acceptance suites); the chain aggregator sets it.
set -uo pipefail
unset TITAN_SESSION_ID TELEMETRY_DIR
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
VAULT="$(cd "$HERE/../../.." && pwd -P)"
snap() {
  { shasum "$VAULT/02_Tasks/TiTan_LLM_OS/Commit_Task_Code_Fence_Awareness.md" "$VAULT"/.scripts/*.sh 2>/dev/null
    git -C "$VAULT" rev-parse HEAD
    cat "$VAULT"/04_Logs/Telemetry/*.jsonl 2>/dev/null | grep -c '"session_id": *"acc"'; } | shasum
}
before="$(snap)"
rc=0
for t in "$HERE"/test_*.sh; do
  n="$(basename "$t")"
  if [ "$n" = test_dod3_full_regression.sh ] && [ "${ACC_SKIP_GATEWAY:-0}" = 1 ]; then echo "SKIP $n (ACC_SKIP_GATEWAY=1)"; continue; fi
  if bash "$t" >/dev/null 2>"$HERE/.last_err"; then echo "PASS $n"
  else echo "FAIL $n"; cat "$HERE/.last_err"; rc=1; fi
done
rm -f "$HERE/.last_err"
[ "$(snap)" = "$before" ] && echo "PASS task file / scripts / repo HEAD / live telemetry untouched" || { echo "FAIL real task file, scripts, HEAD or live telemetry changed"; rc=1; }
exit $rc

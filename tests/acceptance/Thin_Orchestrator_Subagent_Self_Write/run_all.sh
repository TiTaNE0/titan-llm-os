#!/usr/bin/env bash
# Runs every Thin_Orchestrator_Subagent_Self_Write acceptance test under the default bash
# and under /bin/bash (3.2, what macOS ships), then proves the real vault was not written.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
VAULT="$(cd "$HERE/../../.." && pwd -P)"
TASK="$VAULT/02_Tasks/TiTan_LLM_OS/Thin_Orchestrator_Subagent_Self_Write.md"
snap() { { shasum "$TASK" "$VAULT/.session_state.json" 2>/dev/null; ls -la "$VAULT/04_Logs/Telemetry"; } | shasum; }
before="$(snap)"
rc=0
for sh in bash /bin/bash; do
  for t in "$HERE"/test_*.sh; do
    if HOOK_BASH="$sh" bash "$t" >/dev/null 2>"$HERE/.last_err"; then echo "PASS [$sh] $(basename "$t")"
    else echo "FAIL [$sh] $(basename "$t")"; cat "$HERE/.last_err"; rc=1; fi
  done
done
rm -f "$HERE/.last_err"
[ "$(snap)" = "$before" ] && echo "PASS real task file / session / telemetry untouched" || { echo "FAIL real vault changed"; rc=1; }
exit $rc

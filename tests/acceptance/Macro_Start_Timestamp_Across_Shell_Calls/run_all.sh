#!/usr/bin/env bash
# Runs every Macro_Start_Timestamp_Across_Shell_Calls acceptance test, then proves the kit, the
# vault gateways and the live telemetry log were not written.
# ACC_SKIP_GATEWAY=1 skips test_dod4_gateway_green.sh (the full gateway with all kit + vault
# suites); the exit code then reflects only the remaining checks. The chain aggregator sets it.
set -uo pipefail
unset TITAN_SESSION_ID TELEMETRY_DIR
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
VAULT="$(cd "$HERE/../../.." && pwd -P)"
KIT="${KIT_ROOT:-$HOME/AI_Workflow/claude-agent-kit}"
snap() {
  shasum "$KIT"/project-template/.claude/commands/*.md "$KIT/install.sh" "$VAULT"/tests/test_*.sh \
    "$VAULT"/.scripts/telemetry_start.sh "$VAULT"/.scripts/emit_telemetry.sh 2>/dev/null | shasum
  # Other sessions append new_task/retrospective rows to the live log, so count only this suite's probe macros.
  cat "$VAULT"/04_Logs/Telemetry/*.jsonl 2>/dev/null \
    | grep -cE '"macro": *"(acc_mst_probe|mst_probe|mst_nostart)"'
}
before="$(snap)"
rc=0
for t in "$HERE"/test_*.sh; do
  n="$(basename "$t")"
  if [ "$n" = test_dod4_gateway_green.sh ] && [ "${ACC_SKIP_GATEWAY:-0}" = 1 ]; then echo "SKIP $n (ACC_SKIP_GATEWAY=1)"; continue; fi
  if bash "$t" >/dev/null 2>"$HERE/.last_err"; then echo "PASS $n"
  else echo "FAIL $n"; cat "$HERE/.last_err"; rc=1; fi
done
rm -f "$HERE/.last_err"
[ "$(snap)" = "$before" ] && echo "PASS kit / gateways / live telemetry untouched" || { echo "FAIL real kit, vault or live telemetry file changed"; rc=1; }
exit $rc

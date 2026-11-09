#!/usr/bin/env bash
# Runs every Spec_Gate_And_Test_Isolation_Hardening acceptance test, then proves the real
# task file, vault scripts and repo HEAD were not changed.
# ACC_SKIP_GATEWAY=1 skips the slow tests that run full kit/vault suite loops or the full
# gateway: test_dod4_every_kit_suite_leaves_telemetry_identical.sh, test_dod7_full_gateway.sh.
set -uo pipefail
unset TITAN_SESSION_ID TELEMETRY_DIR
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
VAULT="$(cd "$HERE/../../.." && pwd -P)"
snap() {
  { shasum "$VAULT/02_Tasks/TiTan_LLM_OS/Spec_Gate_And_Test_Isolation_Hardening.md" "$VAULT"/.scripts/*.sh 2>/dev/null
    git -C "$VAULT" rev-parse HEAD; } | shasum
}
before="$(snap)"
rc=0
for t in "$HERE"/test_*.sh; do
  n="$(basename "$t")"
  case "$n" in test_dod4_every_kit_suite_leaves_telemetry_identical.sh|test_dod7_full_gateway.sh)
    if [ "${ACC_SKIP_GATEWAY:-0}" = 1 ]; then echo "SKIP $n (ACC_SKIP_GATEWAY=1)"; continue; fi ;;
  esac
  if bash "$t" >/dev/null 2>"$HERE/.last_err"; then echo "PASS $n"
  else echo "FAIL $n"; cat "$HERE/.last_err"; rc=1; fi
done
rm -f "$HERE/.last_err"
[ "$(snap)" = "$before" ] && echo "PASS task file / scripts / repo HEAD untouched" || { echo "FAIL real task file, scripts or HEAD changed"; rc=1; }
exit $rc

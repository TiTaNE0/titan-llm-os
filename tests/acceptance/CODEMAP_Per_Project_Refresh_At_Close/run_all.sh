#!/usr/bin/env bash
# Runs every CODEMAP_Per_Project_Refresh_At_Close acceptance test, then proves the vault HEAD,
# the vault worktree's CODEMAP.md state and the scripts under test were not changed.
# ACC_SKIP_GATEWAY=1 skips test_dod4_gateway_skip_mode.sh (it runs the task gateway).
set -uo pipefail
unset TITAN_SESSION_ID TELEMETRY_DIR
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
VAULT="$(cd "$HERE/../../.." && pwd -P)"
snap() {
  shasum "$VAULT/.scripts/codemap_refresh.sh" "$VAULT/.scripts/commit_task.sh" 2>/dev/null | shasum
  git -C "$VAULT" rev-parse HEAD 2>/dev/null
  [ -e "$VAULT/CODEMAP.md" ] && cksum < "$VAULT/CODEMAP.md" || echo no-codemap
}
before="$(snap)"
ERR="$(mktemp)"
rc=0
for t in "$HERE"/test_*.sh; do
  n="$(basename "$t")"
  if [ "$n" = test_dod4_gateway_skip_mode.sh ] && [ "${ACC_SKIP_GATEWAY:-0}" = 1 ]; then echo "SKIP $n (ACC_SKIP_GATEWAY=1)"; continue; fi
  if bash "$t" >/dev/null 2>"$ERR"; then echo "PASS $n"
  else echo "FAIL $n"; cat "$ERR"; rc=1; fi
done
rm -f "$ERR"
[ "$(snap)" = "$before" ] && echo "PASS vault scripts / HEAD / CODEMAP.md untouched" || { echo "FAIL vault scripts, HEAD or CODEMAP.md changed"; rc=1; }
exit $rc

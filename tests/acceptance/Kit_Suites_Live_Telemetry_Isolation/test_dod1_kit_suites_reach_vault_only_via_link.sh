#!/usr/bin/env bash
# DoD 1 (precondition): kit suites reach the vault only through the relative .vault_link/,
# so no suite can write the live vault behind the private-mirror measurement.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
n=0
for t in "$KIT"/tests/test_*.sh; do
  [ -f "$t" ] || continue; n=$((n + 1))
  if grep -nE 'Mission_Control|iCloud~md~obsidian|/04_Logs/Telemetry' "$t" | grep -v '\.vault_link/' >"$TMP/hits"; then
    fail "$(basename "$t") names the vault or live telemetry by absolute path: $(head -n 3 "$TMP/hits" | tr '\n' ';')"
  else pass "$(basename "$t") vault access only via .vault_link/"; fi
done
[ "$n" -ge 1 ] || fail "kit suite glob matched nothing"
finish

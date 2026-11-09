#!/usr/bin/env bash
# DoD 1 (non-vacuity): the mirror measurement used for DoD 1 does catch the original leak.
# Reintroducing either half of the bug in the private mirror must put rows in the
# mirror's default telemetry dir. Nothing here touches the live vault or the real kit.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
build_mirror
mirror_valid && pass "kit copy resolves to private mirror" || { fail "mirror invalid"; finish; }
cp "$M/.scripts/emit_telemetry.real.sh" "$TMP/emit.fixed"

# RED 1: kit suite without its TELEMETRY_DIR export leaks through .vault_link.
for name in test_gateway_allowlist.sh test_gateway_adversarial.sh; do
  cp "$KIT/tests/$name" "$K/tests/$name"
  sed -i '' '/^export TELEMETRY_DIR=/d' "$K/tests/$name"
  grep -q 'TELEMETRY_DIR' "$K/tests/$name" && { fail "$name: export not stripped"; continue; }
  run_mirror_suite "$name"
  r="$(mirror_rows)"
  [ "$r" -ge 1 ] && pass "$name without export leaks $r rows into the default dir" \
    || fail "$name without export: 0 rows in default dir (detector blind)"
  rm -rf "$MTEL"; mkdir "$MTEL"
  cp "$KIT/tests/$name" "$K/tests/$name"
done

# RED 2: emit_telemetry.sh ignoring the env override (the pre-fix line) leaks even for
# test_metrics_breakdown.sh, which already passed TELEMETRY_DIR per invocation.
sed -i '' 's|^TELEMETRY_DIR="\${TELEMETRY_DIR:-\$VAULT_DIR/04_Logs/Telemetry}"$|TELEMETRY_DIR="$VAULT_DIR/04_Logs/Telemetry"|' "$M/.scripts/emit_telemetry.real.sh"
cmp -s "$M/.scripts/emit_telemetry.real.sh" "$TMP/emit.fixed" && fail "override line not found in emit_telemetry.sh"
run_mirror_suite test_metrics_breakdown.sh
r="$(mirror_rows)"
[ "$r" -ge 1 ] && pass "pre-fix emit leaks $r rows from test_metrics_breakdown.sh" \
  || fail "pre-fix emit: 0 rows in default dir (detector blind)"
rm -rf "$MTEL"; mkdir "$MTEL"

# GREEN control in the same mirror: restoring the fix stops the leak.
cp "$TMP/emit.fixed" "$M/.scripts/emit_telemetry.real.sh"
run_mirror_suite test_metrics_breakdown.sh
expect "fixed emit: rows in default dir from test_metrics_breakdown.sh" 0 "$(mirror_files)"
finish

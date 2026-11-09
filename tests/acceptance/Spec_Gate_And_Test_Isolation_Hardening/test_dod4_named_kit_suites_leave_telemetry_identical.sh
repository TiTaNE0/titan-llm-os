#!/usr/bin/env bash
# DoD 4: the kit suites the task names (gateway allowlist/adversarial, resolve_attention and
# its edge suite) leave the vault telemetry *.jsonl byte-identical. They run from a kit copy
# whose .vault_link points at a private vault mirror, so the "real vault" telemetry they would
# reach is the mirror's, which no other session writes. The detector is proven non-vacuous.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
build_mirror
printf '{"ts":"seed"}\n' > "$MTEL/2026-01.jsonl"
s0="$(tel_snap "$MTEL")"
( unset TELEMETRY_DIR; bash "$M/.scripts/emit_telemetry.sh" acc_probe success 0 >/dev/null 2>&1 )
s1="$(tel_snap "$MTEL")"
[ "$s0" != "$s1" ] && pass "detector RED: an un-overridden emit changes the snapshot" \
  || fail "detector vacuous: emit without TELEMETRY_DIR did not change mirror telemetry"
before="$(tel_snap "$MTEL")"
run_kit_suites test_gateway_allowlist.sh test_gateway_adversarial.sh test_resolve_attention.sh test_resolve_attention_edge.sh
[ -z "$KIT_RED" ] && pass "named kit suites green" || fail "kit suites red:$KIT_RED"
expect "mirror telemetry byte-identical across named kit suites" "$before" "$(tel_snap "$MTEL")"
finish

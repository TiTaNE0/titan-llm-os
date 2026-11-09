#!/usr/bin/env bash
# DoD 4 (full loop, skipped by run_all.sh under ACC_SKIP_GATEWAY=1): every kit tests/test_*.sh
# leaves the vault telemetry *.jsonl byte-identical, checked before and after, on a private mirror.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
build_mirror
printf '{"ts":"seed"}\n' > "$MTEL/2026-01.jsonl"
before="$(tel_snap "$MTEL")"
names=""; for t in "$K"/tests/test_*.sh; do names="$names $(basename "$t")"; done
run_kit_suites $names
[ -z "$KIT_RED" ] && pass "all kit suites green" || fail "kit suites red:$KIT_RED"
expect "mirror telemetry byte-identical across every kit suite" "$before" "$(tel_snap "$MTEL")"
finish

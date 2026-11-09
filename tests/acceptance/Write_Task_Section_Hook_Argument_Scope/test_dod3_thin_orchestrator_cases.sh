#!/usr/bin/env bash
# DoD 3: every hook allow case that tests/test_thin_orchestrator.sh had before this task still
# exists and passes; new foreign-path / foreign-section / duplicate-section refuse cases are added and pass.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
T="$VAULT/tests/test_thin_orchestrator.sh"
labels() { grep -oE "expect $1 \"[^\"]+\"" | sed -E "s/^expect $1 \"(.*)\"$/\1/" | sort -u; }

# Pinned to the commit before this task changed test_thin_orchestrator.sh, so the check survives the task commit.
BASE=1e6d492
OLD="$(cd "$VAULT" && git show "$BASE:tests/test_thin_orchestrator.sh" | labels allow)"
NEW="$(labels allow < "$T")"
[ -n "$OLD" ] && pass "baseline allow cases read from $BASE" || fail "no baseline allow cases"
missing="$(comm -23 <(printf '%s\n' "$OLD") <(printf '%s\n' "$NEW"))"
[ -z "$missing" ] && pass "no allow case dropped" || fail "allow cases dropped: $missing"

OUT="$(THIN_ORCH_SKIP_SUITES=1 bash "$T" 2>&1)"; rc=$?
[ "$rc" = 0 ] && pass "test_thin_orchestrator.sh (suites skipped) exits 0" || fail "test_thin_orchestrator.sh rc=$rc: $(printf '%s\n' "$OUT" | grep FAIL)"
while IFS= read -r l; do
  [ -n "$l" ] || continue
  printf '%s\n' "$OUT" | grep -qxF "PASS: hook ALLOW $l" && pass "still allowed: $l" || fail "allow case not passing: $l"
done <<< "$OLD"
for l in "foreign task path" "foreign section" "duplicate --section"; do
  grep -qF "expect refuse \"$l\"" "$T" && printf '%s\n' "$OUT" | grep -qxF "PASS: hook REFUSE $l" \
    && pass "new refuse case present and passing: $l" || fail "refuse case missing or failing: $l"
done
finish

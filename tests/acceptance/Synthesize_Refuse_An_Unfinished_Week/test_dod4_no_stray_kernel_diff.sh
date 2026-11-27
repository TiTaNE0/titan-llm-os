#!/usr/bin/env bash
# DoD 4 (partial): the /graduate step is post-build, so only assert no uncommitted 03_Brain diff exists.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
cd "$VAULT"
git diff --quiet HEAD -- 03_Brain && pass "no uncommitted diff under 03_Brain" || fail "uncommitted 03_Brain diff"
staged="$(git diff --cached --name-only -- 03_Brain)"
[ -z "$staged" ] && pass "nothing staged under 03_Brain" || fail "staged: $staged"
finish

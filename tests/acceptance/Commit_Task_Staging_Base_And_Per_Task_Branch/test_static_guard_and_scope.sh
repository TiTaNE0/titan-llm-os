#!/usr/bin/env bash
# DoD 3/4: no push/merge/stash/reset/checkout in code lines; bash 3.2 syntax; scope of change.
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
cd "$VAULT"
/bin/bash -n .scripts/commit_task.sh && pass "bash 3.2 parses" || fail "syntax"
if grep -v '^[[:space:]]*#' .scripts/commit_task.sh | grep -v 'rebase-merge' | grep -nEw 'push|merge|stash|reset|fetch|ls-remote|checkout'; then fail "forbidden verb in code line"; else pass "no forbidden verbs"; fi
grep -q 'orch/<id>/<task-slug>' .scripts/commit_task.sh && pass "usage text updated" || fail "usage text not updated"
if git diff --name-only HEAD -- 03_Brain | grep -v '^03_Brain/Tool_Registry.md$' | grep .; then fail "03_Brain changed"; else pass "no builder change in 03_Brain"; fi
finish

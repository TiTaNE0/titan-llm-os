#!/usr/bin/env bash
# smoke_task_contract_check.sh — the contract guard (Task_Contract_Population_And_Guard).
# all-filled → pass; each section left as a placeholder → exit 3; bad args → E2. Temp-isolated.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
CHK="$REPO_ROOT/.scripts/task_contract_check.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

# Build a task with chosen section bodies.
mk() { # file  objective  dod  gateway
  cat > "$1" <<EOF
---
project: [[P]]
status: todo
type: task
---
# Task

## 📋 Declarative Objective
- [ ] $2

## 🎯 Definition of Done (Success Criteria)
- [ ] $3

## 🧪 Verification Gateway
- [ ] **Test Command:** $4
- [ ] **Protocol:** Execute and verify exit code 0.
EOF
}

# 1. All authored -> PASS
mk "$TMP/ok.md" "Build the widget" "Widget exists and is tested" "\`bash tests/smoke_widget.sh\`"
"$CHK" --task-path "$TMP/ok.md" >/dev/null || fail "fully-authored contract should pass"

# 2. Objective placeholder -> exit 3
mk "$TMP/obj.md" "(What we want to achieve)" "Real DoD" "\`real-cmd\`"
rc=0; "$CHK" --task-path "$TMP/obj.md" 2>/dev/null || rc=$?
[[ "$rc" -eq 3 ]] || fail "objective placeholder should exit 3, got $rc"

# 3. DoD placeholder -> exit 3
mk "$TMP/dod.md" "Real objective" "(Success criteria)" "\`real-cmd\`"
rc=0; "$CHK" --task-path "$TMP/dod.md" 2>/dev/null || rc=$?
[[ "$rc" -eq 3 ]] || fail "DoD placeholder should exit 3, got $rc"

# 4. Gateway placeholder -> exit 3
mk "$TMP/gw.md" "Real objective" "Real DoD" "(Command to run)"
rc=0; "$CHK" --task-path "$TMP/gw.md" 2>/dev/null || rc=$?
[[ "$rc" -eq 3 ]] || fail "gateway placeholder should exit 3, got $rc"

# 5b. Regression: a task that MENTIONS the placeholder strings in prose (e.g. a task
#     *about* the placeholders) must still PASS — exact-line match, not substring.
mk "$TMP/meta.md" "Discuss the (What we want to achieve) placeholder behaviour" \
   "Detect (Success criteria) and (Command to run) markers" \
   "\`bash tests/smoke_x.sh\` — replaces the (Command to run) stub"
"$CHK" --task-path "$TMP/meta.md" >/dev/null || fail "prose mentioning placeholders must still PASS (exact-line match)"

# 5. Bad args -> E2
rc=0; "$CHK" 2>/dev/null || rc=$?
[[ "$rc" -eq 2 ]] || fail "missing --task-path should exit 2, got $rc"
rc=0; "$CHK" --task-path "$TMP/nope.md" 2>/dev/null || rc=$?
[[ "$rc" -eq 2 ]] || fail "missing file should exit 2, got $rc"

echo "SMOKE: OK"

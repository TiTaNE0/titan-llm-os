#!/usr/bin/env bash
# smoke_author_contract.sh — guarded header-contract authoring (author_contract.sh).
# Authors objective/dod/gateway on a placeholder task; proves it composes with the
# guard (task_contract_check), refuses re-author without --overwrite, and gates persona.
# Temp-isolated vault with copied scripts + an Executioner session state.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRIPTS="$REPO_ROOT/.scripts"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/.scripts" "$TMP/04_Logs/Telemetry"
cp "$SCRIPTS/author_contract.sh" "$SCRIPTS/task_contract_check.sh" "$SCRIPTS/persona_check.sh" "$SCRIPTS/emit_telemetry.sh" "$SCRIPTS/lib_section.sh" "$TMP/.scripts/"
printf '{\n  "persona": "Executioner",\n  "session_id": "smoke",\n  "started_at": "2026-06-17T00:00:00Z",\n  "agent_surface": "test"\n}\n' > "$TMP/.session_state.json"
S="$TMP/.scripts"
fail() { echo "FAIL: $1" >&2; exit 1; }

# A task with the real template header placeholders.
T="$TMP/T.md"
cat > "$T" <<'EOF'
---
project: [[P]]
status: todo
type: task
---
# ⚡ Task: T

## 📋 Declarative Objective
- [ ] (What we want to achieve)

## 🎯 Definition of Done (Success Criteria)
- [ ] (Success criteria)

## 🧪 Verification Gateway
- [ ] **Test Command:** (Command to run)
- [ ] **Protocol:** Execute and verify exit code 0.

## 🔬 Research Notes
> placeholder
EOF

cf() { printf -- '%s\n' "$1" > "$TMP/cf"; echo "$TMP/cf"; }

# Guard fails up front (all placeholders).
rc=0; "$S/task_contract_check.sh" --task-path "$T" >/dev/null 2>&1 || rc=$?
[[ "$rc" -eq 3 ]] || fail "guard should fail on fresh placeholders, got $rc"

# Author each section.
"$S/author_contract.sh" --task-path "$T" --section objective --source-persona Executioner --content-file "$(cf '- [ ] Build the widget end to end')" >/dev/null || fail "author objective failed"
"$S/author_contract.sh" --task-path "$T" --section dod --source-persona Executioner --content-file "$(cf '- [ ] Widget exists
- [ ] Tests pass')" >/dev/null || fail "author dod failed"
"$S/author_contract.sh" --task-path "$T" --section gateway --source-persona Executioner --content-file "$(cf '- [ ] **Test Command:** `bash tests/smoke_widget.sh`
- [ ] **Protocol:** exit 0.')" >/dev/null || fail "author gateway failed"

# Guard now passes — proves composition.
"$S/task_contract_check.sh" --task-path "$T" >/dev/null || fail "guard should PASS after authoring all three"
# Body preserved correctly: objective text present, placeholder gone.
grep -qF "Build the widget end to end" "$T" || fail "objective content not written"
grep -qxF -- "- [ ] (What we want to achieve)" "$T" && fail "objective placeholder still present"
# Other sections of the file untouched (Research Notes header survives).
grep -qF "## 🔬 Research Notes" "$T" || fail "downstream section clobbered"

# Re-author without --overwrite -> E3 (already authored).
rc=0; "$S/author_contract.sh" --task-path "$T" --section objective --source-persona Executioner --content-file "$(cf '- [ ] changed')" 2>/dev/null || rc=$?
[[ "$rc" -eq 3 ]] || fail "re-author without --overwrite should exit 3, got $rc"
# With --overwrite -> ok.
"$S/author_contract.sh" --task-path "$T" --section objective --source-persona Executioner --content-file "$(cf '- [ ] changed objective')" --overwrite >/dev/null || fail "--overwrite should succeed"
grep -qF "changed objective" "$T" || fail "overwrite content not written"

# Wrong persona -> E4.
rc=0; "$S/author_contract.sh" --task-path "$T" --section dod --source-persona Architect --content-file "$(cf 'x')" 2>/dev/null || rc=$?
[[ "$rc" -eq 4 ]] || fail "wrong persona should exit 4, got $rc"

# Missing header -> E3.
echo "# no sections here" > "$TMP/bare.md"
rc=0; "$S/author_contract.sh" --task-path "$TMP/bare.md" --section objective --source-persona Executioner --content-file "$(cf 'x')" 2>/dev/null || rc=$?
[[ "$rc" -eq 3 ]] || fail "missing header should exit 3, got $rc"

echo "SMOKE: OK"

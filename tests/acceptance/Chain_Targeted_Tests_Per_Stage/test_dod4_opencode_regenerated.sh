#!/usr/bin/env bash
# DoD 4: after the kit edits, setup-opencode was re-run (the installed OpenCode files equal what
# a fresh render of the current kit produces) and check-opencode passes on the installed dir.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
bash "$KIT/install.sh" check-opencode --path "$OC_AGENT" >"$TMP/chk" 2>&1; rc=$?
expect "check-opencode exit code" 0 "$rc"

BIND="${XDG_CONFIG_HOME:-$HOME/.config}/claude-agent-kit/opencode-bindings"
[ -f "$BIND" ] || { fail "no bindings file at $BIND"; finish; }
SA="$TMP/oc/agent"; SC="$TMP/oc/command"
bash "$KIT/install.sh" setup-opencode --path "$SA" --command-path "$SC" --bindings "$BIND" >"$TMP/setup" 2>&1; rc=$?
expect "scratch setup-opencode exit code" 0 "$rc"
for a in builder backend-builder frontend-builder test-verifier validator; do
  if cmp -s "$SA/$a.md" "$OC_AGENT/$a.md"; then pass "installed $a.md matches a fresh render"
  else fail "installed $a.md is stale versus the kit (re-run install.sh setup-opencode)"; fi
done
# Commands bake their install paths (and hash them into the generated-by line); compare the
# body with the scratch paths mapped back and the generated-by hash line dropped.
RA="$(cd "$OC_AGENT" && pwd)"; RC="$(cd "$OC_CMD" && pwd)"
awk -v a="$SA" -v ra="$RA" -v c="$SC" -v rc="$RC" '/^# generated-by: /{next} {gsub(a,ra); gsub(c,rc); print}' "$SC/execute_task.md" > "$TMP/exec_mapped.md"
grep -v '^# generated-by: ' "$OC_CMD/execute_task.md" > "$TMP/exec_installed.md"
if cmp -s "$TMP/exec_mapped.md" "$TMP/exec_installed.md"; then pass "installed command/execute_task.md matches a fresh render"
else fail "installed command/execute_task.md is stale versus the kit"; fi
grep -qF -- "$S_STEP13" "$OC_CMD/execute_task.md" && pass "OpenCode execute_task carries the Step 13 rule" || fail "OpenCode execute_task lacks the Step 13 rule"
finish

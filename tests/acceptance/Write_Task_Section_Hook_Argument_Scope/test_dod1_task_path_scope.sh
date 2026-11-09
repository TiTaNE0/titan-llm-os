#!/usr/bin/env bash
# DoD 1: a planner (through its registered frontmatter hook) can persist its spec into a task file
# under .vault_link/02_Tasks/<Project>/<Name>.md, and is blocked from writing anywhere else --
# even though write_task_section.sh itself would accept the foreign file.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
PL="$KIT/global/agents/planner.md"
V="$TMP/v"; mk_vault "$V"

# Happy path: hook allows, the command runs, the spec lands in the briefed task.
cmd="$(persist .vault_link/02_Tasks/P/T.md spec)"
rc="$(declared_rc "$PL" "$cmd")"
[ "$rc" = 0 ] && pass "planner persist into 02_Tasks/P/T.md allowed" || fail "planner own task blocked (rc=$rc): $(cat "$TMP/err")"
rc="$(run_in "$V" "$cmd")"
[ "$rc" = 0 ] && grep -q '^body from spec$' "$V/02_Tasks/P/T.md" && pass "spec landed in the task file" || fail "spec not written (rc=$rc): $(cat "$TMP/run_err")"

# A task name with spaces (real vault shape) is still a task file.
mk_task "$V/02_Tasks/P/C11.17 Event wizard.md"
rc="$(declared_rc "$PL" "$(persist ".vault_link/02_Tasks/P/C11.17 Event wizard.md" spec)")"
[ "$rc" = 0 ] && pass "quoted task path with spaces allowed" || fail "spaced task path blocked (rc=$rc): $(cat "$TMP/err")"

# Foreign targets that exist and that write_task_section.sh would happily write.
mk_task "$V/03_Brain/System_Agents.md"
mkdir -p "$V/02_Tasks/P/S"; mk_task "$V/02_Tasks/P/S/T.md"
mk_task "$V/02_Tasks/T.md"
mk_task "$V/02_Tasks/P/.T.md"
cp "$V/02_Tasks/P/T.md" "$V/02_Tasks/P/T.txt"
for p in .vault_link/03_Brain/System_Agents.md .vault_link/02_Tasks/P/S/T.md .vault_link/02_Tasks/T.md \
         .vault_link/02_Tasks/P/.T.md .vault_link/02_Tasks/P/T.txt "$V/02_Tasks/P/T.md" 02_Tasks/P/T.md \
         .vault_link/02_Tasks/../03_Brain/System_Agents.md; do
  cmd="$(persist "$p" research_notes)"
  rc="$(declared_rc "$KIT/global/agents/researcher.md" "$cmd")"
  if [ "$rc" = 2 ]; then
    grep -q '^BLOCKED (Bash limited to one write_task_section.sh call): ' "$TMP/err" \
      && pass "foreign path blocked with BLOCKED prefix: $p" || fail "foreign path $p blocked without prefix: $(cat "$TMP/err")"
  else fail "foreign path allowed (rc=$rc): $p"; fi
done
# Proof the hook is the barrier: the same foreign write succeeds when the hook is bypassed.
rc="$(run_in "$V" "$(persist .vault_link/03_Brain/System_Agents.md research_notes)")"
[ "$rc" = 0 ] && grep -q '^body from research_notes$' "$V/03_Brain/System_Agents.md" \
  && pass "RED: unguarded script writes 03_Brain, so the block above is load-bearing" || fail "RED setup: script refused foreign path itself (rc=$rc)"

# Smuggling the path past the check: equals form, a second --task-path, a missing value.
ok=".vault_link/02_Tasks/P/T.md"
for c in \
  "$W --task-path=$ok --section spec --source-persona Executioner --content-file y" \
  "$W --task-path $ok --task-path .vault_link/03_Brain/System_Agents.md --section spec --source-persona Executioner --content-file y" \
  "$W --section spec --source-persona Executioner --content-file y" \
  "$W --section spec --source-persona Executioner --content-file y --task-path" \
  "$W --task-path \"\" --section spec --source-persona Executioner --content-file y"; do
  rc="$(declared_rc "$PL" "$c")"
  [ "$rc" = 2 ] && pass "blocked: ${c#$W }" || fail "allowed (rc=$rc): ${c#$W }"
done
finish

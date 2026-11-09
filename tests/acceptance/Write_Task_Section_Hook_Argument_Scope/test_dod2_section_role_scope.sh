#!/usr/bin/env bash
# DoD 2: each hook-limited agent may only write the section its role owns. The role comes from the
# frontmatter hook registration, falls back to the hook input's agent_type, and an unknown or
# missing role fails closed. Checked under the default bash and /bin/bash (3.2).
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
P=.vault_link/02_Tasks/P/T.md
ALL="research_notes spec validator_report verification_output"
own() { case "$1" in researcher) echo research_notes ;; *) echo spec ;; esac; }

# Registered agents, as Claude Code would invoke them (global/agents and docs/cld twins).
for f in "$KIT"/global/agents/planner.md "$KIT"/global/agents/researcher.md "$KIT"/global/agents/spec-writer.md \
         "$KIT"/docs/cld/researcher.md "$KIT"/docs/cld/spec-writer.md; do
  a="$(basename "$f" .md)"; tag="${f#$KIT/}"
  hook_cmd "$f" | grep -qF "bash_write_task_section_only.sh\" $a || exit 2" \
    && pass "$tag registers role '$a' with fail-closed suffix" || fail "$tag hook line lacks role '$a': $(hook_cmd "$f")"
  for s in $ALL; do
    rc="$(declared_rc "$f" "$(persist "$P" "$s")")"
    if [ "$s" = "$(own "$a")" ]; then
      [ "$rc" = 0 ] && pass "$tag writes own section $s" || fail "$tag own section $s blocked (rc=$rc): $(cat "$TMP/err")"
    else
      [ "$rc" = 2 ] && pass "$tag blocked from $s" || fail "$tag wrote foreign section $s (rc=$rc)"
    fi
  done
  # The registration wins over a contradicting agent_type in the hook input.
  other=researcher; [ "$a" = researcher ] && other=planner
  rc="$(declared_rc "$f" "$(persist "$P" "$(own "$other")")" "$other")"
  [ "$rc" = 2 ] && pass "$tag: agent_type '$other' cannot widen the registered role" || fail "$tag: agent_type overrode registration (rc=$rc)"
done

for sh in bash /bin/bash; do
  # Fallback: no registration argument -> agent_type decides.
  [ "$(direct_rc "$sh" "" validator "$(persist "$P" validator_report)")" = 0 ] && pass "[$sh] agent_type validator writes validator_report" || fail "[$sh] validator fallback blocked: $(cat "$TMP/err")"
  [ "$(direct_rc "$sh" "" validator "$(persist "$P" spec)")" = 2 ] && pass "[$sh] agent_type validator blocked from spec" || fail "[$sh] validator wrote spec"
  [ "$(direct_rc "$sh" "" planner "$(persist "$P" spec)")" = 0 ] && pass "[$sh] agent_type planner writes spec" || fail "[$sh] planner fallback blocked: $(cat "$TMP/err")"
  # Fail closed: unknown role, no role at all, roles without a section (builder, test-verifier).
  for r in builder test-verifier Planner; do
    rc="$(direct_rc "$sh" "$r" "" "$(persist "$P" spec)")"
    [ "$rc" = 2 ] && grep -qF "unknown role '$r'" "$TMP/err" && pass "[$sh] unknown role '$r' blocked" || fail "[$sh] role '$r' not blocked as unknown (rc=$rc): $(cat "$TMP/err")"
  done
  rc="$(direct_rc "$sh" "" "" "$(persist "$P" spec)")"
  [ "$rc" = 2 ] && grep -qF "unknown role ''" "$TMP/err" && pass "[$sh] missing role fails closed" || fail "[$sh] missing role (rc=$rc): $(cat "$TMP/err")"
  # Section smuggling.
  rc="$(direct_rc "$sh" planner "" "$W --task-path $P --section spec --section validator_report --source-persona Executioner --content-file y")"
  [ "$rc" = 2 ] && pass "[$sh] duplicate --section blocked" || fail "[$sh] duplicate --section allowed"
  rc="$(direct_rc "$sh" planner "" "$W --task-path $P \"--section\" \"validator_report\" --source-persona Executioner --content-file y")"
  [ "$rc" = 2 ] && pass "[$sh] quoted foreign section blocked" || fail "[$sh] quoted foreign section allowed"
  rc="$(direct_rc "$sh" planner "" "$W --task-path $P --section=spec --source-persona Executioner --content-file y")"
  [ "$rc" = 2 ] && pass "[$sh] --section= form blocked" || fail "[$sh] --section= allowed"
  # Read-only exploration stays role-independent.
  [ "$(direct_rc "$sh" "" "" "ls -la")" = 0 ] && pass "[$sh] read-only ls allowed with no role" || fail "[$sh] read-only ls blocked"
done

# End to end: the researcher's foreign-section attempt leaves the task untouched; its own write lands.
V="$TMP/v"; mk_vault "$V"; RS="$KIT/global/agents/researcher.md"
before="$(shasum "$V/02_Tasks/P/T.md")"
[ "$(declared_rc "$RS" "$(persist "$P" spec)")" = 2 ] && [ "$(shasum "$V/02_Tasks/P/T.md")" = "$before" ] \
  && pass "researcher spec attempt blocked, task unchanged" || fail "researcher spec attempt not blocked"
cmd="$(persist "$P" research_notes)"
[ "$(declared_rc "$RS" "$cmd")" = 0 ] && [ "$(run_in "$V" "$cmd")" = 0 ] && grep -q '^body from research_notes$' "$V/02_Tasks/P/T.md" \
  && pass "researcher research_notes persisted end to end" || fail "researcher own persist failed: $(cat "$TMP/err" "$TMP/run_err")"

# RED: a permissive stub registered the same way would let the foreign section through.
R="$TMP/red"; mkdir -p "$R/.claude/hooks"; printf 'cat >/dev/null; exit 0\n' > "$R/.claude/hooks/bash_write_task_section_only.sh"
rc="$(hook_json "$(persist "$P" validator_report)" | HOME="$R" sh -c "$(hook_cmd "$KIT/global/agents/planner.md")" >/dev/null 2>&1; echo $?)"
[ "$rc" = 0 ] && pass "RED: permissive stub would be caught" || fail "RED setup broken (rc=$rc)"
finish

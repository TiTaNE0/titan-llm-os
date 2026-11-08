#!/usr/bin/env bash
# DoD 2: the hook command actually declared in researcher/spec-writer frontmatter refuses a
# non-allowed command, allows the sanctioned call, and fails closed when the hook is absent.
# validator/test-verifier keep full Bash (no hook) and get the new status contracts.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
AG="$KIT/global/agents"

frontmatter() { awk 'NR==1 && /^---$/ {on=1; next} on && /^---$/ {exit} on {print}' "$1"; }
# The literal `command:` string Claude Code would run, with YAML single quotes removed.
hook_cmd() { frontmatter "$1" | sed -n "s/^ *command: '\(.*\)'$/\1/p" | head -1; }
# run_declared <agent.md> <HOME> <bash command>: exit code of the frontmatter hook command.
run_declared() { hook_json "$3" | HOME="$2" sh -c "$(hook_cmd "$1")" >/dev/null 2>&1; echo $?; }

OK_CMD=".vault_link/.scripts/write_task_section.sh --task-path \".vault_link/02_Tasks/P/T.md\" --section spec --source-persona Executioner --content-file - <<'SPEC_EOF'"$'\nbody\nSPEC_EOF'

for a in researcher spec-writer; do
  f="$AG/$a.md"
  c="$(hook_cmd "$f")"
  [ -n "$c" ] || { fail "$a: no hook command in frontmatter"; continue; }
  frontmatter "$f" | grep -q '^tools:.*\bBash\b' && pass "$a tools include Bash" || fail "$a tools lack Bash"
  frontmatter "$f" | grep -q 'PreToolUse:' && frontmatter "$f" | grep -q 'matcher: "Bash"' \
    && pass "$a PreToolUse matcher Bash" || fail "$a PreToolUse/matcher missing"
  [ "$(run_declared "$f" "$HOME" "rm -rf /tmp/x")" = 2 ] && pass "$a: declared hook refuses rm" || fail "$a: rm not refused"
  [ "$(run_declared "$f" "$HOME" "cat ~/.ssh/id_rsa")" = 2 ] && pass "$a: declared hook refuses cat" || fail "$a: cat not refused"
  [ "$(run_declared "$f" "$HOME" "$OK_CMD")" = 0 ] && pass "$a: declared hook allows persist call" || fail "$a: persist call refused"
  mkdir -p "$TMP/emptyhome"
  [ "$(run_declared "$f" "$TMP/emptyhome" "$OK_CMD")" = 2 ] && pass "$a: fail-closed when hook not installed" || fail "$a: not fail-closed"
  # Hook that crashes (exit 1) must still map to a block.
  mkdir -p "$TMP/crashhome/.claude/hooks"; printf 'exit 1\n' > "$TMP/crashhome/.claude/hooks/bash_write_task_section_only.sh"
  [ "$(run_declared "$f" "$TMP/crashhome" "$OK_CMD")" = 2 ] && pass "$a: crashing hook maps to block" || fail "$a: crash not mapped to 2"
  # docs/cld twin must declare the same hook
  t="$KIT/docs/cld/$a.md"
  [ "$(hook_cmd "$t")" = "$c" ] && pass "$a docs/cld twin same hook" || fail "$a docs/cld twin hook differs"
done

# RED: the refusal checks above must be able to fail -- a permissive stub hook is detected.
mkdir -p "$TMP/redhome/.claude/hooks"; printf 'cat >/dev/null; exit 0\n' > "$TMP/redhome/.claude/hooks/bash_write_task_section_only.sh"
[ "$(run_declared "$AG/researcher.md" "$TMP/redhome" "rm -rf /tmp/x")" = 0 ] && pass "RED: permissive stub would be caught (allows rm)" || fail "RED setup broken"

# Live install: the hook Claude Code runs is the kit hook, and the agents are kit agents.
if [ "${THIN_ORCH_SKIP_LIVE:-0}" = 1 ]; then echo "SKIP live install"; else
  [ "$(readlink "$HOME/.claude/hooks/bash_write_task_section_only.sh")" = "$HOOK" ] && pass "live hook linked" || fail "live hook not linked to kit"
  for a in researcher spec-writer validator test-verifier; do
    [ "$(readlink "$HOME/.claude/agents/$a.md")" = "$AG/$a.md" ] && pass "live $a linked" || fail "live $a not linked to kit"
  done
fi

# validator / test-verifier: full Bash (allowed-plus), no hook, new status contracts
for a in validator test-verifier; do
  frontmatter "$AG/$a.md" | grep -q '^tools:.*\bBash\b' && pass "$a keeps Bash" || fail "$a lost Bash"
  frontmatter "$AG/$a.md" | grep -q 'PreToolUse' && fail "$a unexpectedly hook-scoped" || pass "$a not hook-scoped"
done
grep -q 'write_task_section.sh' "$AG/validator.md" && grep -q 'VERDICT:' "$AG/validator.md" && pass "validator persists + VERDICT contract" || fail "validator contract"
grep -q 'run_result: PASS|FAIL' "$AG/test-verifier.md" && pass "test-verifier run_result contract" || fail "test-verifier contract"
grep -q 'You never write the vault' "$AG/test-verifier.md" && pass "test-verifier persists nothing" || fail "test-verifier no-persist wording"
for a in researcher spec-writer validator test-verifier; do
  grep -qi 'your job is to return content, not to persist it' "$AG/$a.md" && fail "$a still says return-not-persist" || pass "$a old firewall gone"
done
finish

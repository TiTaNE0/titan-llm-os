#!/usr/bin/env bash
# test_thin_orchestrator.sh - gateway for Thin_Orchestrator_Subagent_Self_Write.
# Subagents persist their own sections via write_task_section.sh (stdin mode); the
# coordinator only checks presence. Covers: kernel sentence, execute_task.md shape,
# agent frontmatter, Bash-scoping hook decision (ALLOW/REFUSE/fail-closed/RED),
# live install symlinks, write_task_section --content-file -, and the kit/vault suites.
# THIN_ORCH_SKIP_LIVE=1 skips the symlink check; THIN_ORCH_SKIP_SUITES=1 skips suites.
set -uo pipefail
unset TITAN_SESSION_ID

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
KIT="${KIT_ROOT:-$HOME/AI_Workflow/claude-agent-kit}"
EXEC="$KIT/project-template/.claude/commands/execute_task.md"
HOOK="$KIT/global/hooks/bash_write_task_section_only.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
FAILS=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAILS=$((FAILS + 1)); }
want() { # label text pattern(fixed)
  if printf '%s\n' "$2" | grep -qF -- "$3"; then pass "$1"; else fail "$1 (missing: $3)"; fi
}
deny() {
  if printf '%s\n' "$2" | grep -qF -- "$3"; then fail "$1 (present: $3)"; else pass "$1"; fi
}

# --- DoD 1: kernel sentence ---------------------------------------------------
if grep -qF 'persist their own task section by calling `write_task_section`' "$REPO_ROOT/03_Brain/System_Agents.md"; then
  pass "DoD1 kernel sentence present"
else fail "DoD1 kernel sentence present"; fi

# --- DoD 3: execute_task.md ---------------------------------------------------
step() { awk -v a="## Step $1 " -v b="## Step $2 " 'index($0,a)==1{on=1} index($0,b)==1{on=0} on' "$EXEC"; }
S613="$(awk '/^## Step 6 /{on=1} /^## Step 14 /{on=0} on' "$EXEC" | awk '/^## Step 13 /{g=1} !g')"
S6="$(step 6 7)"; S7="$(step 7 8)"; S11="$(step 11 12)"; S12="$(step 12 13)"
for p in 'CONTENT_FILE' 'RESEARCH_EOF' '<full subagent report content>' 'Capture spec' 'Capture report'; do
  deny "DoD3 Steps 6-12 deny '$p'" "$S613" "$p"
done
want "DoD3 step6 grep_section Research Notes" "$S6" 'grep_section.sh "$TASK_PATH" "Research Notes" empty'
want "DoD3 step7 grep_section Spec" "$S7" 'grep_section.sh "$TASK_PATH" "Spec" empty'
want "DoD3 step12 grep_section Validator Report" "$S12" 'grep_section.sh "$TASK_PATH" "Validator Report" empty'
want "DoD3 step6 --content-file -" "$S6" '--content-file -'
want "DoD3 step7 --content-file -" "$S7" '--content-file -'
want "DoD3 step12 --content-file -" "$S12" '--content-file -'
want "DoD3 step6 spec_gate" "$S6" '--state spec_gate'
want "DoD3 step7 spec_gate" "$S7" '--state spec_gate'
want "DoD3 step12 close_gate" "$S12" '--state close_gate'
want "DoD3 step11 run_result" "$S11" 'run_result: PASS'
want "DoD3 step12 VERDICT" "$S12" 'VERDICT:'

# --- DoD 2: agent frontmatter / bodies ----------------------------------------
fm() { awk '/^---[ \t\r]*$/{n++; next} n==1' "$1"; }
for dir in global/agents docs/cld; do
  for a in researcher spec-writer; do
    f="$KIT/$dir/$a.md"; F="$(fm "$f")"
    if printf '%s\n' "$F" | grep -E '^tools:' | grep -qw Bash; then pass "DoD2 $dir/$a tools has Bash"; else fail "DoD2 $dir/$a tools has Bash"; fi
    want "DoD2 $dir/$a PreToolUse" "$F" 'PreToolUse'
    want "DoD2 $dir/$a matcher" "$F" 'matcher: "Bash"'
    want "DoD2 $dir/$a hook command" "$F" 'bash_write_task_section_only.sh" || exit 2'
  done
  F="$(fm "$KIT/$dir/validator.md")"
  if printf '%s\n' "$F" | grep -E '^tools:' | grep -qw Bash; then pass "DoD2 $dir/validator tools has Bash"; else fail "DoD2 $dir/validator tools has Bash"; fi
  B="$(cat "$KIT/$dir/validator.md")"
  want "DoD2 $dir/validator write_task_section" "$B" 'write_task_section.sh'
  want "DoD2 $dir/validator VERDICT" "$B" 'VERDICT:'
  want "DoD2 $dir/test-verifier run_result" "$(cat "$KIT/$dir/test-verifier.md")" 'run_result:'
done
for a in researcher spec-writer validator test-verifier; do
  deny "DoD2 global/$a drops 'return content, not to persist it'" "$(cat "$KIT/global/agents/$a.md")" 'your job is to return content, not to persist it'
done

# --- DoD 2: hook decision -----------------------------------------------------
decide() { # hook cmd -> exit code of hook for a Bash tool call
  jq -n --arg c "$2" '{tool_name:"Bash",agent_type:"researcher",tool_input:{command:$c}}' | bash "$1" >/dev/null 2>&1
  echo $?
}
expect() { # kind label cmd
  local rc; rc="$(decide "$HOOK" "$3")"
  case "$1" in
    allow) [ "$rc" = 0 ] && pass "hook ALLOW $2" || fail "hook ALLOW $2 (rc=$rc)" ;;
    refuse) [ "$rc" = 2 ] && pass "hook REFUSE $2" || fail "hook REFUSE $2 (rc=$rc)" ;;
  esac
}
W='.vault_link/.scripts/write_task_section.sh'
A="--task-path .vault_link/02_Tasks/P/T.md --section spec --source-persona Executioner --content-file -"
if [ -f "$HOOK" ] && command -v jq >/dev/null 2>&1; then
  expect allow "single-line file mode" "$W --task-path x.md --section spec --source-persona Executioner --content-file y"
  expect allow "heredoc with hostile body" "$W $A <<'SPEC_EOF'
body; rm -rf /
\$(id)
\`id\`
x | sh
SPEC_EOF"
  expect allow "bash prefix" "bash $W $A <<'E_EOF'
hi
E_EOF"
  expect allow ".scripts form" ".scripts/write_task_section.sh $A <<'E_EOF'
hi
E_EOF"
  expect allow "--overwrite" "$W $A --overwrite <<'E_EOF'
hi
E_EOF"
  expect allow "double-quoted task path" "$W --task-path \".vault_link/02_Tasks/P/T.md\" --section spec --source-persona Executioner --content-file - <<'E_EOF'
hi
E_EOF"
  expect refuse "comment before heredoc" "$W $A # <<'D'
id
D"
  expect refuse "heredoc inside open double quote" "$W --task-path \"x <<'D'
id
D"
  expect refuse "heredoc inside open single quote" "$W --task-path 'x <<'D'
id
D"
  expect refuse "CR after heredoc op" "$W $A <<'D'$'\r'
id
D"
  expect refuse "FF after heredoc op" "$W $A <<'D'$'\f'
id
D"
  expect refuse "VT after heredoc op" "$W $A <<'D'$'\v'
id
D"
  expect refuse "NBSP after heredoc op" "$W $A <<'D'"$'\xc2\xa0'"
id
D"
  expect refuse "tab in command line" "$W"$'\t'"$A"
  expect refuse "ls -la" "ls -la"
  expect refuse "rm -rf" "rm -rf /tmp/x"
  expect refuse "cat passwd" "cat /etc/passwd"
  expect refuse "chained ;" "$W $A; rm x"
  expect refuse "chained &&" "$W $A && curl x"
  expect refuse "piped" "$W $A | sh"
  expect refuse "cmd subst arg" "$W --task-path \$(id) --section spec"
  expect refuse "backtick arg" "$W --task-path \`id\` --section spec"
  expect refuse "redirect" "$W $A > /tmp/x"
  expect refuse "unquoted heredoc" "$W $A <<EOF
hi
EOF"
  expect refuse "double-quoted heredoc" "$W $A <<\"EOF\"
hi
EOF"
  expect refuse "<<- heredoc" "$W $A <<-'EOF'
hi
EOF"
  expect refuse "delimiter mid-body" "$W $A <<'E_EOF'
a
E_EOF
rm -rf /
E_EOF"
  expect refuse "missing terminator" "$W $A <<'E_EOF'
hi"
  expect refuse "multi-line without heredoc" "$W $A
rm x"
  expect refuse "other script" ".vault_link/.scripts/update_kanban.sh $A"
  expect refuse "/tmp script" "/tmp/write_task_section.sh $A"
  expect refuse "foreign prefix" "evil/.scripts/write_task_section.sh $A"
  expect refuse "dotdot path" ".vault_link/.scripts/../x/write_task_section.sh $A"
  expect refuse "empty command" ""
  rc="$(printf 'not json' | bash "$HOOK" >/dev/null 2>&1; echo $?)"
  [ "$rc" = 2 ] && pass "hook REFUSE malformed JSON" || fail "hook REFUSE malformed JSON (rc=$rc)"
  rc="$(jq -n '{tool_name:"Read",tool_input:{}}' | bash "$HOOK" >/dev/null 2>&1; echo $?)"
  [ "$rc" = 0 ] && pass "hook ALLOW non-Bash tool" || fail "hook ALLOW non-Bash tool (rc=$rc)"
else
  fail "hook present and jq available ($HOOK)"
fi
rc="$( (bash /nonexistent/h.sh >/dev/null 2>&1 || exit 2); echo $?)"
[ "$rc" = 2 ] && pass "fail-closed: missing hook -> 2" || fail "fail-closed: missing hook -> 2 (rc=$rc)"
printf '#!/usr/bin/env bash\nexit 0\n' > "$TMP/stub.sh"
if [ "$(decide "$TMP/stub.sh" 'ls -la')" = 0 ]; then pass "RED: always-allow stub detected accepting 'ls -la'"; else fail "RED stub detection"; fi

# --- live install ---------------------------------------------------------------
if [ "${THIN_ORCH_SKIP_LIVE:-0}" = 1 ]; then
  echo "SKIP: live install symlinks"
else
  [ "$(readlink "$HOME/.claude/hooks/bash_write_task_section_only.sh" 2>/dev/null)" = "$HOOK" ] \
    && pass "live hook symlink" || fail "live hook symlink (run install.sh setup-global)"
  [ "$(readlink "$HOME/.claude/agents/researcher.md" 2>/dev/null)" = "$KIT/global/agents/researcher.md" ] \
    && pass "live researcher symlink" || fail "live researcher symlink"
fi

# --- write_task_section stdin mode ---------------------------------------------
V="$TMP/vault"; TD="$TMP/td"; mkdir -p "$V/.scripts" "$V/04_Logs/Telemetry" "$TD"
printf '{\n  "persona": "Executioner",\n  "session_id": "smoke",\n  "started_at": "2026-06-17T00:00:00Z",\n  "agent_surface": "test"\n}\n' > "$V/.session_state.json"
for s in write_task_section lib_section persona_check emit_telemetry; do cp "$REPO_ROOT/.scripts/$s.sh" "$V/.scripts/"; done
chmod +x "$V/.scripts/"*.sh
mk_task() {
  cat > "$1" <<'T_EOF'
---
project: [[P]]
status: todo
type: task
---
# Task: T

## 📋 Declarative Objective
- [ ] x

## 🔬 Research Notes
> placeholder
<!-- write_task_section section=research_notes -->

## 📐 Spec
> placeholder
<!-- write_task_section section=spec -->

## ✅ Validator Report
> placeholder
<!-- write_task_section section=validator_report -->

## 📊 Verification Output
> placeholder
<!-- write_task_section section=verification_output -->
T_EOF
}
WTS="$V/.scripts/write_task_section.sh"
T="$TD/T.md"; mk_task "$T"
export TMPDIR="$TMP/tmpdir"; mkdir -p "$TMPDIR"
rc=0; "$WTS" --task-path "$T" --section spec --source-persona Executioner --content-file - >/dev/null 2>&1 <<'C_EOF' || rc=$?
### Summary
literal $(id) and `id` stay verbatim
C_EOF
[ "$rc" = 0 ] && pass "stdin heredoc -> 0" || fail "stdin heredoc -> 0 (rc=$rc)"
want "stdin content verbatim" "$(cat "$T")" 'literal $(id) and `id` stay verbatim'
[ "$(grep -n 'section=spec' "$T" | cut -d: -f1)" -lt "$(grep -n 'literal \$(id)' "$T" | cut -d: -f1)" ] && pass "content under anchor" || fail "content under anchor"
rc=0; printf '  \n\n' | "$WTS" --task-path "$T" --section research_notes --source-persona Executioner --content-file - >/dev/null 2>&1 || rc=$?
[ "$rc" = 1 ] && pass "empty stdin -> 1" || fail "empty stdin -> 1 (rc=$rc)"
rc=0; echo again | "$WTS" --task-path "$T" --section spec --source-persona Executioner --content-file - >/dev/null 2>&1 || rc=$?
[ "$rc" = 3 ] && pass "populated w/o --overwrite -> 3" || fail "populated w/o --overwrite -> 3 (rc=$rc)"
rc=0; echo replaced | "$WTS" --task-path "$T" --section spec --source-persona Executioner --content-file - --overwrite >/dev/null 2>&1 || rc=$?
[ "$rc" = 0 ] && grep -q '^replaced$' "$T" && ! grep -q 'stay verbatim' "$T" && pass "--overwrite replaces" || fail "--overwrite replaces (rc=$rc)"
echo filebody > "$TD/c.txt"
rc=0; "$WTS" --task-path "$T" --section validator_report --source-persona Executioner --content-file "$TD/c.txt" >/dev/null 2>&1 || rc=$?
[ "$rc" = 0 ] && grep -q '^filebody$' "$T" && pass "file mode -> 0" || fail "file mode -> 0 (rc=$rc)"
rc=0; echo x | "$WTS" --task-path "$T" --section verification_output --source-persona Architect --content-file - >/dev/null 2>&1 || rc=$?
[ "$rc" = 4 ] && pass "persona Architect + stdin -> 4" || fail "persona Architect + stdin -> 4 (rc=$rc)"
if ls "$TMPDIR"/wts_stdin.* >/dev/null 2>&1; then fail "no wts_stdin.* left"; else pass "no wts_stdin.* left"; fi
unset TMPDIR

# --- DoD 4: suites -------------------------------------------------------------
if [ "${THIN_ORCH_SKIP_SUITES:-0}" = 1 ]; then
  echo "SKIP: suites"
else
  for t in "$KIT"/tests/test_*.sh; do
    ( cd "$KIT" && CLAUDE_BIN=__nonexistent__ bash "$t" >/dev/null 2>&1 ) && pass "kit $(basename "$t")" || fail "kit $(basename "$t")"
  done
  for t in test_telemetry_duration_task_field test_section_extent test_commit_task; do
    ( cd "$REPO_ROOT" && bash "tests/$t.sh" >/dev/null 2>&1 ) && pass "vault $t" || fail "vault $t"
  done
fi

# --- DoD 5 (informational) -----------------------------------------------------
echo "coordinator_turns: ${THIN_ORCH_COORDINATOR_TURNS:-not-provided}"
if [ "$FAILS" -eq 0 ]; then echo "ALL GREEN"; exit 0; fi
echo "$FAILS check(s) failed"; exit 1

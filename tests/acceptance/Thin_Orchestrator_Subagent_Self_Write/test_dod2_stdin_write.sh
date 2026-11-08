#!/usr/bin/env bash
# DoD 2: write_task_section.sh --content-file - (stdin) lets a Bash-scoped subagent persist
# its own section. Runs the real script in a mktemp vault.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
V="$TMP/v"; mk_vault "$V"; cd "$V" || exit 1
unset TITAN_SESSION_ID
T="$V/02_Tasks/P/T.md"
W="$V/.scripts/write_task_section.sh"
wts() { "$W" --task-path "$T" --source-persona Executioner --content-file - "$@" >/dev/null 2>"$TMP/err"; echo $?; }

rc="$(wts --section research_notes <<'X'
### Findings
literal $(id) `whoami` ${HOME} \n stays verbatim
X
)"
[ "$rc" = 0 ] && pass "stdin heredoc -> exit 0" || fail "stdin write rc=$rc: $(cat "$TMP/err")"
section_body "$T" research_notes | grep -qF 'literal $(id) `whoami` ${HOME} \n stays verbatim' \
  && pass "content verbatim under anchor" || fail "content not verbatim: $(section_body "$T" research_notes)"
section_body "$T" research_notes | grep -q '^### Findings$' && pass "agent sub-heading kept" || fail "sub-heading lost"
grep -c '^## 📐 Spec$' "$T" | grep -q '^1$' && pass "following section intact" || fail "spec heading damaged"

rc="$(printf '' | wts --section spec)"
[ "$rc" = 1 ] && grep -q 'E1: content from stdin is empty' "$TMP/err" && pass "empty stdin -> E1 (1)" || fail "empty stdin rc=$rc"
rc="$(printf '  \n\t\n' | wts --section spec)"
[ "$rc" = 1 ] && pass "whitespace-only stdin -> E1 (1)" || fail "whitespace stdin rc=$rc"
! section_body "$T" spec | grep -q '[^[:space:]]' && pass "spec untouched after empty writes" || fail "spec changed by failed write"

rc="$(echo second | wts --section research_notes)"
[ "$rc" = 3 ] && pass "populated w/o --overwrite -> E3 (3)" || fail "no-overwrite rc=$rc"
section_body "$T" research_notes | grep -q 'stays verbatim' && pass "original kept on E3" || fail "E3 changed content"
rc="$(echo replaced-body | wts --section research_notes --overwrite)"
[ "$rc" = 0 ] && section_body "$T" research_notes | grep -q '^replaced-body$' && ! section_body "$T" research_notes | grep -q 'verbatim' \
  && pass "--overwrite replaces" || fail "overwrite rc=$rc"

echo file-mode-body > "$TMP/c.md"
rc="$("$W" --task-path "$T" --section validator_report --source-persona Executioner --content-file "$TMP/c.md" 2>/dev/null; echo $?)"
[ "$rc" = 0 ] && section_body "$T" validator_report | grep -q file-mode-body && pass "file mode unchanged" || fail "file mode rc=$rc"

rc="$(echo x | "$W" --task-path "$T" --section verification_output --source-persona Architect --content-file - 2>/dev/null; echo $?)"
[ "$rc" = 4 ] && pass "persona Architect + stdin -> E4" || fail "Architect rc=$rc"
sed -i '' 's/"Executioner"/"Architect"/' "$V/.session_state.json"
rc="$(echo x | wts --section verification_output)"
[ "$rc" = 4 ] && pass "live persona not Executioner + stdin -> E4" || fail "live persona rc=$rc"
sed -i '' 's/"Architect"/"Executioner"/' "$V/.session_state.json"
! section_body "$T" verification_output | grep -q '[^[:space:]]' && pass "E4 wrote nothing" || fail "E4 wrote content"

left="$(ls "$TMPDIR" | grep -c '^wts_stdin\.' || true)"
[ "$left" = 0 ] && pass "no wts_stdin.* temp left (success + E1/E3/E4 paths)" || fail "$left wts_stdin temp(s) left"
ls "$V/02_Tasks/P" | grep -qv '^T\.md$' && fail "stray temp next to task: $(ls "$V/02_Tasks/P")" || pass "no stray task temp"
finish

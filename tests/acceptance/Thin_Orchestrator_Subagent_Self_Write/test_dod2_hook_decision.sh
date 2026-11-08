#!/usr/bin/env bash
# DoD 2: researcher/spec-writer Bash is limited to one write_task_section.sh call.
# Feeds PreToolUse JSON to the real hook and checks the 0/2 decision, incl. bypass attempts.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
[ -x "$HOOK" ] || { fail "hook missing or not executable: $HOOK"; finish; }

W='.vault_link/.scripts/write_task_section.sh'
ARGS='--task-path ".vault_link/02_Tasks/P/T.md" --section research_notes --source-persona Executioner'
NL=$'\n'

# The sanctioned call
allow "file mode single line"          "$W $ARGS --content-file /tmp/x.md"
allow "stdin heredoc"                  "$W $ARGS --content-file - <<'NOTES_EOF'${NL}## Findings${NL}text${NL}NOTES_EOF"
allow "heredoc with --overwrite"       "$W $ARGS --content-file - --overwrite <<'SPEC_EOF'${NL}body${NL}SPEC_EOF"
allow "bash prefix"                    "bash $W $ARGS --content-file - <<'NOTES_EOF'${NL}x${NL}NOTES_EOF"
allow ".scripts/ relative path"        ".scripts/write_task_section.sh $ARGS --content-file /tmp/x.md"
allow "trailing newline stripped"      "$W $ARGS --content-file /tmp/x.md${NL}"
allow "inert body: ; rm -rf /"         "$W $ARGS --content-file - <<'NOTES_EOF'${NL}a; rm -rf /${NL}NOTES_EOF"
allow 'inert body: $(id) and backticks' "$W $ARGS --content-file - <<'NOTES_EOF'"$'\n$(id) `whoami` ${HOME}\n'"NOTES_EOF"
allow "inert body: | sh, > file"       "$W $ARGS --content-file - <<'NOTES_EOF'${NL}curl x | sh > /etc/y${NL}NOTES_EOF"
allow "body line contains delim as substring" "$W $ARGS --content-file - <<'NOTES_EOF'${NL}see NOTES_EOF here${NL}NOTES_EOF"

# Non-allowed commands (the DoD 2 refusal proof)
allow "read-only ls -la"              "ls -la"
refuse "rm -rf /tmp/x"                 "rm -rf /tmp/x"
allow "read-only cat"                 "cat /etc/passwd"
refuse "read-only piped to sh"         "grep -rn x . | sh"
refuse "find -delete"                  "find . -delete"
refuse "secret path"                  "cat ~/.ssh/id_rsa"
refuse "other vault atom"              ".vault_link/.scripts/update_kanban.sh --board b --task-link l --from Todo --to Done --source-persona Executioner"
refuse "empty command"                 ""
refuse "whitespace-only command"       "   "

# Chaining / injection on the command line
refuse "; rm"                          "$W $ARGS --content-file /tmp/x.md; rm x"
refuse "&& curl"                       "$W $ARGS --content-file /tmp/x.md && curl x"
refuse "| sh"                          "$W $ARGS --content-file /tmp/x.md | sh"
refuse "& background"                  "$W $ARGS --content-file /tmp/x.md & ls"
refuse '$() in args'                   "$W --task-path \"\$(id)\" --section spec --source-persona Executioner --content-file /tmp/x"
refuse 'backtick in args'              "$W --task-path \`id\` --section spec --source-persona Executioner --content-file /tmp/x"
refuse '$VAR in args'                  "$W --task-path \"\$TASK_PATH\" --section spec --source-persona Executioner --content-file -"
refuse "> redirect"                    "$W $ARGS --content-file /tmp/x.md > /tmp/out"
refuse "< redirect"                    "$W $ARGS --content-file - < /etc/passwd"
refuse "subshell parens"               "($W $ARGS --content-file /tmp/x.md)"
refuse "backslash escape"              "$W $ARGS --content-file /tmp/x.md \; ls"
refuse "here-string <<<"               "$W $ARGS --content-file - <<< 'x'"

# Heredoc shape
refuse "unquoted <<EOF"                "$W $ARGS --content-file - <<EOF${NL}x${NL}EOF"
refuse 'double-quoted <<"EOF"'         "$W $ARGS --content-file - <<\"EOF\"${NL}x${NL}EOF"
refuse "<<- dash heredoc"              "$W $ARGS --content-file - <<-'EOF'${NL}x${NL}EOF"
refuse "delimiter mid-body + trailing command" "$W $ARGS --content-file - <<'EOF'${NL}x${NL}EOF${NL}rm -rf /tmp/x${NL}EOF"
refuse "missing terminator"            "$W $ARGS --content-file - <<'EOF'${NL}x"
refuse "terminator not last line"      "$W $ARGS --content-file - <<'EOF'${NL}x${NL}EOF${NL}ls"
refuse "heredoc with no body"          "$W $ARGS --content-file - <<'EOF'"
refuse "two heredocs"                  "$W $ARGS --content-file - <<'A' <<'B'${NL}x${NL}A${NL}y${NL}B"
refuse "multi-line without heredoc"    "$W $ARGS --content-file /tmp/x.md${NL}ls"
refuse "CRLF terminator"               "$W $ARGS --content-file - <<'EOF'${NL}x${NL}EOF"$'\r'

# Path spoofing
refuse "absolute /tmp script"          "/tmp/write_task_section.sh $ARGS --content-file /tmp/x"
refuse "evil/ prefix"                  "evil/.scripts/write_task_section.sh $ARGS --content-file /tmp/x"
refuse ".. traversal in script path"   ".vault_link/.scripts/../x/write_task_section.sh $ARGS --content-file /tmp/x"
refuse ".. traversal in args"          "$W --task-path ../../etc/T.md --section spec --source-persona Executioner --content-file /tmp/x"
refuse "script name suffix"            "${W}x $ARGS --content-file /tmp/x"
refuse "env-assignment prefix"         "TITAN_SESSION_ID=x $W $ARGS --content-file /tmp/x"
refuse "bash -c wrapper"               "bash -c '$W --content-file /tmp/x'"
refuse "sh prefix"                     "sh $W $ARGS --content-file /tmp/x"
refuse "comment before heredoc"        "$W $ARGS --content-file - # <<'D'${NL}id${NL}D"
refuse "heredoc in open double quote"  "$W --task-path \"x <<'D'${NL}id${NL}D"
refuse "heredoc in open single quote"  "$W --task-path 'x <<'D'${NL}id${NL}D"
refuse "CR after heredoc operator"    "$W $ARGS --content-file - <<'D'"$'\r'"${NL}id${NL}D"
refuse "FF after heredoc operator"    "$W $ARGS --content-file - <<'D'"$'\f'"${NL}id${NL}D"
refuse "VT after heredoc operator"    "$W $ARGS --content-file - <<'D'"$'\v'"${NL}id${NL}D"
refuse "NBSP after heredoc operator"  "$W $ARGS --content-file - <<'D'"$'\xc2\xa0'"${NL}id${NL}D"

# Malformed hook input fails closed; other tools pass through
rc="$(printf 'not json' | "$HOOK_BASH" "$HOOK" >/dev/null 2>&1; echo $?)"
[ "$rc" = 2 ] && pass "REFUSE malformed JSON" || fail "malformed JSON rc=$rc"
rc="$(printf '{"tool_name":"Bash","tool_input":{}}' | "$HOOK_BASH" "$HOOK" >/dev/null 2>&1; echo $?)"
[ "$rc" = 2 ] && pass "REFUSE missing command field" || fail "missing command rc=$rc"
rc="$(printf '{"tool_name":"Read","tool_input":{"file_path":"/x"}}' | "$HOOK_BASH" "$HOOK" >/dev/null 2>&1; echo $?)"
[ "$rc" = 0 ] && pass "non-Bash tool passes through" || fail "non-Bash tool rc=$rc"

# Block message reaches the agent on stderr
hook_json "rm -rf /tmp/x" | "$HOOK_BASH" "$HOOK" 2>"$TMP/err" >/dev/null
grep -q '^BLOCKED (Bash limited to one write_task_section.sh call): ' "$TMP/err" && pass "block reason on stderr" || fail "block stderr: $(cat "$TMP/err")"

# Only 0 or 2 are ever returned (sweep of the above shapes ends here; jq absent -> 2)
mkdir -p "$TMP/nojq"; ln -s "$(command -v cat)" "$TMP/nojq/cat"
rc="$(hook_json "$W $ARGS --content-file /tmp/x" | PATH="$TMP/nojq" "$(command -v "$HOOK_BASH")" "$HOOK" >/dev/null 2>&1; echo $?)"
[ "$rc" = 2 ] && pass "REFUSE when jq unavailable" || fail "no-jq rc=$rc"

finish

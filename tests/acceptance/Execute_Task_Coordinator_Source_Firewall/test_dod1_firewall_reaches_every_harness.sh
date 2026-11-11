#!/usr/bin/env bash
# DoD1: the coordinator source firewall is text in the HARD RULE that every harness receives,
# not a frontmatter tool ban: the Claude Code command (vault symlink) and the generated
# OpenCode command both carry the same paragraph, and it names non-Claude tool names and Bash writes.
. "$(dirname "$0")/_lib.sh"

[ "$ET" -ef "$KIT/project-template/.claude/commands/execute_task.md" ] \
  && pass "vault execute_task.md resolves to the kit runbook" || fail "vault execute_task.md is not the kit runbook symlink"

section "$ET" '^## HARD RULE' > "$TMP/hard"
FW="$(grep -F '**Coordinator source firewall (every harness).**' "$TMP/hard")"
[ -n "$FW" ] && pass "firewall paragraph sits inside the HARD RULE block" || fail "firewall paragraph not inside HARD RULE"

# One sentence forbids every tool family the Grok incident used (write, search_replace, rm) plus the rest.
S="$(printf '%s' "$FW" | grep -oE 'never creates, edits or deletes repo source[^.]*\.')"
for t in '`Edit`' '`Write`' '`write`' '`search_replace`' '`apply_patch`' '`>`' '`rm`' '`mv`' '`sed -i`' 'any other file tool' 'under any harness or tool name'; do
  case "$S" in *"$t"*) pass "prohibition sentence covers $t" ;; *) fail "prohibition sentence misses $t" ;; esac
done
case "$FW" in *'`disallowed-tools` is not enforced on every harness'*'this text is the rule'*) pass "states frontmatter is not the enforcement" ;; *) fail "missing 'disallowed-tools not enforced ... this text is the rule'" ;; esac
case "$FW" in *'only from the builder subagents'*) pass "source changes come only from builders" ;; *) fail "missing 'only from the builder subagents'" ;; esac

# Non-Claude harness: OpenCode's generated command must carry the identical paragraph.
grep -qxF -- "$FW" "$OC_CMD/execute_task.md" 2>/dev/null && pass "OpenCode execute_task carries the identical firewall paragraph" \
  || fail "OpenCode execute_task lacks the firewall paragraph (run install.sh setup-opencode)"
done_

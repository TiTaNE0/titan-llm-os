#!/usr/bin/env bash
# DoD 3: the gateway pins both contracts by grep. Run it against a scratch copy of the kit:
# green on the shipped files, red on each contract regression.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

[ -f "$GATEWAY" ] && pass "gateway test exists" || { fail "gateway missing: $GATEWAY"; finish; }

mk_kit() { # <dir>: kit copy holding only the files the gateway pins
  mkdir -p "$1/global/agents" "$1/docs/cld" "$1/project-template/.claude/commands" "$1/tests"
  cp "$PMR" "$1/global/agents/"; cp "$PMR_DOC" "$1/docs/cld/"; cp "$EXEC_MD" "$1/project-template/.claude/commands/"
}
gw() { ( cd "$VAULT" && KIT_ROOT="$1" PMR_SKIP_SUITES=1 bash "$GATEWAY" >"$TMP/gw_out" 2>&1 ); echo $?; }

K="$TMP/k0"; mk_kit "$K"
expect "gateway green on shipped contracts" 0 "$(gw "$K")"
grep -qx 'SKIP: suites' "$TMP/gw_out" && pass "PMR_SKIP_SUITES=1 skips suites" || fail "skip mode did not print SKIP: suites"
grep -qx 'ALL GREEN' "$TMP/gw_out" && pass "gateway prints ALL GREEN" || fail "gateway did not print ALL GREEN"

# red <label> <relpath> <sed-expr>: mutate one pinned file; the gateway must exit 1.
red() {
  local k="$TMP/k$RANDOM$RANDOM"; mk_kit "$k"
  sed -E "$3" "$k/$2" > "$k/$2.new" && mv "$k/$2.new" "$k/$2"
  cmp -s "$k/$2" "$(case "$2" in global/*) echo "$PMR";; docs/*) echo "$PMR_DOC";; *) echo "$EXEC_MD";; esac)" \
    && { fail "RED $1: mutation did not change the file"; return; }
  expect "RED $1 -> gateway exit 1" 1 "$(gw "$k")"
}
P=global/agents/pm-reviewer.md; E=project-template/.claude/commands/execute_task.md
red "single-pass sentence dropped" $P '/List every finding in one pass/d'
red "numbered list dropped" $P 's/numbered list/list/g'
red "class label dropped ([scope creep])" $P '/\[scope creep\]/d'
red "exclusion sentence dropped" $P '/Style and hypothetical-misuse findings are excluded/d'
red "re-review scope dropped (reviewer)" $P 's/check only those findings plus regressions/check findings/'
red "old one-line verdict reintroduced" $P 's/^Your final message IS the verdict.*/Return EXACTLY one line: `FLAG: <one-line reason>`/'
red "docs twin drifts from global" docs/cld/pm-reviewer.md '$ s/$/ /'
red "model changed" $P 's/^model: opus/model: sonnet/'
red "one-resume rule dropped" $E 's/in one resume/in one message/'
red "full-list rule dropped" $E 's/full numbered findings list/first finding/'
red "re-review scope dropped (Step 8)" $E 's/check only those findings plus regressions/re-check the spec/'
red "revision bound dropped" $E 's/at most 2 revisions/at most N revisions/'
red "planner re-spawned instead of resumed" $E 's/then resume the planner agent started in Step 6/then spawn `planner` again/'
red "rubric re-run dropped" $E '/^4\. Re-run `.vault_link\/.scripts\/spec_rubric.sh/d'
red "interactive gate removed" $E 's/\*\*Do not proceed until the user approves\.\*\*//'

# Aggregator wiring: test_chain_consolidation.sh runs this gateway in skip mode (no recursion / double run).
grep -qF '[ "$b" = test_pm_reviewer_single_pass.sh ] && envp="PMR_SKIP_SUITES=1"' "$VAULT/tests/test_chain_consolidation.sh" \
  && pass "aggregator runs gateway with PMR_SKIP_SUITES=1" || fail "aggregator lacks PMR_SKIP_SUITES=1 for the gateway"
finish

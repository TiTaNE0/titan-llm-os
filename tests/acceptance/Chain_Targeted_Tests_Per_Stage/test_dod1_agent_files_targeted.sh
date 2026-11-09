#!/usr/bin/env bash
# DoD 1 (agent files): builder, backend-builder, frontend-builder, test-verifier and validator
# carry the targeted-test rule on their test-run item, scoped to /execute_task, so /feature,
# /bugfix and /quick keep running the full suite.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
# item_has <label> <file> <item-prefix-regex> <sentence>
item_has() {
  local l; l="$(grep -E -- "$3" "$2" | head -1)"
  [ -n "$l" ] || { fail "$1: item $3 not found"; return; }
  [[ "$l" == *"$4" ]] && pass "$1 test item ends with the scoped targeted rule" || fail "$1 test item lacks the scoped targeted rule"
}
item_has builder "$AG/builder.md" '^6\. Run typecheck, lint' " $A_BUILDER"
item_has backend-builder "$AG/backend-builder.md" '^5\. Run typecheck, lint' " $A_BUILDER"
item_has frontend-builder "$AG/frontend-builder.md" '^7\. Run typecheck, lint' " $A_BUILDER"
for a in builder backend-builder frontend-builder; do
  has "$a keeps its general test rule" "$(cat "$AG/$a.md")" 'Run typecheck, lint, and'
done

TVW="$(awk '/^## What you do$/{on=1;next} /^## /{on=0} on' "$AG/test-verifier.md")"
has "test-verifier 'What you do' item 7" "$TVW" "$A_TV7"

V4="$(grep -E '^4\. Run typecheck, lint' "$AG/validator.md")"
has "validator item 4 keeps the full suite outside /execute_task" "$V4" 'Run typecheck, lint, the full test suite (under `/execute_task`: only targeted tests, meaning the tests for the files the builders changed plus the task'"'"'s Verification Gateway command in its skip mode; do not run the full kit or vault suite loops, the gateway step runs them once), **and the project'"'"'s production build'
has "validator Verification section scoped" "$(cat "$AG/validator.md")" 'full test suite (targeted tests under `/execute_task`)'

# Every new sentence in all five files is scoped to /execute_task.
bad="$(grep -hiE 'only targeted tests|nested full-gateway run' "$AG"/{builder,backend-builder,frontend-builder,test-verifier,validator}.md | grep -vcF '/execute_task')"
expect "unscoped targeted-test lines" 0 "$bad"

# Frontmatter unchanged versus the kit's last commit.
fm() { awk 'NR==1&&/^---$/{on=1;print;next} on{print} on&&/^---$/{exit}' "$1"; }
for a in builder backend-builder frontend-builder test-verifier validator; do
  head_fm="$(git -C "$KIT" show "HEAD:global/agents/$a.md" 2>/dev/null | awk 'NR==1&&/^---$/{on=1;print;next} on{print} on&&/^---$/{exit}')"
  [ -n "$head_fm" ] || { fail "$a: no HEAD frontmatter to compare"; continue; }
  expect "$a frontmatter unchanged" "$head_fm" "$(fm "$AG/$a.md")"
done
for p in 'run_result: PASS|FAIL' 'You never write the vault'; do has "test-verifier keeps '$p'" "$(cat "$AG/test-verifier.md")" "$p"; done
for p in '**Role conflicts**' 'FIX REQUIRED' 'BLOCK' 'write_task_section.sh' 'VERDICT:'; do has "validator keeps '$p'" "$(cat "$AG/validator.md")" "$p"; done
finish

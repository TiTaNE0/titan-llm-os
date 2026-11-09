#!/usr/bin/env bash
# DoD 3: planner/builder agent files carry tier aliases only; install.sh role lists cover every
# agent file exactly once with planner as gate and builder as worker.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

fm() { awk -v k="$2" '/^---$/{c++; next} c==1 && $0 ~ "^"k":" {sub("^"k":[[:space:]]*",""); print; exit}' "$1"; }
expect "planner.md model (gate tier alias)" opus "$(fm "$AGENTS/planner.md" model)"
expect "builder.md model (worker tier alias)" sonnet "$(fm "$AGENTS/builder.md" model)"
for a in planner builder; do
  c="$(grep -cE '^model:' "$AGENTS/$a.md" || true)"
  expect "$a.md has exactly one model line" 1 "$c"
  grep -qE '^model:[[:space:]]*[^[:space:]]*/' "$AGENTS/$a.md" && fail "$a.md model is a provider/model string" || pass "$a.md model has no provider/model string"
done
expect "planner tools are read-only + Bash" "Read, Grep, Glob, Bash" "$(fm "$AGENTS/planner.md" tools)"
expect "builder tools include Edit/Write" "Read, Edit, Write, Bash, Grep, Glob" "$(fm "$AGENTS/builder.md" tools)"

# planner's Bash is hook-limited exactly like researcher's.
hookline() { grep -E '^[[:space:]]+command:' "$1"; }
expect "planner PreToolUse hook identical to researcher's" "$(hookline "$AGENTS/researcher.md")" "$(hookline "$AGENTS/planner.md")"
grep -qF 'bash_write_task_section_only.sh' "$AGENTS/planner.md" && pass "planner hook script named" || fail "planner hook script missing"
grep -q 'hooks:' "$AGENTS/builder.md" && fail "builder must not be hook-limited" || pass "builder carries no write-limiting hook"

# Planner output contract the rubric depends on.
for s in '### Responsibility map' 'name the file that currently owns it' '### Context pack' 'Build split: none' 'Build split: backend-frontend' 'WROTE spec (exit 0)'; do
  grep -qF -- "$s" "$AGENTS/planner.md" && pass "planner.md contains '$s'" || fail "planner.md lacks '$s'"
done
grep -qiF 'context pack' "$AGENTS/builder.md" && pass "builder reads the context pack" || fail "builder.md never mentions the context pack"

# install.sh role lists: parse by sourcing just the two assignments.
ROLES="$(grep -E '^OPENCODE_(GATE|WORKER)_ROLES=' "$KIT/install.sh")"
eval "$ROLES"
case " $OPENCODE_GATE_ROLES " in *" planner "*) pass "planner is a gate role in install.sh";; *) fail "planner not in OPENCODE_GATE_ROLES";; esac
case " $OPENCODE_WORKER_ROLES " in *" builder "*) pass "builder is a worker role in install.sh";; *) fail "builder not in OPENCODE_WORKER_ROLES";; esac
LISTED="$(printf '%s\n' $OPENCODE_GATE_ROLES $OPENCODE_WORKER_ROLES | sort)"
expect "no role listed twice" "$(printf '%s\n' "$LISTED" | sort -u)" "$LISTED"
FILES="$(ls "$AGENTS"/*.md | sed 's#.*/##; s/\.md$//' | sort)"
expect "role lists == agent files (11)" "$FILES" "$LISTED"
expect "agent file count" 11 "$(printf '%s\n' "$FILES" | wc -l | tr -d ' ')"
grep -qF 'all 11 agent files' "$KIT/install.sh" && pass "install.sh usage says 11 agent files" || fail "install.sh usage not updated to 11"
finish

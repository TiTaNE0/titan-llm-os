#!/usr/bin/env bash
# DoD 1: kernel § 1.5 lists planner as a gate class and builder as a worker class (read-only check).
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
K="$VAULT/03_Brain/System_Agents.md"
S15="$(awk '/^### 1\.5 /{on=1;print;next} on && /^##+ /{exit} on{print}' "$K")"
[ -n "$S15" ] || fail "kernel § 1.5 not found"
printf '%s\n' "$S15" | grep -qF 'spec-writer, planner, pm-reviewer' && pass "planner listed with gate roles in § 1.5" || fail "§ 1.5 gate list lacks planner"
printf '%s\n' "$S15" | grep -qF 'story-writer, builder, backend-builder' && pass "builder listed with worker roles in § 1.5" || fail "§ 1.5 worker list lacks builder"
finish

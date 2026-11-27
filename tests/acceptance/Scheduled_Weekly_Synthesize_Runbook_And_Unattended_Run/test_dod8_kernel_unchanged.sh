#!/usr/bin/env bash
# DoD 8: kernel text of /synthesize is not edited by this task; Brain edits go through /graduate.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
cd "$VAULT"
for f in System_Agents Memory_Schema Agent_Roles Tool_Registry; do
  git diff --quiet HEAD -- "03_Brain/$f.md" && pass "03_Brain/$f.md has no uncommitted edit" || fail "03_Brain/$f.md modified"
done
unt="$(git ls-files --others --exclude-standard 03_Brain | grep -v '^03_Brain/Weekly_Synthesis/' || true)"
[ -z "$unt" ] && pass "no untracked files in 03_Brain outside Weekly_Synthesis" || fail "untracked in 03_Brain: $unt"
staged="$(git diff --cached --name-only -- 03_Brain)"
[ -z "$staged" ] && pass "nothing staged under 03_Brain" || fail "staged: $staged"
# Out of scope items stay out: no boot-step-8 edit, no /graduate scheduling.
grep -n 'graduate' "$PROMPT" >/dev/null && fail "prompt mentions graduate" || pass "prompt never schedules /graduate"
ugr="$(awk '/^## UNATTENDED MODE/{on=1;next} /^## /{on=0} on' "$RUNBOOK" | grep -c 'Never run `/graduate`')"
eq "unattended mode forbids /graduate" "$ugr" "1"
# Helper is read-only: every subcommand leaves a sandbox byte-identical (manifest incl. mtimes of dirs ignored).
SB="$TMP/sb"; mk_sandbox "$SB"; write_w47 "$SB"
( cd "$SB" && ./.vault_link/.scripts/session_state_write.sh --persona Synthesizer --session-id synth-ro --started-at x --no-legacy-mirror ) >/dev/null
b="$(manifest "$SB")"; hb="$(git -C "$SB" rev-parse HEAD)"
H="$SB/.scripts/synthesize_run.sh"
( cd "$SB" && "$H" week --today 2026-11-30; "$H" plan --week 2026-W47; "$H" plan --week 2026-W46; "$H" report --week 2026-W47; "$H" scope --session-id synth-ro --head "$hb" ) >/dev/null 2>&1
eq "helper subcommands leave the sandbox byte-identical" "$(manifest "$SB")" "$b"
finish

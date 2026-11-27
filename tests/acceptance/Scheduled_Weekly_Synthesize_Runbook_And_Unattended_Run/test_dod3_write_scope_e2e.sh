#!/usr/bin/env bash
# DoD 3: an unattended run writes only inside 03_Brain/Weekly_Synthesis/ and 04_Logs/ (plus its keyed
# session file), never edits other 03_Brain files, never runs /graduate, commits nothing.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
U="$TMP/u.md"; section "$RUNBOOK" '## UNATTENDED MODE' > "$U"
has "$U" 'Never run `/graduate`.' "static: never graduate"
has "$U" 'Do not commit anything.' "static: no commit"
has "$U" '`03_Brain/Weekly_Synthesis/` and `04_Logs/`' "static: allowlist names both folders"
has "$U" 'Never call `queue_attention.sh`.' "static: no queue_attention"
has "$PROMPT" 'Do not commit anything.' "prompt repeats no-commit"

SB="$TMP/sb"; mk_sandbox "$SB"
before="$(manifest "$SB")"
drive_unattended "$SB"
eq "scope check passes after a clean unattended run" "$SCOPE_OUT" "SCOPE: clean"
eq "scope check exit 0" "$SCOPE_RC" "0"
after="$(manifest "$SB")"
changed="$(diff <(echo "$before") <(echo "$after") | sed -n 's/^[<>] [^ ]*  //p; s/^[<>] link  //p' | sort -u)"
bad="$(echo "$changed" | grep -v '^\./03_Brain/Weekly_Synthesis/\|^\./04_Logs/\|^\./\.session_state\.synth-20261130T060000Z\.json$' | grep -v '^$' || true)"
[ -z "$bad" ] && pass "independent manifest diff: changes only in allowed paths" || fail "writes outside allowlist: $bad"
eq "git HEAD unchanged" "$(git -C "$SB" rev-parse HEAD)" "$HEAD0"
[ ! -e "$SB/.session_state.json" ] && pass "no legacy .session_state.json" || fail "legacy mirror written"
[ -f "$SB/.session_state.synth-20261130T060000Z.json" ] && pass "keyed session file written" || fail "keyed session file"
for f in 03_Brain/System_Agents.md 01_Projects/P.md 02_Tasks/P/T.md P_Board.md Needs_Attention.md; do
  eq "sentinel untouched: $f" "$(git -C "$SB" status --porcelain -- "$f" | wc -l | tr -d ' ')" "0"
done

# RED controls: each rogue write after the marker must be caught with exit 4 and the path named.
red() { # name  cmd
  local n="$1" rb="$TMP/red_$1"; mk_sandbox "$rb"
  ( cd "$rb" && ./.vault_link/.scripts/session_state_write.sh --persona Synthesizer --session-id synth-r --started-at x --no-legacy-mirror ) >/dev/null
  local h; h="$(git -C "$rb" rev-parse HEAD)"; sleep 0.1
  ( cd "$rb" && eval "$2" ) >/dev/null 2>&1
  local out rc; out="$(cd "$rb" && ./.vault_link/.scripts/synthesize_run.sh scope --session-id synth-r --head "$h")"; rc=$?
  eq "RED $n exit 4" "$rc" "4"
  echo "$out" | grep -qF -- "$3" && pass "RED $n names $3" || fail "RED $n output lacks $3: $out"
}
red kernel 'echo x >> 03_Brain/System_Agents.md' '03_Brain/System_Agents.md'
red attention 'echo x >> Needs_Attention.md' 'Needs_Attention.md'
red legacy 'echo x > .session_state.json' '.session_state.json'
red content 'mkdir -p 05_Content/a && echo x > 05_Content/a/n.md' '05_Content'
red commit 'echo y > 02_Tasks/P/T.md; git add -A; git -c user.name=t -c user.email=t@t commit -qm z' 'HEAD moved'
red brain_new 'echo x > 03_Brain/New_Rule.md' '03_Brain/New_Rule.md'
red brain_delete 'rm 03_Brain/System_Agents.md' '03_Brain'
# Allowed writes after marker must NOT trip the check.
rb="$TMP/green_allowed"; mk_sandbox "$rb"
( cd "$rb" && ./.vault_link/.scripts/session_state_write.sh --persona Synthesizer --session-id synth-g --started-at x --no-legacy-mirror ) >/dev/null; sleep 0.1
mkdir -p "$rb/04_Logs/Errors" "$rb/03_Brain/Weekly_Synthesis/archive"; echo e > "$rb/04_Logs/Errors/e.md"; echo a > "$rb/03_Brain/Weekly_Synthesis/archive/2026.jsonl"
eq "allowed writes (Errors report, archive) stay clean" "$(cd "$rb" && ./.vault_link/.scripts/synthesize_run.sh scope --session-id synth-g)" "SCOPE: clean"
# Missing marker is E1, not a silent pass.
cd "$rb" && ./.vault_link/.scripts/synthesize_run.sh scope --session-id nope >/dev/null 2>&1; eq "scope without marker exits 1" "$?" "1"

# Fix 2: facts.jsonl.next holds the personal fact store and must be gitignored.
GI="$VAULT/.gitignore"; RULE='03_Brain/Weekly_Synthesis/*.next'
awk '/^# Synthesized memory/ { p = 1; next } p && /^$/ { exit } p' "$GI" | grep -qxF "$RULE" && pass "static: rule in the synthesized-memory block" || fail "static: $RULE missing from the synthesized-memory block"
mkdir -p "$TMP/gi_a" "$TMP/gi_b"
for d in gi_a gi_b; do git -C "$TMP/$d" init -q; mkdir -p "$TMP/$d/03_Brain/Weekly_Synthesis"; echo '{}' > "$TMP/$d/03_Brain/Weekly_Synthesis/facts.jsonl.next"; done
cp "$GI" "$TMP/gi_a/.gitignore"; grep -vxF "$RULE" "$GI" > "$TMP/gi_b/.gitignore"
git -C "$TMP/gi_a" check-ignore -q 03_Brain/Weekly_Synthesis/facts.jsonl.next; eq "behavioral: copied .gitignore ignores facts.jsonl.next" "$?" "0"
git -C "$TMP/gi_b" check-ignore -q 03_Brain/Weekly_Synthesis/facts.jsonl.next; [ "$?" -ne 0 ] && pass "RED: without the rule facts.jsonl.next is not ignored" || fail "RED: ignored without the rule"
git -C "$VAULT" check-ignore -q 03_Brain/Weekly_Synthesis/facts.jsonl.next; eq "live: repo ignores facts.jsonl.next" "$?" "0"
finish

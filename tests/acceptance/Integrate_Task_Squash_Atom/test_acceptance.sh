#!/usr/bin/env bash
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
SC="$VAULT/.scripts/integrate_task.sh"

# DoD1 + 2-commit task squashes to one single-parent commit; branch deleted; markers pinned.
O="$TMP/o1.git"; R="$TMP/r1"; mk_repo "$R" "$O"
OLD="$(rp "$R" staging)"; mk_branch "$R" task/T_One a.txt new 2; TIP="$(rp "$R" task/T_One)"
printf 'keep\n' > "$R/CODEMAP.md"; SUM="$(cksum < "$R/CODEMAP.md")"
it "$R" T_One
eq "integrate exits 0" "$RC" 0
eq "one new commit on staging" "$(git -C "$R" rev-list --count "$OLD..staging")" 1
eq "single parent" "$(git -C "$R" rev-list --parents -n1 staging | wc -w | tr -d ' ')" 2
eq "no merge commits" "$(git -C "$R" rev-list --merges --count staging)" 0
eq "staging parent is old tip" "$(rp "$R" staging~1)" "$OLD"
eq "squash tree equals task tree" "$(rp "$R" 'staging^{tree}')" "$(rp "$R" "$TIP^{tree}")"
eq "origin staging == local staging" "$(git --git-dir="$O" rev-parse staging)" "$(rp "$R" staging)"
eq "HEAD on staging" "$(git -C "$R" symbolic-ref --short HEAD)" staging
eq "task branch deleted" "$(git -C "$R" for-each-ref refs/heads/task | wc -l | tr -d ' ')" 0
eq "subject" "$(git -C "$R" log -1 --format=%s staging)" "task(Acme): T_One"
TR="$(git -C "$R" log -1 --format=%B staging | git interpret-trailers --parse)"
has "trailer Task-Branch" "$TR" "Task-Branch: task/T_One"
has "trailer Task-Commit" "$TR" "Task-Commit: $TIP"
eq "stdout marker order" "$(printf '%s\n' "$OUT" | sed -n '1,4p' | cut -d= -f1 | paste -sd, -)" "INTEGRATE_SHA,INTEGRATE_STATE,INTEGRATE_TASK_BRANCH,RELEASE_PR"
has "state integrated" "$OUT" "INTEGRATE_STATE=integrated"
has "release PR created" "$OUT" "RELEASE_PR=created"
eq "untracked file byte-identical" "$(cksum < "$R/CODEMAP.md")" "$SUM"
eq "origin main untouched" "$(git --git-dir="$O" rev-parse main)" "$(rp "$R" origin/main)"
eq "stderr empty on success" "$ERR" ""

# DoD3 re-run idempotent: tip already trailered -> no commit, no push (reject on), exit 0.
git -C "$R" branch task/T_One "$TIP"; git -C "$R" switch -q main
git -C "$R" update-ref refs/heads/staging "$OLD"; touch "$O/reject"
CNT="$(git --git-dir="$O" rev-list --count staging)"; OSHA="$(git --git-dir="$O" rev-parse staging)"
it "$R" T_One
eq "re-run exits 0 despite reject" "$RC" 0
has "already-integrated" "$OUT" "INTEGRATE_STATE=already-integrated"
eq "no new origin commit" "$(git --git-dir="$O" rev-list --count staging)" "$CNT"
eq "origin staging unchanged" "$(git --git-dir="$O" rev-parse staging)" "$OSHA"
eq "local staging caught up" "$(rp "$R" staging)" "$OSHA"
eq "branch deleted on idempotent path" "$(git -C "$R" for-each-ref refs/heads/task | wc -l | tr -d ' ')" 0
rm -f "$O/reject"

# DoD3 reused slug with new tip integrates anew.
mk_branch "$R" task/T_One a.txt other
it "$R" T_One
eq "reused slug exit 0" "$RC" 0
has "reused slug integrated" "$OUT" "INTEGRATE_STATE=integrated"
eq "origin gained exactly one commit" "$(git --git-dir="$O" rev-list --count staging)" "$((CNT + 1))"

# DoD2 push failure -> exit 5, nothing local changed.
O="$TMP/o2.git"; R="$TMP/r2"; mk_repo "$R" "$O"; mk_branch "$R" task/T_Two c.txt new
touch "$O/reject"; printf 'junk\n' > "$R/junk.txt"; B="$(snap "$R" "$O")"
it "$R" T_Two
eq "push failure exit 5" "$RC" 5
eq "push failure one stderr line" "$(printf '%s\n' "$ERR" | wc -l | tr -d ' ')" 1
has "push failure E5" "$ERR" "E5:"
eq "push failure empty stdout" "$OUT" ""
eq "push failure leaves everything" "$(snap "$R" "$O")" "$B"
eq "gh not called on push failure" "$(wc -l < "$GH_LOG" | tr -d ' ')" 0
rm -f "$O/reject"

# fetch / ls-remote failure -> 5, nothing local changed.
for v in fetch ls-remote; do
  B="$(snap "$R" "$O")"; FAKE_GIT_FAIL=$v it "$R" T_Two
  eq "$v failure exit 5" "$RC" 5
  eq "$v failure unchanged" "$(snap "$R" "$O")" "$B"
done

# DoD2 dirty tracked / staged -> 3 before any network (even when network fails).
git -C "$R" switch -q task/T_Two; printf 'x\n' >> "$R/c.txt"; B="$(snap "$R" "$O")"
FAKE_GIT_FAIL=fetch it "$R" T_Two
eq "modified tracked exit 3 (not 5)" "$RC" 3
has "names file" "$ERR" "c.txt"
eq "dirty refusal unchanged" "$(snap "$R" "$O")" "$B"
git -C "$R" checkout -q -- c.txt; printf 'n\n' > "$R/new.txt"; git -C "$R" add new.txt
FAKE_GIT_FAIL=ls-remote it "$R" T_Two
eq "staged file exit 3" "$RC" 3
git -C "$R" reset -q new.txt; rm -f "$R/new.txt"

# Recovery: after failures, clean re-run succeeds with exactly one trailered commit.
it "$R" T_Two
eq "retry exit 0" "$RC" 0
eq "exactly one commit carries tip" "$(git -C "$R" log --first-parent --fixed-strings --grep="Task-Commit: " --format=%H staging | wc -l | tr -d ' ')" 1

# gh failures are WARN + exit 0, branch already gone.
O="$TMP/o3.git"; R="$TMP/r3"; mk_repo "$R" "$O"; mk_branch "$R" task/T_Three a.txt z
FAKE_GH_FAIL=create it "$R" T_Three
eq "gh create failure exit 0" "$RC" 0
has "RELEASE_PR failed" "$OUT" "RELEASE_PR=failed"
has "WARN create" "$OUT" "WARN: release PR not updated (gh pr create failed"
eq "branch deleted before gh" "$(git -C "$R" for-each-ref refs/heads/task | wc -l | tr -d ' ')" 0
eq "origin has commit" "$(git --git-dir="$O" rev-parse staging)" "$(rp "$R" staging)"
mk_branch "$R" task/T_One c.txt q
FAKE_GH_PR=9 it "$R" T_One
has "existing PR updated" "$OUT" "RELEASE_PR=updated"
has "pr edit 9" "$(cat "$GH_LOG")" "pr edit 9 --body-file"
mk_branch "$R" task/T_Two a.txt r
PATH="$TMP/bin:/usr/bin:/bin" it "$R" T_Two
eq "gh missing exit 0" "$RC" 0
has "gh missing WARN" "$OUT" "WARN: release PR skipped: gh not installed"
eq "no pr merge ever" "$(grep -c 'pr merge' "$GH_LOG")" 0

# Slug lookup: orch branch used; task+orch ambiguous; nested orch ignored.
O="$TMP/o4.git"; R="$TMP/r4"; mk_repo "$R" "$O"
mk_branch "$R" orch/r1/T_One a.txt o
it "$R" T_One
eq "orch branch integrates" "$RC" 0
has "orch branch reported" "$OUT" "INTEGRATE_TASK_BRANCH=orch/r1/T_One"
mk_branch "$R" task/T_Two a.txt t1; git -C "$R" branch orch/r2/T_Two task/T_Two; B="$(snap "$R" "$O")"
it "$R" T_Two
eq "ambiguous exit 3" "$RC" 3
has "ambiguous message" "$ERR" "ambiguous"
eq "ambiguous unchanged" "$(snap "$R" "$O")" "$B"
git -C "$R" switch -q staging; git -C "$R" branch -D task/T_Two orch/r2/T_Two >/dev/null
git -C "$R" branch orch/a/b/T_Two staging
it "$R" T_Two
eq "nested orch not matched exit 3" "$RC" 3
has "no task branch" "$ERR" "no task branch"

# --allow-missing-branch.
it "$R" T_Three --allow-missing-branch
eq "skipped-no-branch exit 0" "$RC" 0
has "skipped state" "$OUT" "INTEGRATE_STATE=skipped-no-branch"
has "sha none" "$OUT" "INTEGRATE_SHA=none"

# Persona.
B="$(snap "$R" "$O")"
(cd "$R" && /bin/bash "$S/integrate_task.sh" --task-path "$V/02_Tasks/P/T_One.md" --source-persona Architect) >"$TMP/o" 2>"$TMP/e"; RC=$?
eq "non-Executioner exit 4" "$RC" 4
eq "persona unchanged" "$(snap "$R" "$O")" "$B"

# Telemetry present.
T="$(cat "$V"/04_Logs/Telemetry/*.jsonl 2>/dev/null)"
has "telemetry success" "$T" '"status":"success"'
has "telemetry error E5" "$T" '"error_class":"E5"'
has "telemetry macro" "$T" '"macro":"integrate_task"'

# DoD4 static checks.
NC="$(grep -v '^[[:space:]]*#' "$SC")"
eq "no gh pr merge" "$(printf '%s\n' "$NC" | grep -c 'pr merge')" 0
eq "push lines target staging only" "$(printf '%s\n' "$NC" | grep 'git push' | grep -vc 'refs/heads/staging')" 0
eq "no force flag on push" "$(printf '%s\n' "$NC" | grep 'git push' | grep -Ec -- '--force| -f |\+')" 0
for w in '--force' '--no-verify' 'git merge ' 'git reset' 'git stash' 'git clean' 'git rebase' 'git pull'; do
  eq "absent: $w" "$(printf '%s\n' "$NC" | grep -Fc -- "$w")" 0
done
TOK="$(printf '%s\n' "$NC" | grep -oE '[A-Za-z0-9_]+\.sh' | sort -u | paste -sd, -)"
eq "only allowed .sh tokens" "$(printf '%s\n' "$NC" | grep -oE '[A-Za-z0-9_]+\.sh' | sort -u | grep -vxE 'emit_telemetry\.sh|persona_check\.sh|integrate_task\.sh' | wc -l | tr -d ' ')" 0
eq "SCRIPT_DIR refs exact" "$(printf '%s\n' "$NC" | grep -oE 'SCRIPT_DIR/[a-z_]+\.sh' | sort -u | paste -sd, -)" 'SCRIPT_DIR/emit_telemetry.sh,SCRIPT_DIR/persona_check.sh'
eq "no source" "$(printf '%s\n' "$NC" | grep -cE '^[[:space:]]*(source |\. )')" 0
eq "shebang" "$(head -1 "$SC")" '#!/usr/bin/env bash'
/bin/bash -n "$SC" && pass "bash -n" || fail "bash -n"

# DoD5 header.
HDR="$(sed -n '1,/^set -euo pipefail/p' "$SC")"
for k in '5  transient' 'INTEGRATE_SHA=' 'INTEGRATE_STATE=' 'INTEGRATE_TASK_BRANCH=' 'RELEASE_PR=' 'WARN:'; do has "header: $k" "$HDR" "$k"; done
finish

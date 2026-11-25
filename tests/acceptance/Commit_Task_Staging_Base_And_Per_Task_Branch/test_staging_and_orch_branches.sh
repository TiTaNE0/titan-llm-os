#!/usr/bin/env bash
# DoD 1/3: staging base, per-task orch branches, ref-conflict E3, no-op, stdout contract.
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

# crit 2a/3/4: interactive in staging project cuts task/<slug> from staging whatever HEAD
R="$TMP/r1"; mk_repo "$R"; add_staging "$R"; ST="$(rp "$R" staging)"; MN="$(rp "$R" main)"
git -C "$R" switch -q -c feature/x; printf 'f\n' > "$R/f.txt"; git -C "$R" add f.txt; git -C "$R" commit -q -m f; FX="$(rp "$R" feature/x)"
dirty "$R" a.txt; ct "$R" T_One
eq "interactive exit" "$RC" 0
eq "interactive branch" "$(head_br "$R")" task/T_One
eq "interactive parent is staging not feature/x" "$(rp "$R" task/T_One~1)" "$ST"
eq "feature/x unchanged" "$(rp "$R" feature/x)" "$FX"
eq "main unchanged" "$(rp "$R" main)" "$MN"
eq "COMMIT_BRANCH marker" "$(printf '%s\n' "$OUT" | sed -n 1p)" "COMMIT_BRANCH=task/T_One"
eq "COMMIT_SHA marker second" "$(printf '%s\n' "$OUT" | sed -n 2p | cut -d= -f1)" COMMIT_SHA
eq "COMMIT_STAGED marker third" "$(printf '%s\n' "$OUT" | sed -n 3p)" COMMIT_STAGED=1
# crit 10 no-op rerun
B4="$(git -C "$R" for-each-ref --format='%(refname) %(objectname)')"
ct "$R" T_One
eq "noop exit" "$RC" 0
eq "noop markers" "$(printf '%s\n' "$OUT" | head -3 | tr '\n' ' ')" "COMMIT_BRANCH=none COMMIT_SHA=none COMMIT_STAGED=0 "
eq "noop refs unchanged" "$(git -C "$R" for-each-ref --format='%(refname) %(objectname)')" "$B4"

# crit 2b: origin/staging only, no tracking config, no push
R="$TMP/r2"; O="$TMP/o2.git"; mk_repo "$R" "$O"; add_staging "$R" push; git -C "$R" branch -q -D staging
ST="$(rp "$R" refs/remotes/origin/staging)"; LS="$(git -C "$R" ls-remote origin)"
dirty "$R" a.txt; ct "$R" T_One
eq "origin-staging exit" "$RC" 0
eq "origin-staging parent" "$(rp "$R" task/T_One~1)" "$ST"
eq "no tracking merge cfg" "$(git -C "$R" config --get branch.task/T_One.merge || true)" ""
eq "no tracking remote cfg" "$(git -C "$R" config --get branch.task/T_One.remote || true)" ""
eq "no local staging created" "$(git -C "$R" show-ref --verify --quiet refs/heads/staging && echo y || echo n)" n
eq "origin untouched" "$(git -C "$R" ls-remote origin)" "$LS"

# D1 precedence: local staging ahead of origin/staging wins
R="$TMP/r3"; O="$TMP/o3.git"; mk_repo "$R" "$O"; add_staging "$R" push
git -C "$R" switch -q staging; printf 'm\n' > "$R/more.txt"; git -C "$R" add more.txt; git -C "$R" commit -q -m more; git -C "$R" switch -q main
dirty "$R" a.txt; ct "$R" T_One
eq "local staging beats origin/staging" "$(rp "$R" task/T_One~1)" "$(rp "$R" staging)"

# crit 7: orch/<run> blocks orch/<run>/<slug>: one E3 line, nothing mutated
R="$TMP/r4"; mk_repo "$R"; git -C "$R" branch orch/run-7; dirty "$R" a.txt
snap() { { git -C "$R" for-each-ref; git -C "$R" symbolic-ref HEAD; git -C "$R" ls-files -s | cksum; git -C "$R" status --porcelain; } | cksum; }
B4="$(snap)"; ct "$R" T_One --run-id run-7
eq "E3 exit" "$RC" 3
eq "E3 one stderr line" "$(printf '%s\n' "$ERR" | wc -l | tr -d ' ')" 1
case "$ERR" in E3:*orch/run-7*) pass "E3 names orch/run-7";; *) fail "E3 text: $ERR";; esac
eq "E3 stdout empty" "$OUT" ""
eq "E3 nothing mutated" "$(snap)" "$B4"
# nested-under-target variant
R="$TMP/r4b"; mk_repo "$R"; git -C "$R" branch orch/run-8/T_One/old; dirty "$R" a.txt; ct "$R" T_One --run-id run-8
eq "nested conflict exit" "$RC" 3
case "$ERR" in *orch/run-8/T_One/old*) pass "nested conflict names blocker";; *) fail "nested text: $ERR";; esac
# branch named task blocks task/<slug> interactive
R="$TMP/r4c"; mk_repo "$R"; git -C "$R" branch task; dirty "$R" a.txt; ct "$R" T_One
eq "task blocker exit" "$RC" 3

# crit 6: non-staging --run-id: orch/<run>/<slug>, second task stacks on first
R="$TMP/r5"; mk_repo "$R"; dirty "$R" a.txt; ct "$R" T_One --run-id run-123
eq "orch exit" "$RC" 0
eq "orch branch" "$(head_br "$R")" orch/run-123/T_One
dirty "$R" c.txt; ct "$R" T_Two --run-id run-123
eq "orch second branch" "$(head_br "$R")" orch/run-123/T_Two
eq "orch second stacked on first" "$(rp "$R" orch/run-123/T_Two~1)" "$(rp "$R" orch/run-123/T_One)"
eq "orch ref count" "$(git -C "$R" for-each-ref --format='%(refname)' refs/heads/orch/run-123/ | wc -l | tr -d ' ')" 2

# crit 8 + amendment 5: staging project, run-id cut from staging, then stack, cross-run guard
R="$TMP/r6"; O="$TMP/o6.git"; mk_repo "$R" "$O"; add_staging "$R" push; ST="$(rp "$R" staging)"; LS="$(git -C "$R" ls-remote origin)"
dirty "$R" a.txt; ct "$R" T_One --run-id run-s
eq "run-s exit" "$RC" 0
eq "run-s branch" "$(head_br "$R")" orch/run-s/T_One
eq "run-s parent is staging" "$(rp "$R" orch/run-s/T_One~1)" "$ST"
dirty "$R" c.txt; ct "$R" T_Two --run-id run-s
eq "stack parent = first branch tip" "$(rp "$R" orch/run-s/T_Two~1)" "$(rp "$R" orch/run-s/T_One)"
dirty "$R" d.txt; ct "$R" T_Three --run-id run
eq "shorter run id does not stack" "$(rp "$R" orch/run/T_Three~1)" "$ST"
eq "staging unchanged" "$(rp "$R" staging)" "$ST"
eq "origin unchanged" "$(git -C "$R" ls-remote origin)" "$LS"
# crit 10 run-id no-op creates no ref
R2="$TMP/r7"; mk_repo "$R2"; add_staging "$R2"; ct "$R2" T_One --run-id run-s2
eq "run-id noop markers" "$(printf '%s\n' "$OUT" | head -3 | tr '\n' ' ')" "COMMIT_BRANCH=none COMMIT_SHA=none COMMIT_STAGED=0 "
eq "run-id noop no ref" "$(git -C "$R2" for-each-ref refs/heads/orch/ | wc -l | tr -d ' ')" 0

# D1: default branch not resolved in staging project (main+master, no origin/HEAD)
R="$TMP/r8"; mk_repo "$R"; add_staging "$R"; git -C "$R" branch master main; git -C "$R" switch -q master
dirty "$R" a.txt; ct "$R" T_One
eq "ambiguous-default exit" "$RC" 0
eq "ambiguous-default branch" "$(head_br "$R")" task/T_One

# D1 fallback: staging touches d.txt; main has dirty out-of-list d.txt
R="$TMP/r9"; mk_repo "$R"; git -C "$R" switch -q -c staging; printf 'sd\n' > "$R/d.txt"; git -C "$R" commit -q -am sd; git -C "$R" switch -q main
dirty "$R" a.txt; printf 'mine\n' > "$R/d.txt"; ct "$R" T_One --run-id run-f
eq "fallback exit" "$RC" 0
eq "fallback HEAD still main" "$(head_br "$R")" main
eq "fallback parent staging" "$(rp "$R" orch/run-f/T_One~1)" "$(rp "$R" staging)"
eq "fallback worktree d intact" "$(cat "$R/d.txt")" mine
case "$OUT" in *"NOTE: committed onto orch/run-f/T_One without switching"*) pass "fallback NOTE";; *) fail "fallback NOTE missing: $OUT";; esac
R="$TMP/r9b"; mk_repo "$R"; git -C "$R" switch -q -c staging; printf 'sd\n' > "$R/d.txt"; git -C "$R" commit -q -am sd; git -C "$R" switch -q main
dirty "$R" a.txt; printf 'mine\n' > "$R/d.txt"; ct "$R" T_One
eq "interactive fallback E2" "$RC" 2
eq "no task branch created" "$(git -C "$R" show-ref --verify --quiet refs/heads/task/T_One && echo y || echo n)" n
finish

#!/usr/bin/env bash
# test_commit_task.sh
#
# Verification Gateway for Close_Task_Commit_Step.
# Builds throwaway git repos (default branch main and master, a bare origin, a
# feature branch) and drives .scripts/commit_task.sh against a task file whose
# Spec lists the files touched. Asserts: only listed files are committed, a
# task/<slug> branch is created on the default branch, nothing is pushed, the
# Orchestrator reports (not commits) out-of-list tracked changes, and the refusal paths.
#
# Runs against TEMP COPIES of the atom in an isolated temp vault; every git
# repo lives under mktemp. Never touches the live vault or kit repos.
#
# Exit 0 = all assertions pass; last line `SMOKE: OK`.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRIPTS="$REPO_ROOT/.scripts"

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

TMP="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

V="$TMP/vault"
S="$V/.scripts"
mkdir -p "$S" "$V/04_Logs/Telemetry" "$V/02_Tasks/Proj" "$TMP/outside"
cp "$SCRIPTS/commit_task.sh" "$SCRIPTS/lib_section.sh" "$SCRIPTS/persona_check.sh" "$SCRIPTS/emit_telemetry.sh" "$S/"
printf '{\n  "persona": "Executioner",\n  "session_id": "smoke",\n  "started_at": "2026-06-14T00:00:00Z",\n  "agent_surface": "test"\n}\n' > "$V/.session_state.json"

fail() { echo "FAIL: $1" >&2; exit 1; }
eq()   { [[ "$1" == "$2" ]] || fail "$3 (expected '$2', got '$1')"; }

TASK="$V/02_Tasks/Proj/Fix_Thing.md"
echo "outside" > "$TMP/outside/z.txt"

# Spec mirrors the real format: nested `## Spec: <Task>` header, owns-suffix
# naming an out-of-list file, an outside-repo absolute path, a not-found path,
# and marked lines in Risks / a later section that must NOT be parsed.
cat > "$TASK" <<EOF
---
project: [[Proj]]
status: in_progress
---

# Task: Fix_Thing

## 📐 Spec
> Populated by invoke_spec_writer.
<!-- write_task_section section=spec -->

## Spec: Fix_Thing

### Summary
Touches a few files.

### Files touched
Executioner-buildable:
- [EDIT] \`a.txt\` (repo)
- [NEW] \`b.txt\` — owns: new thing; existing owner: \`d.txt\`
- [DELETE] \`c.txt\`
- [EDIT] \`$TMP/outside/z.txt\` (elsewhere)
- [EDIT] \`ghost.txt\`
- [EDIT] \`sub\` (a directory)

Note: other text.

### Risks
- [EDIT] \`d.txt\` is mentioned here but is not part of the file list.

## ✅ Validator Report
- [NEW] \`late.txt\` must not be parsed
EOF

TASK_NOBLOCK="$V/02_Tasks/Proj/No_Block.md"
printf -- '---\nproject: [[Proj]]\n---\n\n## 📐 Spec\n\n## Spec: No_Block\n\n### Summary\nnothing listed\n\n## Other\n' > "$TASK_NOBLOCK"

# mk_repo <dir> <default-branch> [remote]  -> clean repo with a.txt c.txt d.txt sub/s.txt
mk_repo() {
  local d="$1" br="$2" remote="${3:-}"
  mkdir -p "$d/sub"
  git init -q -b "$br" "$d"
  git -C "$d" config user.name "Test"
  git -C "$d" config user.email "test@example.com"
  printf 'a0\n' > "$d/a.txt"; printf 'c0\n' > "$d/c.txt"; printf 'd0\n' > "$d/d.txt"; printf 's0\n' > "$d/sub/s.txt"
  git -C "$d" add -A
  git -C "$d" commit -q -m init
  if [[ -n "$remote" ]]; then
    git init -q --bare -b "$br" "$remote"
    git -C "$d" remote add origin "$remote"
    git -C "$d" push -q -u origin "$br"
    git -C "$d" remote set-head origin "$br" >/dev/null
  fi
}

# dirty_listed: modify a, create b, delete c (the three listed changes)
dirty_listed() { printf 'a1\n' > "$1/a.txt"; printf 'b1\n' > "$1/b.txt"; rm -f "$1/c.txt"; }

RC=0
run_ct() { # run_ct <repo> <args...> ; sets RC, $TMP/out, $TMP/err
  local repo="$1"; shift
  RC=0
  (cd "$repo" && "$S/commit_task.sh" "$@") > "$TMP/out" 2> "$TMP/err" || RC=$?
}
CT=(--task-path "$TASK" --source-persona Executioner)

committed_files() { git -C "$1" show --name-only --format= HEAD | sort | paste -sd, -; }

# --- 1. Interactive on main with origin: task branch, only listed files, no push
R1="$TMP/r1"; O1="$TMP/o1.git"
mk_repo "$R1" main "$O1"
dirty_listed "$R1"
printf 'd1\n' > "$R1/d.txt"
printf 'junk\n' > "$R1/junk.txt"
MAIN_BEFORE="$(git -C "$R1" rev-parse main)"
REMOTE_BEFORE="$(git -C "$R1" ls-remote origin)"
run_ct "$R1" "${CT[@]}"
eq "$RC" 0 "case1 exit code (stderr: $(cat "$TMP/err"))"
eq "$(git -C "$R1" symbolic-ref --short HEAD)" "task/Fix_Thing" "case1 branch"
eq "$(committed_files "$R1")" "a.txt,b.txt,c.txt" "case1 committed files"
eq "$(git -C "$R1" diff --name-only)" "d.txt" "case1 d.txt remains modified and unstaged"
git -C "$R1" diff --cached --quiet || fail "case1 index not clean after commit"
eq "$(git -C "$R1" rev-parse main)" "$MAIN_BEFORE" "case1 main ref unchanged"
eq "$(git -C "$R1" ls-remote origin)" "$REMOTE_BEFORE" "case1 nothing pushed"
grep -qx 'COMMIT_BRANCH=task/Fix_Thing' "$TMP/out" || fail "case1 COMMIT_BRANCH marker"
grep -qx 'COMMIT_STAGED=3' "$TMP/out" || fail "case1 COMMIT_STAGED marker"
grep -qE '^COMMIT_SHA=[0-9a-f]{7,}$' "$TMP/out" || fail "case1 COMMIT_SHA marker"
grep -qx 'WARN_OUT_OF_LIST: d.txt' "$TMP/out" || fail "case1 warn for tracked d.txt"
grep -qx 'WARN_OUT_OF_LIST: junk.txt' "$TMP/out" || fail "case1 warn for untracked junk.txt"
grep -qF 'z.txt (outside-repo)' "$TMP/out" || fail "case1 outside-repo skip"
grep -qx 'SKIPPED: ghost.txt (not-found)' "$TMP/out" || fail "case1 not-found skip"
grep -qx 'SKIPPED: sub (directory)' "$TMP/out" || fail "case1 directory skip"
if grep -q 'late.txt' "$TMP/out"; then fail "case1 parsed an entry outside the Spec section"; fi
eq "$(git -C "$R1" log -1 --format=%s)" "task(Proj): Fix_Thing" "case1 commit subject"
git -C "$R1" log -1 --format=%b | grep -qF 'Closes [[Fix_Thing]] via /close_task.' || fail "case1 commit body"

# --- 2. master default, no remote: task branch created from master
R2="$TMP/r2"
mk_repo "$R2" master
dirty_listed "$R2"
MASTER_BEFORE="$(git -C "$R2" rev-parse master)"
run_ct "$R2" "${CT[@]}"
eq "$RC" 0 "case2 exit code (stderr: $(cat "$TMP/err"))"
eq "$(git -C "$R2" symbolic-ref --short HEAD)" "task/Fix_Thing" "case2 branch"
eq "$(git -C "$R2" rev-parse master)" "$MASTER_BEFORE" "case2 master unchanged"
eq "$(git -C "$R2" rev-parse 'task/Fix_Thing~1')" "$MASTER_BEFORE" "case2 branched from master"

# --- 3. non-default branch: commit stays on the current branch
R3="$TMP/r3"
mk_repo "$R3" main
git -C "$R3" switch -q -c feature/x
dirty_listed "$R3"
HEAD3="$(git -C "$R3" rev-parse HEAD)"
run_ct "$R3" "${CT[@]}"
eq "$RC" 0 "case3 exit code (stderr: $(cat "$TMP/err"))"
eq "$(git -C "$R3" symbolic-ref --short HEAD)" "feature/x" "case3 branch unchanged"
eq "$(git -C "$R3" branch --list 'task/*' | wc -l | tr -d ' ')" 0 "case3 no task branch created"
eq "$(git -C "$R3" rev-parse 'HEAD~1')" "$HEAD3" "case3 one new commit on feature/x"
eq "$(committed_files "$R3")" "a.txt,b.txt,c.txt" "case3 committed files"

# --- 4. Orchestrator + out-of-list TRACKED change: not refused, left dirty, reported
R4="$TMP/r4"
mk_repo "$R4" main
dirty_listed "$R4"
printf 'd1\n' > "$R4/d.txt"
run_ct "$R4" "${CT[@]}" --run-id run-123
eq "$RC" 0 "case4 exit code (stderr: $(cat "$TMP/err"))"
eq "$(git -C "$R4" symbolic-ref --short HEAD)" "orch/run-123/Fix_Thing" "case4 orch branch created with d.txt dirty"
eq "$(committed_files "$R4")" "a.txt,b.txt,c.txt" "case4 only the list committed"
eq "$(git -C "$R4" diff --name-only)" "d.txt" "case4 d.txt still modified and unstaged"
git -C "$R4" diff --cached --quiet || fail "case4 index not clean"
grep -qx 'IGNORED: d.txt (out-of-list, not committed)' "$TMP/out" || fail "case4 IGNORED line ($(cat "$TMP/out"))"
grep -qx 'COMMIT_BRANCH=orch/run-123/Fix_Thing' "$TMP/out" || fail "case4 COMMIT_BRANCH marker"
grep -qx 'COMMIT_STAGED=3' "$TMP/out" || fail "case4 COMMIT_STAGED marker"
eq "$(git -C "$R4" rev-parse 'HEAD~1')" "$(git -C "$R4" rev-parse main)" "case4 orch branch cut from main"

# --- 4b. Orchestrator: existing orch branch with a different tree; switch succeeds with others' edits dirty
R4B="$TMP/r4b"
mk_repo "$R4B" main
printf 'x\n' > "$R4B/other file.txt"; git -C "$R4B" add -A; git -C "$R4B" commit -q -m other
git -C "$R4B" switch -q -c orch/run-9/Fix_Thing
printf 'c-orch\n' > "$R4B/c.txt"; git -C "$R4B" commit -q -am orch-work
git -C "$R4B" switch -q main
printf 'x1\n' > "$R4B/other file.txt"; printf 'd1\n' > "$R4B/d.txt"
printf 'a1\n' > "$R4B/a.txt"
run_ct "$R4B" "${CT[@]}" --run-id run-9
eq "$RC" 0 "case4b exit code (stderr: $(cat "$TMP/err"))"
eq "$(git -C "$R4B" symbolic-ref --short HEAD)" "orch/run-9/Fix_Thing" "case4b switched to existing orch branch"
eq "$(committed_files "$R4B")" "a.txt" "case4b listed dirty file committed alone"
eq "$(cat "$R4B/c.txt")" "c-orch" "case4b worktree now holds the orch branch tree"
grep -qx 'IGNORED: other file.txt (out-of-list, not committed)' "$TMP/out" || fail "case4b IGNORED path with spaces"
grep -qx 'IGNORED: d.txt (out-of-list, not committed)' "$TMP/out" || fail "case4b IGNORED d.txt"
eq "$(git -C "$R4B" diff --name-only | paste -sd, -)" "d.txt,other file.txt" "case4b others still dirty"

# --- 4c. Existing orch branch whose switch would overwrite others' edits: commit without switching
R4C="$TMP/r4c"
mk_repo "$R4C" main
git -C "$R4C" switch -q -c orch/run-9/Fix_Thing
printf 'd-orch\n' > "$R4C/d.txt"; printf 'e-orch\n' > "$R4C/e.txt"; git -C "$R4C" add -A; git -C "$R4C" commit -q -m orch-work
git -C "$R4C" switch -q main
printf 'd-human\n' > "$R4C/d.txt"; printf 'e-human\n' > "$R4C/e.txt"
printf 'a1\n' > "$R4C/a.txt"
ORCH_BEFORE="$(git -C "$R4C" rev-parse orch/run-9/Fix_Thing)"
run_ct "$R4C" "${CT[@]}" --run-id run-9
eq "$RC" 0 "case4c exit code (stderr: $(cat "$TMP/err"))"
eq "$(git -C "$R4C" symbolic-ref --short HEAD)" "main" "case4c HEAD stays on main"
eq "$(git -C "$R4C" rev-parse 'orch/run-9/Fix_Thing~1')" "$ORCH_BEFORE" "case4c orch branch advanced by one commit"
eq "$(git -C "$R4C" show --name-only --format= orch/run-9/Fix_Thing | paste -sd, -)" "a.txt" "case4c commit holds only the list"
eq "$(git -C "$R4C" show orch/run-9/Fix_Thing:d.txt)" "d-orch" "case4c others' edits not committed"
eq "$(cat "$R4C/d.txt")" "d-human" "case4c worktree edit intact"
eq "$(cat "$R4C/a.txt")" "a1" "case4c listed file intact in worktree"
grep -qx 'NOTE: committed onto orch/run-9/Fix_Thing without switching (worktree has overlapping edits)' "$TMP/out" || fail "case4c NOTE ($(cat "$TMP/out"))"
grep -qx 'COMMIT_BRANCH=orch/run-9/Fix_Thing' "$TMP/out" || fail "case4c COMMIT_BRANCH"
grep -qx 'COMMIT_STAGED=1' "$TMP/out" || fail "case4c COMMIT_STAGED"
grep -qx 'IGNORED: d.txt (out-of-list, not committed)' "$TMP/out" || fail "case4c IGNORED d.txt"
git -C "$R4C" log -1 --format=%b orch/run-9/Fix_Thing | grep -qF 'Orchestrator run: run-9' || fail "case4c commit body"

# --- 4d. Same fallback when an untracked file would be overwritten by the switch
R4D="$TMP/r4d"
mk_repo "$R4D" main
git -C "$R4D" switch -q -c orch/run-9/Fix_Thing
printf 'e-orch\n' > "$R4D/e.txt"; git -C "$R4D" add -A; git -C "$R4D" commit -q -m orch-work
git -C "$R4D" switch -q main
printf 'e-human\n' > "$R4D/e.txt"; printf 'a1\n' > "$R4D/a.txt"
run_ct "$R4D" "${CT[@]}" --run-id run-9
eq "$RC" 0 "case4d exit code (stderr: $(cat "$TMP/err"))"
eq "$(git -C "$R4D" symbolic-ref --short HEAD)" "main" "case4d HEAD stays on main"
eq "$(git -C "$R4D" show --name-only --format= orch/run-9/Fix_Thing | paste -sd, -)" "a.txt" "case4d commit holds only the list"
eq "$(cat "$R4D/e.txt")" "e-human" "case4d untracked file intact"

# --- 4e. A hook that sweeps others' edits into the commit: reported, not hidden as IGNORED
R4E="$TMP/r4e"
mk_repo "$R4E" main
printf '#!/bin/sh\ngit add -u\n' > "$R4E/.git/hooks/pre-commit"; chmod +x "$R4E/.git/hooks/pre-commit"
printf 'a1\n' > "$R4E/a.txt"; printf 'd1\n' > "$R4E/d.txt"
run_ct "$R4E" "${CT[@]}" --run-id run-5
eq "$RC" 0 "case4e exit code (stderr: $(cat "$TMP/err"))"
eq "$(committed_files "$R4E")" "a.txt,d.txt" "case4e hook swept d.txt"
grep -qx 'WARN: swept into commit: d.txt' "$TMP/out" || fail "case4e swept warning ($(cat "$TMP/out"))"
if grep -q '^IGNORED: d.txt' "$TMP/out"; then fail "case4e swept file wrongly reported IGNORED"; fi
grep -qx 'COMMIT_STAGED=2' "$TMP/out" || fail "case4e COMMIT_STAGED counts the real commit"

# --- 5. Orchestrator + only UNTRACKED out-of-list: commits on orch/<run-id>/<slug>
R5="$TMP/r5"
mk_repo "$R5" main
dirty_listed "$R5"
printf 'junk\n' > "$R5/junk.txt"
run_ct "$R5" "${CT[@]}" --run-id run-123
eq "$RC" 0 "case5 exit code (stderr: $(cat "$TMP/err"))"
eq "$(git -C "$R5" symbolic-ref --short HEAD)" "orch/run-123/Fix_Thing" "case5 branch"
eq "$(committed_files "$R5")" "a.txt,b.txt,c.txt" "case5 committed files"
git -C "$R5" log -1 --format=%b | grep -qF 'Orchestrator run: run-123' || fail "case5 commit body run id"
[[ -f "$R5/junk.txt" ]] && git -C "$R5" ls-files --error-unmatch junk.txt >/dev/null 2>&1 && fail "case5 junk committed"
if grep -q 'WARN_OUT_OF_LIST' "$TMP/out"; then fail "case5 orchestrator mode must not print warnings"; fi

# --- 6. Re-run after case 1: no-op
HEAD1="$(git -C "$R1" rev-parse HEAD)"
run_ct "$R1" "${CT[@]}"
eq "$RC" 0 "case6 exit code (stderr: $(cat "$TMP/err"))"
grep -qx 'COMMIT_SHA=none' "$TMP/out" || fail "case6 expected COMMIT_SHA=none"
eq "$(git -C "$R1" rev-parse HEAD)" "$HEAD1" "case6 HEAD unchanged"

# --- 6b. Only an out-of-list file dirty on the default branch: no-op, no branch switch
R6="$TMP/r6"
mk_repo "$R6" main
printf 'd1\n' > "$R6/d.txt"
run_ct "$R6" "${CT[@]}"
eq "$RC" 0 "case6b exit code (stderr: $(cat "$TMP/err"))"
grep -qx 'COMMIT_BRANCH=none' "$TMP/out" || fail "case6b expected COMMIT_BRANCH=none"
eq "$(git -C "$R6" symbolic-ref --short HEAD)" "main" "case6b stayed on main"

# --- 7. Failing pre-commit hook: E2, task file untouched
R7="$TMP/r7"
mk_repo "$R7" main
dirty_listed "$R7"
printf '#!/bin/sh\necho hook-says-no >&2\nexit 1\n' > "$R7/.git/hooks/pre-commit"
chmod +x "$R7/.git/hooks/pre-commit"
SUM_BEFORE="$(cksum < "$TASK")"
run_ct "$R7" "${CT[@]}"
eq "$RC" 2 "case7 exit code"
grep -q '^E2:' "$TMP/err" || fail "case7 stderr E2 prefix"
eq "$(cksum < "$TASK")" "$SUM_BEFORE" "case7 task file checksum unchanged"

# --- 8. Out-of-list path pre-staged: refused in both modes
R8="$TMP/r8"
mk_repo "$R8" main
dirty_listed "$R8"
printf 'd1\n' > "$R8/d.txt"
git -C "$R8" add d.txt
HEAD8="$(git -C "$R8" rev-parse HEAD)"
run_ct "$R8" "${CT[@]}"
eq "$RC" 3 "case8 exit code interactive"
grep -q 'staged paths outside the spec list: d.txt' "$TMP/err" || fail "case8 stderr message ($(cat "$TMP/err"))"
run_ct "$R8" "${CT[@]}" --run-id run-9
eq "$RC" 3 "case8 exit code orchestrator"
eq "$(git -C "$R8" rev-parse HEAD)" "$HEAD8" "case8 HEAD unchanged"
eq "$(git -C "$R8" symbolic-ref --short HEAD)" "main" "case8 branch unchanged"

# --- 9. Spec without a Files touched block: E3
R9="$TMP/r9"
mk_repo "$R9" main
dirty_listed "$R9"
run_ct "$R9" --task-path "$TASK_NOBLOCK" --source-persona Executioner
eq "$RC" 3 "case9 exit code"

# --- 10. Wrong persona: E4
run_ct "$R9" --task-path "$TASK" --source-persona Architect
eq "$RC" 4 "case10 exit code"

# --- 10b. Other refusals: unknown arg, missing arg, missing task, non-repo, detached HEAD
run_ct "$R9" "${CT[@]}" --bogus
eq "$RC" 3 "case10b unknown arg"
run_ct "$R9" --task-path "$TASK"
eq "$RC" 3 "case10b missing persona arg"
run_ct "$R9" --task-path "$TMP/nope.md" --source-persona Executioner
eq "$RC" 1 "case10b missing task file"
run_ct "$TMP/outside" "${CT[@]}"
eq "$RC" 1 "case10b not a git work tree"
git -C "$R9" checkout -q --detach
run_ct "$R9" "${CT[@]}"
eq "$RC" 3 "case10b detached HEAD"

# --- 10c. Telemetry written for success and error
TELE="$V/04_Logs/Telemetry"
cat "$TELE"/*.jsonl | grep -q '"commit_task"' || fail "case10c no commit_task telemetry"
cat "$TELE"/*.jsonl | grep '"commit_task"' | grep -q '"success"' || fail "case10c no success telemetry"
cat "$TELE"/*.jsonl | grep '"commit_task"' | grep -q '"error"' || fail "case10c no error telemetry"

# --- 12. Regressions: gitignored listed file reported (ignored); `git rm` deletion committed
TASK_REG="$V/02_Tasks/Proj/Reg_Case.md"
cat > "$TASK_REG" <<EOF
---
project: [[Proj]]
---

## Spec: Reg_Case

### Files touched
- [EDIT] \`a.txt\`
- [NEW] \`ignored.log\`
- [DELETE] \`c.txt\`
EOF
R12="$TMP/r12"
mk_repo "$R12" main
printf 'ignored.log\n' > "$R12/.gitignore"
git -C "$R12" add .gitignore
git -C "$R12" commit -q -m ignore
printf 'a1\n' > "$R12/a.txt"
printf 'log\n' > "$R12/ignored.log"
git -C "$R12" rm -q c.txt
run_ct "$R12" --task-path "$TASK_REG" --source-persona Executioner
eq "$RC" 0 "case12 exit code ($(cat "$TMP/err"))"
grep -Fxq 'SKIPPED: ignored.log (ignored)' "$TMP/out" || fail "case12 ignored not reported ($(cat "$TMP/out"))"
if grep -q 'ignored.log (clean)' "$TMP/out"; then fail "case12 ignored reported as clean"; fi
eq "$(committed_files "$R12")" "a.txt,c.txt" "case12 committed files (staged delete included)"
eq "$(git -C "$R12" status --porcelain --untracked-files=no)" "" "case12 no staged leftovers"

# --- 13. Default branch: both main and master with no origin/HEAD is ambiguous -> E3
R13="$TMP/r13"
mk_repo "$R13" master
git -C "$R13" branch main
dirty_listed "$R13"
HEAD13="$(git -C "$R13" rev-parse HEAD)"
REFS13="$(git -C "$R13" for-each-ref | paste -sd, -)"
run_ct "$R13" "${CT[@]}"
eq "$RC" 3 "case13 exit code (stderr: $(cat "$TMP/err"))"
eq "$(wc -l < "$TMP/err" | tr -d ' ')" 1 "case13 stderr is exactly one line"
grep -q '^E3: default branch ambiguous' "$TMP/err" || fail "case13 stderr message ($(cat "$TMP/err"))"
eq "$(git -C "$R13" symbolic-ref --short HEAD)" "master" "case13 still on master"
eq "$(git -C "$R13" rev-parse HEAD)" "$HEAD13" "case13 HEAD unchanged"
eq "$(git -C "$R13" for-each-ref | paste -sd, -)" "$REFS13" "case13 no ref moved or created"
git -C "$R13" diff --cached --quiet || fail "case13 index touched"

# --- 13b. Same two branches but origin/HEAD present: it decides, task branch created
R13B="$TMP/r13b"; O13B="$TMP/o13b.git"
mk_repo "$R13B" master "$O13B"
git -C "$R13B" branch main
dirty_listed "$R13B"
run_ct "$R13B" "${CT[@]}"
eq "$RC" 0 "case13b exit code (stderr: $(cat "$TMP/err"))"
eq "$(git -C "$R13B" symbolic-ref --short HEAD)" "task/Fix_Thing" "case13b branch"
eq "$(git -C "$R13B" rev-parse 'task/Fix_Thing~1')" "$(git -C "$R13B" rev-parse master)" "case13b cut from origin/HEAD branch"

# --- 14. In-progress merge touching only listed paths: refused, not concluded as a merge commit
R14="$TMP/r14"
mk_repo "$R14" main
git -C "$R14" switch -q -c other
printf 'a-other\n' > "$R14/a.txt"
git -C "$R14" commit -q -am other
git -C "$R14" switch -q main
git -C "$R14" switch -q -c feature
printf 'd-feature\n' > "$R14/d.txt"
git -C "$R14" commit -q -am feature
git -C "$R14" merge -q --no-commit other >/dev/null 2>&1 || true
git -C "$R14" rev-parse -q --verify MERGE_HEAD >/dev/null || fail "case14 fixture: merge not in progress"
HEAD14="$(git -C "$R14" rev-parse HEAD)"
INDEX14="$(git -C "$R14" ls-files -s | cksum)"
run_ct "$R14" "${CT[@]}"
eq "$RC" 3 "case14 exit code (stderr: $(cat "$TMP/err"))"
eq "$(wc -l < "$TMP/err" | tr -d ' ')" 1 "case14 stderr is exactly one line"
grep -q '^E3: MERGE_HEAD present' "$TMP/err" || fail "case14 stderr message ($(cat "$TMP/err"))"
eq "$(git -C "$R14" rev-parse HEAD)" "$HEAD14" "case14 HEAD unchanged"
eq "$(git -C "$R14" ls-files -s | cksum)" "$INDEX14" "case14 index unchanged"
eq "$(git -C "$R14" rev-list --merges --count HEAD)" 0 "case14 no merge commit created"
git -C "$R14" rev-parse -q --verify MERGE_HEAD >/dev/null || fail "case14 MERGE_HEAD was disturbed"

# --- 14b. Other in-progress markers: each refuses before any git change
R14B="$TMP/r14b"
mk_repo "$R14B" main
dirty_listed "$R14B"
HEAD14B="$(git -C "$R14B" rev-parse HEAD)"
for m in CHERRY_PICK_HEAD REVERT_HEAD; do
  git -C "$R14B" rev-parse HEAD > "$R14B/.git/$m"
  run_ct "$R14B" "${CT[@]}"
  eq "$RC" 3 "case14b $m exit code"
  grep -q "^E3: $m present" "$TMP/err" || fail "case14b $m stderr ($(cat "$TMP/err"))"
  rm -f "$R14B/.git/$m"
done
for m in rebase-merge rebase-apply sequencer; do
  mkdir "$R14B/.git/$m"
  run_ct "$R14B" "${CT[@]}"
  eq "$RC" 3 "case14b $m exit code"
  grep -q "^E3: $m present" "$TMP/err" || fail "case14b $m stderr ($(cat "$TMP/err"))"
  rmdir "$R14B/.git/$m"
done
eq "$(git -C "$R14B" rev-parse HEAD)" "$HEAD14B" "case14b HEAD unchanged"
eq "$(git -C "$R14B" symbolic-ref --short HEAD)" "main" "case14b branch unchanged"
git -C "$R14B" diff --cached --quiet || fail "case14b index touched"
run_ct "$R14B" "${CT[@]}"
eq "$RC" 0 "case14b clean again after markers removed (stderr: $(cat "$TMP/err"))"

# ===========================================================================
# Staging integration branch + per-task Orchestrator branches (PRD crit 1-10)
# ===========================================================================
# mk_staging <dir> [remote]: repo whose `staging` is one commit ahead of main (adds
# stg.txt, no listed file); pushed with -u when a remote is given; HEAD back on main.
mk_staging() {
  local d="$1" remote="${2:-}"
  mk_repo "$d" main "$remote"
  git -C "$d" switch -q -c staging
  printf 'stg\n' > "$d/stg.txt"
  git -C "$d" add -A; git -C "$d" commit -q -m staging-work
  if [[ -n "$remote" ]]; then git -C "$d" push -q -u origin staging; fi
  git -C "$d" switch -q main
}

TASK_OTHER="$V/02_Tasks/Proj/Other_Run.md"
cat > "$TASK_OTHER" <<EOF
---
project: [[Proj]]
---

## Spec: Other_Run

### Files touched
- [EDIT] \`d.txt\`
EOF

# snap <repo>: everything a refused run must leave identical
snap() {
  git -C "$1" for-each-ref --format='%(refname) %(objectname)'
  git -C "$1" rev-parse HEAD
  git -C "$1" symbolic-ref HEAD
  git -C "$1" ls-files -s | cksum
  git -C "$1" status --porcelain
}

# --- crit 2a. Staging project (local staging), HEAD on main: task branch cut from staging
R2A="$TMP/n_r2a"
mk_staging "$R2A"
STG2A="$(git -C "$R2A" rev-parse staging)"; MAIN2A="$(git -C "$R2A" rev-parse main)"
dirty_listed "$R2A"
run_ct "$R2A" "${CT[@]}"
eq "$RC" 0 "crit2a exit code (stderr: $(cat "$TMP/err"))"
eq "$(git -C "$R2A" symbolic-ref --short HEAD)" "task/Fix_Thing" "crit2a HEAD on task branch"
eq "$(git -C "$R2A" rev-parse 'task/Fix_Thing~1')" "$STG2A" "crit2a parent is the staging tip"
[[ "$(git -C "$R2A" rev-parse 'task/Fix_Thing~1')" != "$MAIN2A" ]] || fail "crit2a parent must not be main"
eq "$(git -C "$R2A" rev-parse staging)" "$STG2A" "crit2a staging unchanged"
eq "$(git -C "$R2A" rev-parse main)" "$MAIN2A" "crit2a main unchanged"
grep -qx 'COMMIT_BRANCH=task/Fix_Thing' "$TMP/out" || fail "crit2a COMMIT_BRANCH marker"
eq "$(committed_files "$R2A")" "a.txt,b.txt,c.txt" "crit2a committed files"

# --- crit 10a. Re-run in the crit-2a repo: no-op, nothing changes
SNAP10A="$(snap "$R2A")"
run_ct "$R2A" "${CT[@]}"
eq "$RC" 0 "crit10a exit code"
grep -qx 'COMMIT_BRANCH=none' "$TMP/out" || fail "crit10a COMMIT_BRANCH none"
grep -qx 'COMMIT_SHA=none' "$TMP/out" || fail "crit10a COMMIT_SHA none"
grep -qx 'COMMIT_STAGED=0' "$TMP/out" || fail "crit10a COMMIT_STAGED 0"
eq "$(snap "$R2A")" "$SNAP10A" "crit10a state unchanged"

# --- crit 2b. Only origin/staging exists: cut from it, no tracking, no local staging, remote untouched
R2B="$TMP/n_r2b"; O2B="$TMP/n_o2b.git"
mk_staging "$R2B" "$O2B"
git -C "$R2B" branch -D staging -q
STG2B="$(git -C "$R2B" rev-parse refs/remotes/origin/staging)"
REMOTE2B="$(git -C "$R2B" ls-remote origin)"
dirty_listed "$R2B"
run_ct "$R2B" "${CT[@]}"
eq "$RC" 0 "crit2b exit code (stderr: $(cat "$TMP/err"))"
eq "$(git -C "$R2B" symbolic-ref --short HEAD)" "task/Fix_Thing" "crit2b HEAD on task branch"
eq "$(git -C "$R2B" rev-parse 'task/Fix_Thing~1')" "$STG2B" "crit2b parent is origin/staging tip"
eq "$(git -C "$R2B" config --get branch.task/Fix_Thing.merge || true)" "" "crit2b no upstream merge config"
eq "$(git -C "$R2B" config --get branch.task/Fix_Thing.remote || true)" "" "crit2b no upstream remote config"
if git -C "$R2B" show-ref --verify --quiet refs/heads/staging; then fail "crit2b local staging created"; fi
eq "$(git -C "$R2B" ls-remote origin)" "$REMOTE2B" "crit2b remote unchanged"

# --- D1 precedence. Local staging ahead of origin/staging wins
R2C="$TMP/n_r2c"; O2C="$TMP/n_o2c.git"
mk_staging "$R2C" "$O2C"
git -C "$R2C" switch -q staging
printf 'more\n' > "$R2C/stg2.txt"; git -C "$R2C" add -A; git -C "$R2C" commit -q -m staging-ahead
git -C "$R2C" switch -q main
dirty_listed "$R2C"
run_ct "$R2C" "${CT[@]}"
eq "$RC" 0 "D1 precedence exit code (stderr: $(cat "$TMP/err"))"
eq "$(git -C "$R2C" rev-parse 'task/Fix_Thing~1')" "$(git -C "$R2C" rev-parse staging)" "D1 precedence parent is local staging tip"
[[ "$(git -C "$R2C" rev-parse staging)" != "$(git -C "$R2C" rev-parse origin/staging)" ]] || fail "D1 precedence fixture"

# --- D1 default branch not resolved in a staging project (main and master, no origin/HEAD)
R2D="$TMP/n_r2d"
mk_staging "$R2D"
git -C "$R2D" branch master main
git -C "$R2D" switch -q master
dirty_listed "$R2D"
run_ct "$R2D" "${CT[@]}"
eq "$RC" 0 "D1 default-not-resolved exit code (stderr: $(cat "$TMP/err"))"
eq "$(git -C "$R2D" symbolic-ref --short HEAD)" "task/Fix_Thing" "D1 default-not-resolved branch"
eq "$(git -C "$R2D" rev-parse 'task/Fix_Thing~1')" "$(git -C "$R2D" rev-parse staging)" "D1 default-not-resolved parent"

# --- crit 3. HEAD on staging: commit lands on a task branch, staging does not move
R3S="$TMP/n_r3s"
mk_staging "$R3S"
git -C "$R3S" switch -q staging
STG3="$(git -C "$R3S" rev-parse staging)"
dirty_listed "$R3S"
run_ct "$R3S" "${CT[@]}"
eq "$RC" 0 "crit3 exit code (stderr: $(cat "$TMP/err"))"
eq "$(git -C "$R3S" symbolic-ref --short HEAD)" "task/Fix_Thing" "crit3 HEAD on task branch"
eq "$(git -C "$R3S" rev-parse 'task/Fix_Thing~1')" "$STG3" "crit3 parent is the old staging tip"
eq "$(git -C "$R3S" rev-parse staging)" "$STG3" "crit3 staging unchanged"

# --- crit 4. HEAD on a feature branch in a staging project: cut from staging, not the feature
R4S="$TMP/n_r4s"
mk_staging "$R4S"
git -C "$R4S" switch -q -c feature/x
printf 'd-feat\n' > "$R4S/d.txt"; git -C "$R4S" commit -q -am feat-work
FEAT4="$(git -C "$R4S" rev-parse feature/x)"
dirty_listed "$R4S"
run_ct "$R4S" "${CT[@]}"
eq "$RC" 0 "crit4 exit code (stderr: $(cat "$TMP/err"))"
eq "$(git -C "$R4S" symbolic-ref --short HEAD)" "task/Fix_Thing" "crit4 HEAD on task branch"
eq "$(git -C "$R4S" rev-parse 'task/Fix_Thing~1')" "$(git -C "$R4S" rev-parse staging)" "crit4 parent is the staging tip"
eq "$(git -C "$R4S" rev-parse feature/x)" "$FEAT4" "crit4 feature branch unchanged"

# --- crit 5. Non-staging feature branch stays put: covered by case 3 above

# --- crit 6. Non-staging: second task of the same run gets its own branch, stacked on HEAD
dirty_one() { printf 'a2\n' > "$1/a.txt"; }
dirty_one "$R4"
run_ct "$R4" --task-path "$TASK_REG" --source-persona Executioner --run-id run-123
eq "$RC" 0 "crit6 exit code (stderr: $(cat "$TMP/err"))"
eq "$(git -C "$R4" symbolic-ref --short HEAD)" "orch/run-123/Reg_Case" "crit6 second task branch"
eq "$(git -C "$R4" for-each-ref --format='%(refname)' refs/heads/orch/run-123/ | wc -l | tr -d ' ')" "2" "crit6 two branches for the run"
eq "$(git -C "$R4" rev-parse 'orch/run-123/Reg_Case~1')" "$(git -C "$R4" rev-parse orch/run-123/Fix_Thing)" "crit6 stacked on first task branch"

# --- crit 7. Ref-name conflicts: E3, one line, nothing mutated
R7="$TMP/n_r7"
mk_repo "$R7" main
git -C "$R7" branch orch/run-7
dirty_listed "$R7"
SNAP7="$(snap "$R7")"
run_ct "$R7" "${CT[@]}" --run-id run-7
eq "$RC" 3 "crit7 exit code"
eq "$(wc -l < "$TMP/err" | tr -d ' ')" "1" "crit7 one stderr line ($(cat "$TMP/err"))"
grep -Eq '^E3:.*orch/run-7' "$TMP/err" || fail "crit7 stderr names the blocker ($(cat "$TMP/err"))"
[[ ! -s "$TMP/out" ]] || fail "crit7 stdout must be empty"
eq "$(snap "$R7")" "$SNAP7" "crit7 nothing mutated"

R7B="$TMP/n_r7b"
mk_repo "$R7B" main
git -C "$R7B" branch orch/run-8/Fix_Thing/old
dirty_listed "$R7B"
SNAP7B="$(snap "$R7B")"
run_ct "$R7B" "${CT[@]}" --run-id run-8
eq "$RC" 3 "crit7 nested exit code"
grep -Eq '^E3:.*orch/run-8/Fix_Thing/old' "$TMP/err" || fail "crit7 nested names the nested branch ($(cat "$TMP/err"))"
eq "$(snap "$R7B")" "$SNAP7B" "crit7 nested nothing mutated"

R7C="$TMP/n_r7c"
mk_repo "$R7C" main
git -C "$R7C" branch task
dirty_listed "$R7C"
SNAP7C="$(snap "$R7C")"
run_ct "$R7C" "${CT[@]}"
eq "$RC" 3 "crit7 task-prefix exit code"
grep -Eq "^E3: branch 'task' exists" "$TMP/err" || fail "crit7 task-prefix names 'task' ($(cat "$TMP/err"))"
eq "$(snap "$R7C")" "$SNAP7C" "crit7 task-prefix nothing mutated"

# --- crit 8. Staging project, --run-id: per-task branch cut from staging, nothing pushed
R8="$TMP/n_r8"; O8="$TMP/n_o8.git"
mk_staging "$R8" "$O8"
STG8="$(git -C "$R8" rev-parse staging)"
REMOTE8="$(git -C "$R8" ls-remote origin)"
dirty_listed "$R8"
run_ct "$R8" "${CT[@]}" --run-id run-s
eq "$RC" 0 "crit8 exit code (stderr: $(cat "$TMP/err"))"
eq "$(git -C "$R8" symbolic-ref --short HEAD)" "orch/run-s/Fix_Thing" "crit8 branch"
eq "$(git -C "$R8" rev-parse 'orch/run-s/Fix_Thing~1')" "$STG8" "crit8 parent is the staging tip"
eq "$(git -C "$R8" rev-parse staging)" "$STG8" "crit8 staging unchanged"
eq "$(git -C "$R8" ls-remote origin)" "$REMOTE8" "crit8 remote unchanged"

# --- amendment 5. Same run again: stacked on HEAD, not cut from staging
dirty_one "$R8"
run_ct "$R8" --task-path "$TASK_REG" --source-persona Executioner --run-id run-s
eq "$RC" 0 "stack exit code (stderr: $(cat "$TMP/err"))"
eq "$(git -C "$R8" symbolic-ref --short HEAD)" "orch/run-s/Reg_Case" "stack branch"
eq "$(git -C "$R8" rev-parse 'orch/run-s/Reg_Case~1')" "$(git -C "$R8" rev-parse orch/run-s/Fix_Thing)" "stack parent is the first task tip"
eq "$(git -C "$R8" rev-parse staging)" "$STG8" "stack staging unchanged"

# --- crit 10b. Orchestrator re-run with nothing dirty: no-op, no branch created
SNAP10B="$(snap "$R8")"
run_ct "$R8" "${CT[@]}" --run-id run-s2
eq "$RC" 0 "crit10b exit code"
grep -qx 'COMMIT_BRANCH=none' "$TMP/out" || fail "crit10b COMMIT_BRANCH none"
grep -qx 'COMMIT_STAGED=0' "$TMP/out" || fail "crit10b COMMIT_STAGED 0"
eq "$(git -C "$R8" for-each-ref refs/heads/orch/run-s2/ | wc -l | tr -d ' ')" "0" "crit10b no run-s2 branch"
eq "$(snap "$R8")" "$SNAP10B" "crit10b state unchanged"

# --- amendment 5 guard. A shorter run id must not stack on a longer run's branch
printf 'd2\n' > "$R8/d.txt"
run_ct "$R8" --task-path "$TASK_OTHER" --source-persona Executioner --run-id run
eq "$RC" 0 "cross-run exit code (stderr: $(cat "$TMP/err"))"
eq "$(git -C "$R8" symbolic-ref --short HEAD)" "orch/run/Other_Run" "cross-run branch"
eq "$(git -C "$R8" rev-parse 'orch/run/Other_Run~1')" "$STG8" "cross-run parent is the staging tip"

# --- D1 fallback from staging: others' edits block the switch; commit built without switching
mk_overlap() { # mk_overlap <dir>: staging also changes d.txt; main has d.txt (out-of-list) and a.txt dirty
  mk_repo "$1" main
  git -C "$1" switch -q -c staging
  printf 'd-stg\n' > "$1/d.txt"; printf 'stg\n' > "$1/stg.txt"
  git -C "$1" add -A; git -C "$1" commit -q -m staging-work
  git -C "$1" switch -q main
  printf 'd-human\n' > "$1/d.txt"; printf 'a1\n' > "$1/a.txt"
}
R9="$TMP/n_r9"
mk_overlap "$R9"
run_ct "$R9" "${CT[@]}" --run-id run-f
eq "$RC" 0 "fallback exit code (stderr: $(cat "$TMP/err"))"
eq "$(git -C "$R9" symbolic-ref --short HEAD)" "main" "fallback HEAD stays on main"
eq "$(git -C "$R9" rev-parse 'orch/run-f/Fix_Thing~1')" "$(git -C "$R9" rev-parse staging)" "fallback parent is the staging tip"
grep -qx 'NOTE: committed onto orch/run-f/Fix_Thing without switching (worktree has overlapping edits)' "$TMP/out" || fail "fallback NOTE ($(cat "$TMP/out"))"
eq "$(cat "$R9/d.txt")" "d-human" "fallback worktree d.txt intact"
eq "$(git -C "$R9" show --name-only --format= orch/run-f/Fix_Thing | paste -sd, -)" "a.txt" "fallback commit holds only the list"
eq "$(git -C "$R9" show orch/run-f/Fix_Thing:d.txt)" "d-stg" "fallback branch keeps the staging d.txt"

R9B="$TMP/n_r9b"
mk_overlap "$R9B"
run_ct "$R9B" "${CT[@]}"
eq "$RC" 2 "fallback interactive exit code"
eq "$(grep -c '^E2:' "$TMP/err")" "1" "fallback interactive one E2 line ($(cat "$TMP/err"))"
if git -C "$R9B" show-ref --verify --quiet refs/heads/task/Fix_Thing; then fail "fallback interactive created a task branch"; fi

# --- 11. Static: no network/integration/history-rewriting git use in the atom
# The in-progress guard must name the rebase-merge git path; that literal is not a git verb.
CODE="$(grep -v '^[[:space:]]*#' "$SCRIPTS/commit_task.sh" | sed 's/rebase-merge//g')"
if printf '%s\n' "$CODE" | grep -Ew 'push|merge|stash|reset'; then fail "case11 forbidden git verb in commit_task.sh"; fi
if printf '%s\n' "$CODE" | grep -F -e '--no-verify' -e 'add -A "'; then fail "case11 forbidden git flag in commit_task.sh"; fi

echo "SMOKE: OK"

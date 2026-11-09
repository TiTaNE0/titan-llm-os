#!/usr/bin/env bash
# test_commit_task.sh
#
# Verification Gateway for Close_Task_Commit_Step.
# Builds throwaway git repos (default branch main and master, a bare origin, a
# feature branch) and drives .scripts/commit_task.sh against a task file whose
# Spec lists the files touched. Asserts: only listed files are committed, a
# task/<slug> branch is created on the default branch, nothing is pushed, the
# Orchestrator refuses out-of-list tracked changes, and the refusal paths.
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

# --- 4. Orchestrator + out-of-list TRACKED change: refused, nothing changed
R4="$TMP/r4"
mk_repo "$R4" main
dirty_listed "$R4"
printf 'd1\n' > "$R4/d.txt"
HEAD4="$(git -C "$R4" rev-parse HEAD)"
BR4="$(git -C "$R4" branch --list | sort | paste -sd, -)"
run_ct "$R4" "${CT[@]}" --run-id run-123
eq "$RC" 3 "case4 exit code"
eq "$(wc -l < "$TMP/err" | tr -d ' ')" 1 "case4 stderr is exactly one line"
grep -q '^E3: out-of-list tracked changes: .*d.txt' "$TMP/err" || fail "case4 stderr message ($(cat "$TMP/err"))"
eq "$(git -C "$R4" rev-parse HEAD)" "$HEAD4" "case4 HEAD unchanged"
eq "$(git -C "$R4" branch --list | sort | paste -sd, -)" "$BR4" "case4 branches unchanged"
git -C "$R4" diff --cached --quiet || fail "case4 index touched"
git -C "$R4" show-ref --verify --quiet refs/heads/orch/run-123 && fail "case4 orch branch created"

# --- 5. Orchestrator + only UNTRACKED out-of-list: commits on orch/<run-id>
R5="$TMP/r5"
mk_repo "$R5" main
dirty_listed "$R5"
printf 'junk\n' > "$R5/junk.txt"
run_ct "$R5" "${CT[@]}" --run-id run-123
eq "$RC" 0 "case5 exit code (stderr: $(cat "$TMP/err"))"
eq "$(git -C "$R5" symbolic-ref --short HEAD)" "orch/run-123" "case5 branch"
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

# --- 11. Static: no network/integration/history-rewriting git use in the atom
# The in-progress guard must name the rebase-merge git path; that literal is not a git verb.
CODE="$(grep -v '^[[:space:]]*#' "$SCRIPTS/commit_task.sh" | sed 's/rebase-merge//g')"
if printf '%s\n' "$CODE" | grep -Ew 'push|merge|stash|reset'; then fail "case11 forbidden git verb in commit_task.sh"; fi
if printf '%s\n' "$CODE" | grep -F -e '--no-verify' -e 'add -A "'; then fail "case11 forbidden git flag in commit_task.sh"; fi

echo "SMOKE: OK"

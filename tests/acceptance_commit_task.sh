#!/usr/bin/env bash
# acceptance_commit_task.sh
#
# Independent acceptance tests for Close_Task_Commit_Step (DoD 2, 3, 4, 5 and the
# stage-only / never-push parts of DoD 1). Attacks .scripts/commit_task.sh from the
# outside with hostile spec shapes, throwaway repos under mktemp, a bare origin and
# a logging `git` shim, and checks the kit command files statically.
#
# Everything runs under /bin/bash (3.2 on macOS): the atom and its sub-scripts are
# launched through a PATH shim that maps `bash` to /bin/bash.
# Never touches the live vault or kit repos (the kit is only read).
#
# Usage: /bin/bash tests/acceptance_commit_task.sh
# Last line: ACCEPTANCE: PASS | FAIL

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# Kit location: KIT env override, else $HOME/AI_Workflow/claude-agent-kit; kit-file
# assertions are skipped (SKIP line) when that directory is absent.
KIT="${KIT:-$HOME/AI_Workflow/claude-agent-kit}"
SCRIPTS="$REPO_ROOT/.scripts"

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export LC_ALL=C

PASSES=0
FAILS=0
pass() { PASSES=$((PASSES + 1)); echo "  ok   - $1"; }
fail() { FAILS=$((FAILS + 1)); echo "  FAIL - $1" >&2; [ -n "${2:-}" ] && printf '         %s\n' "$2" >&2; return 0; }
eq()   { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "expected [$3] got [$2]"; fi; }
has()  { case "$2" in *"$3"*) pass "$1" ;; *) fail "$1" "missing [$3] in [$2]" ;; esac; }
hasnt() { case "$2" in *"$3"*) fail "$1" "unexpected [$3] in [$2]" ;; *) pass "$1" ;; esac; }
rc_is() { eq "$1 (exit code)" "$RC" "$2"; }
section() { echo; echo "== $1"; }

TMP="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

REALGIT="$(command -v git)"
V="$TMP/vault"
S="$V/.scripts"
SHIM="$TMP/shim"
GITLOG="$TMP/git_calls.log"
: > "$GITLOG"
mkdir -p "$S" "$V/04_Logs/Telemetry" "$V/02_Tasks/Proj" "$SHIM" "$TMP/outside"
cp "$SCRIPTS/commit_task.sh" "$SCRIPTS/persona_check.sh" "$SCRIPTS/emit_telemetry.sh" "$S/"
state_persona() {
  printf '{\n  "persona": "%s",\n  "session_id": "acc",\n  "started_at": "2026-06-14T00:00:00Z",\n  "agent_surface": "test"\n}\n' "$1" > "$V/.session_state.json"
}
state_persona Executioner
echo "outside" > "$TMP/outside/z.txt"

# git shim logs every invocation made by the atom; bash shim forces 3.2 everywhere.
printf '#!/bin/bash\nprintf "%%s\\n" "$*" >> "$GITLOG"\nexec "%s" "$@"\n' "$REALGIT" > "$SHIM/git"
chmod +x "$SHIM/git"
ln -s /bin/bash "$SHIM/bash"

# ---------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------
N=0
REPO=""; ORIGIN=""; BASE=""

# mk_repo <default-branch> [remote]
mk_repo() {
  local br="$1" remote="${2:-}"
  N=$((N + 1))
  BASE="$TMP/s$N"; REPO="$BASE/repo"; ORIGIN="$BASE/origin.git"
  mkdir -p "$REPO/sub" "$REPO/docs" "$REPO/gone"
  echo "outside-of-repo sibling" > "$BASE/outside_repo.txt"
  "$REALGIT" init -q -b "$br" "$REPO"
  g config user.name Test; g config user.email test@example.com
  g config core.quotepath off
  local f
  for f in a.txt c.txt d.txt old.txt risk.txt late.txt second.txt decoy_research.txt \
           "café.txt" "docs/my file.md" sub/s.txt gone/x.txt; do
    printf '%s0\n' "$f" > "$REPO/$f"
  done
  printf 'ignored.log\n' > "$REPO/.gitignore"
  g add -A; g commit -q -m init
  if [ -n "$remote" ]; then
    "$REALGIT" init -q --bare -b "$br" "$ORIGIN"
    g remote add origin "$ORIGIN"
    g push -q -u origin "$br" 2>/dev/null
    g remote set-head origin "$br"
  fi
}
g() { "$REALGIT" -C "$REPO" "$@"; }

# mk_task <Name>  (Files touched block on stdin; @OUT@ -> $TMP/outside)
mk_task() {
  local name="$1" f="$V/02_Tasks/Proj/$1.md" blk
  blk="$(sed "s|@OUT@|$TMP/outside|g")"
  {
    printf -- '---\nproject: [[Proj]]\nstatus: in_progress\n---\n\n# Task: %s\n\n' "$name"
    printf '## 🔬 Research Notes\n\n### Files touched\n- [EDIT] `decoy_research.txt`\n\n'
    printf '## 📐 Spec\n> placeholder\n<!-- write_task_section section=spec -->\n\n## Spec: %s\n\n### Summary\nx\n\n### Files touched\n' "$name"
    printf '%s\n' "$blk"
    printf '\n### Risks\n- [EDIT] `risk.txt` is only mentioned in Risks\n\n'
    printf '### Files touched (addendum)\n- [EDIT] `second.txt`\n\n'
    printf '## ✅ Validator Report\n- [NEW] `late.txt` must not be parsed\n\n### Files touched\n- [EDIT] `late.txt`\n'
  } > "$f"
  TASKNAME="$name"; TASKFILE="$f"
}

dirty_decoys() {
  local f
  for f in d.txt risk.txt late.txt second.txt decoy_research.txt; do echo "dirty" >> "$REPO/$f"; done
  echo "junk" > "$REPO/junk.txt"
}

# run <cwd> <atom args...> -> RC OUT ERR
run() {
  local cwd="$1"; shift
  RC=0
  ( cd "$cwd" && env PATH="$SHIM:$PATH" GITLOG="$GITLOG" bash "$S/commit_task.sh" "$@" ) >"$TMP/stdout" 2>"$TMP/stderr" || RC=$?
  OUT="$(cat "$TMP/stdout")"; ERR="$(cat "$TMP/stderr")"
}
# irun <TaskName> [extra atom args]  (interactive unless --run-id given)
irun() { local t="$1"; shift; run "$REPO" --task-path "$V/02_Tasks/Proj/$t.md" --source-persona Executioner "$@"; }

committed() { g show --no-renames --name-only --format= HEAD | LC_ALL=C sort; }
sorted() { printf '%s\n' "$@" | LC_ALL=C sort; }
head_ref() { g rev-parse "refs/heads/$1" 2>/dev/null; }
cur_branch() { g symbolic-ref -q --short HEAD 2>/dev/null; }
origin_state() { { "$REALGIT" -C "$ORIGIN" for-each-ref; find "$ORIGIN/objects" -type f | wc -l; } | shasum -a 1; }
vault_state() { find "$V" -type f ! -path "$V/04_Logs/*" -print0 | sort -z | xargs -0 shasum -a 1 | shasum -a 1; }

settle() { ( sleep 1; g status >/dev/null 2>&1; g status >/dev/null 2>&1 ); }
snap() {
  ( cd "$REPO" && {
      g rev-parse HEAD 2>&1; g symbolic-ref -q HEAD 2>&1; g for-each-ref 2>&1
      g ls-files -s; shasum -a 1 .git/index
      find . -path ./.git -prune -o -type f -print0 | sort -z | xargs -0 shasum -a 1
    } | shasum -a 1 )
}
stdout_line() { printf '%s\n' "$OUT" | grep -E "^$1=" | head -n 1 | sed "s/^$1=//"; }
errlines() { [ -z "$ERR" ] && echo 0 || printf '%s\n' "$ERR" | wc -l | tr -d ' '; }

# ===========================================================================
section "(a) Stage ONLY listed files: kitchen-sink hostile spec, interactive, on main, bare origin"
# ===========================================================================
mk_repo main remote
mk_task Kitchen_Sink <<'EOF'
- [EDIT] `docs/my file.md` (path with spaces)
- [EDIT] `café.txt` (non-ascii)
- [NEW] `n1.txt` — owns: a thing; existing owner: `d.txt`
- [NEW] n2.txt — owns: something that lives next to d.txt
- [NEW] `n3.txt` owns: no em dash, existing owner: `a.txt`
- [DELETE] `c.txt`
- [DELETE] `gone/x.txt` (whole directory removed on disk)
- [NEW] `-rf.txt` (leading dash)
- [NEW] `newdir/deep/f.txt` (untracked, new directories)
- [EDIT] `sub` (a directory)
- [EDIT] `sub/` (a directory, trailing slash)
- [NEW] `ignored.log` (gitignored)
- [EDIT] `*.txt` (glob must stay literal)
- [EDIT] `[ab].txt` (glob must stay literal)
- [EDIT] `:(exclude)a.txt` (pathspec magic must stay literal)
- [EDIT] `../outside_repo.txt` (relative, outside repo)
- [EDIT] `@OUT@/z.txt` (absolute, outside repo)
- [EDIT] `ghost.txt` (nowhere)
EOF
echo "docs-dirty" >> "$REPO/docs/my file.md"
echo "cafe-dirty" >> "$REPO/café.txt"
echo n1 > "$REPO/n1.txt"; echo n2 > "$REPO/n2.txt"; echo n3 > "$REPO/n3.txt"
rm "$REPO/c.txt"; rm -rf "$REPO/gone"
echo rf > "$REPO/-rf.txt"
mkdir -p "$REPO/newdir/deep"; echo f > "$REPO/newdir/deep/f.txt"
echo "sub-dirty" >> "$REPO/sub/s.txt"
echo "ign" > "$REPO/ignored.log"
echo "a-dirty" >> "$REPO/a.txt"
echo "outside-dirty" >> "$BASE/outside_repo.txt"
dirty_decoys
mkdir -p "$REPO/.git/hooks"
printf '#!/bin/sh\ntouch "%s/PUSH_HOOK_RAN"\n' "$BASE" > "$REPO/.git/hooks/pre-push"; chmod +x "$REPO/.git/hooks/pre-push"
MAIN0="$(head_ref main)"; ORIGIN0="$(origin_state)"; RT0="$(g rev-parse refs/remotes/origin/main)"
TASK0="$(shasum -a 1 < "$TASKFILE")"; VAULT0="$(vault_state)"; OUTSIDE0="$(shasum -a 1 < "$BASE/outside_repo.txt")"
TELE0="$(cat "$V"/04_Logs/Telemetry/*.jsonl 2>/dev/null | wc -l | tr -d ' ')"
irun Kitchen_Sink
rc_is "kitchen sink" 0
eq "task branch created from default" "$(cur_branch)" "task/Kitchen_Sink"
eq "commit contains EXACTLY the listed, dirty, in-repo files" "$(committed)" \
   "$(sorted '-rf.txt' 'c.txt' 'café.txt' 'docs/my file.md' 'gone/x.txt' 'n1.txt' 'n2.txt' 'n3.txt' 'newdir/deep/f.txt')"
eq "COMMIT_STAGED matches" "$(stdout_line COMMIT_STAGED)" "9"
eq "COMMIT_BRANCH reported" "$(stdout_line COMMIT_BRANCH)" "task/Kitchen_Sink"
eq "COMMIT_SHA is the new HEAD" "$(stdout_line COMMIT_SHA)" "$(g rev-parse --short HEAD)"
eq "first stdout line is COMMIT_BRANCH (parser contract)" "$(printf '%s\n' "$OUT" | head -n 1 | cut -d= -f1)" "COMMIT_BRANCH"
eq "default branch ref unchanged" "$(head_ref main)" "$MAIN0"
eq "origin/main tracking ref unchanged" "$(g rev-parse refs/remotes/origin/main)" "$RT0"
eq "bare origin byte-identical (refs + objects): nothing pushed" "$(origin_state)" "$ORIGIN0"
[ ! -e "$BASE/PUSH_HOOK_RAN" ] && pass "pre-push hook never fired" || fail "pre-push hook fired"
eq "index is empty after commit (nothing left staged)" "$(g diff --cached --name-only)" ""
eq "d.txt (named only in an owns: suffix) still modified, unstaged" "$(g status --porcelain=v1 d.txt)" " M d.txt"
eq "a.txt (hit by glob/magic entries) still modified, unstaged" "$(g status --porcelain=v1 a.txt)" " M a.txt"
eq "sub/s.txt (directory entry) still modified, unstaged" "$(g status --porcelain=v1 sub/s.txt)" " M sub/s.txt"
eq "ignored.log not tracked" "$(g ls-files ignored.log)" ""
eq "outside-repo file untouched" "$(shasum -a 1 < "$BASE/outside_repo.txt")" "$OUTSIDE0"
for f in risk.txt late.txt second.txt decoy_research.txt; do
  eq "decoy section path $f not committed" "$(g status --porcelain=v1 "$f")" " M $f"
done
eq "task file byte-identical" "$(shasum -a 1 < "$TASKFILE")" "$TASK0"
eq "vault (non-log) byte-identical" "$(vault_state)" "$VAULT0"
for f in d.txt a.txt risk.txt late.txt second.txt decoy_research.txt sub/s.txt junk.txt; do
  has "WARN_OUT_OF_LIST names $f" "$OUT" "WARN_OUT_OF_LIST: $f"
done
hasnt "WARN never names a committed file" "$OUT" "WARN_OUT_OF_LIST: n1.txt"
has "SKIPPED directory (sub)" "$OUT" "SKIPPED: sub (directory)"
has "SKIPPED ignored" "$OUT" "SKIPPED: ignored.log (ignored)"
has "SKIPPED outside-repo (relative ..)" "$OUT" "SKIPPED: ../outside_repo.txt (outside-repo)"
has "SKIPPED outside-repo (absolute)" "$OUT" "(outside-repo)"
has "SKIPPED not-found" "$OUT" "SKIPPED: ghost.txt (not-found)"
eq "subject line" "$(g log -1 --format=%s)" "task(Proj): Kitchen_Sink"
has "body closes the task" "$(g log -1 --format=%b)" "Closes [[Kitchen_Sink]] via /close_task."
hasnt "interactive message carries no Orchestrator line" "$(g log -1 --format=%B)" "Orchestrator run"
TELE1="$(cat "$V"/04_Logs/Telemetry/*.jsonl 2>/dev/null | wc -l | tr -d ' ')"
eq "exactly one telemetry record emitted on success" "$((TELE1 - TELE0))" "1"
has "telemetry names the atom, success, Executioner" "$(tail -n 1 "$V"/04_Logs/Telemetry/*.jsonl | tail -n 1)" "commit_task"

# ===========================================================================
section "(a) Idempotency: re-run after success is a no-op"
# ===========================================================================
HEAD1="$(g rev-parse HEAD)"
irun Kitchen_Sink
rc_is "re-run" 0
eq "re-run: COMMIT_SHA=none" "$(stdout_line COMMIT_SHA)" "none"
eq "re-run: HEAD unchanged" "$(g rev-parse HEAD)" "$HEAD1"
eq "re-run: still on task branch" "$(cur_branch)" "task/Kitchen_Sink"

# ===========================================================================
section "(a) Rename (R) entries"
# ===========================================================================
# R1: staged rename, only the NEW name listed -> old.txt is staged out-of-list
mk_repo main
mk_task Ren_One <<'EOF'
- [NEW] `renamed.txt`
EOF
g mv old.txt renamed.txt
settle; S0="$(snap)"
irun Ren_One
rc_is "staged rename, only destination listed" 3
has "refusal names the origin path old.txt" "$ERR" "old.txt"
eq "refusal changed nothing" "$(snap)" "$S0"

# R2: staged rename, both ends listed
mk_repo main
mk_task Ren_Two <<'EOF'
- [DELETE] `old.txt`
- [NEW] `docs/new name.txt` (rename target with a space)
EOF
g mv old.txt "docs/new name.txt"
irun Ren_Two
rc_is "staged rename, both ends listed" 0
eq "both ends committed" "$(committed)" "$(sorted 'docs/new name.txt' 'old.txt')"
eq "rename recorded as a rename" "$(g show -M --name-status --format= HEAD | cut -c1)" "R"

# R3: unstaged rename (mv), only the destination listed, interactive
mk_repo main
mk_task Ren_Three <<'EOF'
- [NEW] `renamed.txt`
EOF
mv "$REPO/old.txt" "$REPO/renamed.txt"
irun Ren_Three
rc_is "unstaged rename, only destination listed (interactive)" 0
eq "only the destination is committed" "$(committed)" "renamed.txt"
eq "old.txt deletion left unstaged" "$(g status --porcelain=v1 old.txt)" " D old.txt"
has "old.txt reported as out-of-list" "$OUT" "WARN_OUT_OF_LIST: old.txt"

# R4: Orchestrator, unstaged rename, only destination listed -> tracked delete out-of-list
mk_repo main
mk_task Ren_Four <<'EOF'
- [NEW] `renamed.txt`
EOF
mv "$REPO/old.txt" "$REPO/renamed.txt"
settle; S0="$(snap)"
irun Ren_Four --run-id r4
rc_is "Orchestrator, rename with origin unlisted" 3
eq "refusal changed nothing" "$(snap)" "$S0"

# R5: Orchestrator, staged rename, both ends listed
mk_repo main
mk_task Ren_Five <<'EOF'
- [DELETE] `old.txt`
- [NEW] `renamed.txt`
EOF
g mv old.txt renamed.txt
irun Ren_Five --run-id r5
rc_is "Orchestrator, staged rename, both listed" 0
eq "on orch branch" "$(cur_branch)" "orch/r5"
eq "both ends committed" "$(committed)" "$(sorted old.txt renamed.txt)"

# ===========================================================================
section "(a) [DELETE] shapes"
# ===========================================================================
mk_repo main
mk_task Del_Staged <<'EOF'
- [DELETE] `c.txt`
- [DELETE] `never-existed.txt`
EOF
g rm -q c.txt
irun Del_Staged
rc_is "git rm'd (staged) delete" 0
eq "deletion committed" "$(g show --name-status --format= HEAD)" "$(printf 'D\tc.txt')"
has "never-tracked delete reported not-found" "$OUT" "SKIPPED: never-existed.txt (not-found)"

# ===========================================================================
section "(a) Parser: other sections, deeper headings, CRLF"
# ===========================================================================
mk_repo main
mk_task Subheading <<'EOF'
- [EDIT] `a.txt`
#### Architect-only
- [EDIT] `c.txt`
EOF
echo x >> "$REPO/a.txt"; echo x >> "$REPO/c.txt"; dirty_decoys
irun Subheading
rc_is "deeper sub-heading inside the block" 0
eq "level-4 sub-heading entries stay in the block; Risks/addendum/Validator/Research do not" "$(committed)" "$(sorted a.txt c.txt)"

mk_repo main
mk_task Crlf <<'EOF'
- [EDIT] `a.txt`
- [EDIT] c.txt
EOF
sed 's/$/\r/' "$TASKFILE" > "$TASKFILE.crlf" && mv "$TASKFILE.crlf" "$TASKFILE"
echo x >> "$REPO/a.txt"; echo x >> "$REPO/c.txt"
irun Crlf
rc_is "CRLF task file" 0
eq "CRLF: backticked and bare paths both parsed" "$(committed)" "$(sorted a.txt c.txt)"

mk_repo main
mk_task Spec_Only_In_Risks <<'EOF'
Nothing marked here.
EOF
echo x >> "$REPO/risk.txt"; echo x >> "$REPO/late.txt"
irun Spec_Only_In_Risks
rc_is "markers only outside the Files touched block" 3
eq "E3 is a single stderr line" "$(errlines)" "1"
eq "nothing committed" "$(g rev-list --count HEAD)" "1"

# ===========================================================================
section "(a) cwd variants: subdirectory and symlinked path"
# ===========================================================================
mk_repo main
mk_task Cwd_Sub <<'EOF'
- [EDIT] `a.txt`
EOF
echo x >> "$REPO/a.txt"
run "$REPO/sub" --task-path "$TASKFILE" --source-persona Executioner
rc_is "run from a subdirectory of the repo" 0
eq "paths resolve against the toplevel, not cwd" "$(committed)" "a.txt"

mk_repo main
ln -s "$REPO" "$BASE/link"
mk_task Cwd_Link <<EOF
- [EDIT] \`$BASE/link/a.txt\`
EOF
echo x >> "$REPO/a.txt"
run "$BASE/link" --task-path "$TASKFILE" --source-persona Executioner
rc_is "cwd and spec path reached through a symlink" 0
eq "symlinked absolute path canonicalised into the repo" "$(committed)" "a.txt"

mk_repo main
mk_task Cwd_Rel <<'EOF'
- [EDIT] `a.txt`
EOF
echo x >> "$REPO/a.txt"
RC=0; ( cd "$V" && cd "$REPO" && env PATH="$SHIM:$PATH" GITLOG="$GITLOG" bash "$S/commit_task.sh" --task-path "../../vault/02_Tasks/Proj/Cwd_Rel.md" --source-persona Executioner ) >/dev/null 2>&1 || RC=$?
eq "relative --task-path resolved against cwd (exit)" "$RC" "0"
eq "relative --task-path: listed file committed" "$(committed)" "a.txt"

# ===========================================================================
section "(a) Task-name hostility: spaces, odd chars, unusable branch names"
# ===========================================================================
mk_repo main
mk_task "My Task: v2" <<'EOF'
- [EDIT] `a.txt`
EOF
echo x >> "$REPO/a.txt"
irun "My Task: v2"
rc_is "task name with space and colon" 0
eq "branch slug sanitised, case preserved" "$(cur_branch)" "task/My-Task--v2"

mk_repo main
mk_task "Bad..Name" <<'EOF'
- [EDIT] `a.txt`
EOF
echo x >> "$REPO/a.txt"
settle; S0="$(snap)"
irun "Bad..Name"
rc_is "task name giving an invalid ref" 3
eq "refusal changed nothing (still on main, nothing staged)" "$(snap)" "$S0"

# ===========================================================================
section "(b) Never pushes, never merges, never moves the default-branch ref"
# ===========================================================================
mk_repo main remote
mk_task Orch_Remote <<'EOF'
- [EDIT] `a.txt`
EOF
echo x >> "$REPO/a.txt"; echo junk > "$REPO/untracked-junk.txt"
MAIN0="$(head_ref main)"; ORIGIN0="$(origin_state)"
irun Orch_Remote --run-id run-123
rc_is "Orchestrator happy path" 0
eq "on orch/run-123" "$(cur_branch)" "orch/run-123"
eq "only the listed file committed" "$(committed)" "a.txt"
eq "main ref unchanged" "$(head_ref main)" "$MAIN0"
eq "origin byte-identical" "$(origin_state)" "$ORIGIN0"
eq "untracked out-of-list stays untracked" "$(g status --porcelain=v1 untracked-junk.txt)" "?? untracked-junk.txt"
hasnt "Orchestrator mode prints no WARN lines" "$OUT" "WARN_OUT_OF_LIST"
has "commit message carries the run id" "$(g log -1 --format=%B)" "Orchestrator run: run-123"
eq "orch branch parent is the old main tip" "$(g rev-parse HEAD~1)" "$MAIN0"

# second task, same run: stacks on the existing orch branch, still no push
mk_task Orch_Second <<'EOF'
- [EDIT] `c.txt`
EOF
echo x >> "$REPO/c.txt"
irun Orch_Second --run-id run-123
rc_is "second task in the same run" 0
eq "stays on orch/run-123" "$(cur_branch)" "orch/run-123"
eq "main ref still unchanged" "$(head_ref main)" "$MAIN0"
eq "origin still byte-identical" "$(origin_state)" "$ORIGIN0"

# existing task/<slug> branch (retry) with a compatible tree
mk_repo main remote
mk_task Retry_Branch <<'EOF'
- [EDIT] `a.txt`
EOF
g branch task/Retry_Branch
echo x >> "$REPO/a.txt"
MAIN0="$(head_ref main)"
irun Retry_Branch
rc_is "pre-existing task branch" 0
eq "switched to the existing branch (no -c)" "$(cur_branch)" "task/Retry_Branch"
eq "main unchanged" "$(head_ref main)" "$MAIN0"

# existing task branch that conflicts with the dirty tree -> E2, nothing lands anywhere
mk_repo main remote
mk_task Conflict_Branch <<'EOF'
- [EDIT] `a.txt`
EOF
g switch -q -c task/Conflict_Branch; echo other > "$REPO/a.txt"; g commit -q -am diverge; g switch -q main
echo mine >> "$REPO/a.txt"
MAIN0="$(head_ref main)"; TB0="$(head_ref task/Conflict_Branch)"
irun Conflict_Branch
rc_is "switch to a conflicting existing branch" 2
eq "main unchanged" "$(head_ref main)" "$MAIN0"
eq "task branch tip unchanged" "$(head_ref task/Conflict_Branch)" "$TB0"
eq "still on main" "$(cur_branch)" "main"
eq "dirty edit preserved" "$(g status --porcelain=v1 a.txt)" " M a.txt"

# custom default branch from origin/HEAD
mk_repo develop remote
mk_task Custom_Default <<'EOF'
- [EDIT] `a.txt`
EOF
echo x >> "$REPO/a.txt"
DEV0="$(head_ref develop)"
irun Custom_Default
rc_is "default branch = origin/HEAD (develop)" 0
eq "task branch cut from develop" "$(cur_branch)" "task/Custom_Default"
eq "develop unchanged" "$(head_ref develop)" "$DEV0"

# master, no remote
mk_repo master
mk_task On_Master <<'EOF'
- [EDIT] `a.txt`
EOF
echo x >> "$REPO/a.txt"
M0="$(head_ref master)"
irun On_Master
rc_is "master without any remote" 0
eq "task branch from master" "$(cur_branch)" "task/On_Master"
eq "master unchanged" "$(head_ref master)" "$M0"

# feature branch: stay put, no new branch
mk_repo main remote
mk_task On_Feature <<'EOF'
- [EDIT] `a.txt`
EOF
g switch -q -c feature/x; echo x >> "$REPO/a.txt"
MAIN0="$(head_ref main)"
irun On_Feature
rc_is "feature branch" 0
eq "committed on the current branch" "$(cur_branch)" "feature/x"
eq "no task/ branch created" "$(g branch --list 'task/*' | wc -l | tr -d ' ')" "0"
eq "main unchanged" "$(head_ref main)" "$MAIN0"

# undeterminable default branch
mk_repo trunk
mk_task No_Default <<'EOF'
- [EDIT] `a.txt`
EOF
echo x >> "$REPO/a.txt"
settle; S0="$(snap)"
irun No_Default
rc_is "no origin/HEAD, no main, no master" 3
eq "refusal changed nothing" "$(snap)" "$S0"

# --- default-branch rule: origin/HEAD; else exactly one of main/master; both or neither = E3
# both main and master, no origin/HEAD, sitting on master (the reproduced bug)
mk_repo master
g branch main
mk_task Both_On_Master <<'EOF'
- [EDIT] `a.txt`
EOF
echo x >> "$REPO/a.txt"
settle; S0="$(snap)"
irun Both_On_Master
rc_is "main AND master, no origin/HEAD, sitting on master" 3
eq "refusal changed nothing (no commit on master, no task branch)" "$(snap)" "$S0"
eq "E3 on one stderr line" "$(errlines)" "1"
has "message says the default branch is ambiguous" "$ERR" "E3: default branch ambiguous"
eq "stdout empty on refusal" "$OUT" ""
irun Both_On_Master --run-id run-1
rc_is "main AND master, Orchestrator mode (orch/ target needs no default)" 0
eq "Orchestrator commit lands on orch/run-1" "$(cur_branch)" "orch/run-1"

# both, sitting on main
mk_repo main
g branch master
mk_task Both_On_Main <<'EOF'
- [EDIT] `a.txt`
EOF
echo x >> "$REPO/a.txt"
settle; S0="$(snap)"
irun Both_On_Main
rc_is "main AND master, no origin/HEAD, sitting on main" 3
eq "refusal changed nothing" "$(snap)" "$S0"

# both, but origin/HEAD decides
mk_repo master remote
g branch main
mk_task Both_With_Head <<'EOF'
- [EDIT] `a.txt`
EOF
echo x >> "$REPO/a.txt"
M0="$(head_ref master)"
irun Both_With_Head
rc_is "main AND master with origin/HEAD=master" 0
eq "task branch cut from the origin/HEAD branch" "$(cur_branch)" "task/Both_With_Head"
eq "master unchanged" "$(head_ref master)" "$M0"

# only main, no remote
mk_repo main
mk_task Only_Main <<'EOF'
- [EDIT] `a.txt`
EOF
echo x >> "$REPO/a.txt"
irun Only_Main
rc_is "only main, no remote" 0
eq "task branch created" "$(cur_branch)" "task/Only_Main"

# --- in-progress operation guard: refused before any git change
mk_repo main
mk_task Merging <<'EOF'
- [EDIT] `a.txt`
EOF
g switch -q -c other; echo a-other > "$REPO/a.txt"; g commit -q -am other; g switch -q main
g switch -q -c feature; echo d-feature > "$REPO/d.txt"; g commit -q -am feature
g merge -q --no-commit other >/dev/null 2>&1 || true
g rev-parse -q --verify MERGE_HEAD >/dev/null && pass "fixture: merge --no-commit left MERGE_HEAD" || fail "fixture: merge not in progress"
H0="$(g rev-parse HEAD)"
settle; S0="$(snap)"
irun Merging
rc_is "merge in progress touching only a listed path" 3
eq "E3 on one stderr line" "$(errlines)" "1"
has "message names MERGE_HEAD" "$ERR" "E3: MERGE_HEAD present"
eq "HEAD, refs, index and worktree unchanged" "$(snap)" "$S0"
eq "no merge commit created" "$(g rev-list --merges --count HEAD)" "0"
eq "HEAD is the same commit" "$(g rev-parse HEAD)" "$H0"
irun Merging --run-id run-1
rc_is "merge in progress, Orchestrator mode" 3
eq "Orchestrator refusal changed nothing" "$(snap)" "$S0"
eq "no orch/ branch created" "$(g branch --list 'orch/*' | wc -l | tr -d ' ')" "0"

mk_repo main
mk_task Marker_Dirs <<'EOF'
- [EDIT] `a.txt`
EOF
echo x >> "$REPO/a.txt"
settle; S0="$(snap)"
for m in CHERRY_PICK_HEAD REVERT_HEAD; do
  g rev-parse HEAD > "$REPO/.git/$m"
  irun Marker_Dirs
  rc_is "$m present" 3
  has "$m message" "$ERR" "E3: $m present"
  rm -f "$REPO/.git/$m"
done
for m in rebase-merge rebase-apply sequencer; do
  mkdir "$REPO/.git/$m"
  irun Marker_Dirs
  rc_is "$m present" 3
  has "$m message" "$ERR" "E3: $m present"
  rmdir "$REPO/.git/$m"
done
eq "markers removed, repo identical to the start" "$(snap)" "$S0"
irun Marker_Dirs
rc_is "works again once the markers are gone" 0

section "(b) Every git invocation the atom made, across all runs above"
FORBID=0
while IFS= read -r line; do
  sub="${line%% *}"
  case "$sub" in
    push|merge|pull|fetch|rebase|reset|stash|clean|cherry-pick|revert|checkout|restore|tag|am|apply|rm|mv|branch|update-ref|symbolic-ref-write)
      case "$sub $line" in
        "branch "*) ;;
        *) FORBID=$((FORBID + 1)); echo "         forbidden git call: git $line" >&2 ;;
      esac ;;
  esac
  case "$line" in
    commit*--no-verify*|commit*" -n"*|commit*--amend*|commit*" -a"*|commit*--all*) FORBID=$((FORBID + 1)); echo "         forbidden commit flags: git $line" >&2 ;;
    add*) case "$line" in "add -A -- "?*) ;; *) FORBID=$((FORBID + 1)); echo "         add without pathspec: git $line" >&2 ;; esac ;;
  esac
done < "$GITLOG"
eq "no forbidden git subcommand or flag in the call log" "$FORBID" "0"
[ -s "$GITLOG" ] && pass "git shim actually observed the atom's calls ($(wc -l < "$GITLOG" | tr -d ' ') calls)" || fail "git shim saw no calls (harness broken)"

# ===========================================================================
section "(d) Orchestrator refusals leave HEAD / branches / index / worktree byte-identical"
# ===========================================================================
refusal() { # refusal <desc> <expected-rc>  (call after settle+snap into S0)
  rc_is "$1" "$2"
  eq "$1: snapshot identical" "$(snap)" "$S0"
  eq "$1: no orch/ branch created" "$(g branch --list 'orch/*' | wc -l | tr -d ' ')" "0"
}

mk_repo main remote
mk_task Orch_Tracked <<'EOF'
- [EDIT] `a.txt`
EOF
echo x >> "$REPO/a.txt"; echo x >> "$REPO/d.txt"
settle; S0="$(snap)"
irun Orch_Tracked --run-id run-1
refusal "tracked out-of-list change" 3
eq "E3 on one stderr line" "$(errlines)" "1"
has "message starts E3 and names d.txt" "$ERR" "E3: out-of-list tracked changes: d.txt"
eq "stdout empty on refusal" "$OUT" ""

mk_repo main
mk_task Orch_Tracked_Clean <<'EOF'
- [EDIT] `a.txt`
EOF
echo x >> "$REPO/d.txt"
settle; S0="$(snap)"
irun Orch_Tracked_Clean --run-id run-1
refusal "tracked out-of-list change while nothing listed is dirty (no no-op loophole)" 3

mk_repo main
mk_task Orch_Staged <<'EOF'
- [EDIT] `a.txt`
EOF
echo x >> "$REPO/a.txt"; echo x >> "$REPO/d.txt"; g add d.txt
settle; S0="$(snap)"
irun Orch_Staged --run-id run-1
refusal "out-of-list path pre-staged" 3

mk_repo main
mk_task Orch_Detached <<'EOF'
- [EDIT] `a.txt`
EOF
g checkout -q --detach; echo x >> "$REPO/a.txt"
settle; S0="$(snap)"
irun Orch_Detached --run-id run-1
refusal "detached HEAD" 3

mk_repo main
printf -- '---\nproject: [[Proj]]\n---\n\n## 📐 Spec\n\n## Spec: No_Block\n\n### Summary\nnothing\n\n## Other\n- [EDIT] `a.txt`\n' > "$V/02_Tasks/Proj/No_Block.md"
echo x >> "$REPO/a.txt"
settle; S0="$(snap)"
irun No_Block --run-id run-1
refusal "no Files touched block (marker only in another section)" 3

mk_repo main
mk_task Unparsable <<'EOF'
- [EDIT] the build config (no path)
EOF
echo x >> "$REPO/a.txt"
settle; S0="$(snap)"
irun Unparsable --run-id run-1
refusal "marked entries without any parsable path" 3

for rid in '..' 'a..b' '.hidden' 'x.lock'; do
  mk_repo main
  mk_task Bad_Run <<'EOF'
- [EDIT] `a.txt`
EOF
  echo x >> "$REPO/a.txt"
  settle; S0="$(snap)"
  irun Bad_Run --run-id "$rid"
  refusal "invalid run id '$rid'" 3
done

mk_repo main
mk_task Empty_Run <<'EOF'
- [EDIT] `a.txt`
EOF
echo x >> "$REPO/a.txt"
settle; S0="$(snap)"
irun Empty_Run --run-id ""
refusal "empty --run-id" 3

mk_repo main
mk_task Inject_Run <<'EOF'
- [EDIT] `a.txt`
EOF
echo x >> "$REPO/a.txt"
irun Inject_Run --run-id 'r 1; touch PWNED $(id)'
rc_is "shell metacharacters in run id" 0
case "$(cur_branch)" in orch/*) pass "branch created under orch/" ;; *) fail "branch under orch/" "$(cur_branch)" ;; esac
case "$(cur_branch)" in *[!A-Za-z0-9._/-]*) fail "branch name sanitised" "$(cur_branch)" ;; *) pass "branch name sanitised" ;; esac
[ ! -e "$REPO/PWNED" ] && [ ! -e "$BASE/PWNED" ] && pass "no injection" || fail "injected command ran"

mk_repo main
mk_task Orch_Branch_Conflict <<'EOF'
- [EDIT] `a.txt`
EOF
g switch -q -c orch/run-1; echo other > "$REPO/a.txt"; g commit -q -am other; g switch -q main
echo mine >> "$REPO/a.txt"
settle; S0="$(snap)"
irun Orch_Branch_Conflict --run-id run-1
rc_is "existing orch branch that conflicts (E2)" 2
eq "E2: snapshot identical" "$(snap)" "$S0"

section "(d) Persona and argument refusals"
mk_repo main
mk_task Persona <<'EOF'
- [EDIT] `a.txt`
EOF
echo x >> "$REPO/a.txt"
settle; S0="$(snap)"
run "$REPO" --task-path "$TASKFILE" --source-persona Architect --run-id run-1
rc_is "--source-persona Architect" 4
eq "persona refusal: snapshot identical" "$(snap)" "$S0"
state_persona Architect
run "$REPO" --task-path "$TASKFILE" --source-persona Executioner
rc_is "live session persona Architect, caller claims Executioner" 4
eq "persona refusal (live): snapshot identical" "$(snap)" "$S0"
rm -f "$V/.session_state.json"
run "$REPO" --task-path "$TASKFILE" --source-persona Executioner
rc_is "no session state file" 4
eq "missing state file: snapshot identical" "$(snap)" "$S0"
state_persona Executioner

run "$REPO" --source-persona Executioner
rc_is "missing --task-path" 3
run "$REPO" --task-path "$TASKFILE" --source-persona Executioner --bogus
rc_is "unknown arg" 3
run "$REPO" --task-path "$V/02_Tasks/Proj/Nope.md" --source-persona Executioner
rc_is "task file missing" 1
mkdir -p "$TMP/nogit"
run "$TMP/nogit" --task-path "$TASKFILE" --source-persona Executioner
rc_is "cwd outside any git work tree" 1
mkdir -p "$TMP/unborn" && "$REALGIT" init -q -b main "$TMP/unborn"
run "$TMP/unborn" --task-path "$TASKFILE" --source-persona Executioner
rc_is "unborn HEAD" 3
eq "unborn repo untouched" "$(ls -A "$TMP/unborn")" ".git"

section "(d) Interactive refusals are equally non-destructive"
mk_repo main
mk_task Int_Staged <<'EOF'
- [EDIT] `a.txt`
EOF
echo x >> "$REPO/a.txt"; echo x >> "$REPO/d.txt"; g add d.txt
settle; S0="$(snap)"
irun Int_Staged
rc_is "interactive, out-of-list path pre-staged" 3
eq "snapshot identical" "$(snap)" "$S0"

mk_repo main
mk_task Int_Detached <<'EOF'
- [EDIT] `a.txt`
EOF
g checkout -q --detach; echo x >> "$REPO/a.txt"
settle; S0="$(snap)"
irun Int_Detached
rc_is "interactive, detached HEAD" 3
eq "snapshot identical" "$(snap)" "$S0"

# ===========================================================================
section "(d) Orchestrator: untracked out-of-list files do NOT block"
# ===========================================================================
mk_repo main
mk_task Orch_Untracked <<'EOF'
- [EDIT] `a.txt`
- [NEW] `fresh.txt`
EOF
echo x >> "$REPO/a.txt"; echo f > "$REPO/fresh.txt"; echo j > "$REPO/junk.txt"; mkdir -p "$REPO/__pycache__"; echo p > "$REPO/__pycache__/m.pyc"
irun Orch_Untracked --run-id run-9
rc_is "only untracked out-of-list" 0
eq "committed exactly the listed files" "$(committed)" "$(sorted a.txt fresh.txt)"
eq "junk untracked still present" "$(g status --porcelain=v1 junk.txt)" "?? junk.txt"

# ===========================================================================
section "(DoD 2) Commit failure (E2) leaves everything retryable; task file untouched"
# ===========================================================================
mk_repo main
mk_task Hook_Fail <<'EOF'
- [EDIT] `a.txt`
- [NEW] `b.txt`
EOF
echo x >> "$REPO/a.txt"; echo b > "$REPO/b.txt"
printf '#!/bin/sh\necho "hook says no" >&2\nexit 1\n' > "$REPO/.git/hooks/pre-commit"; chmod +x "$REPO/.git/hooks/pre-commit"
MAIN0="$(head_ref main)"; TASK0="$(shasum -a 1 < "$TASKFILE")"; VAULT0="$(vault_state)"
irun Hook_Fail
rc_is "failing pre-commit hook" 2
has "stderr is an E2 message" "$ERR" "E2:"
eq "E2 on a single stderr line" "$(errlines)" "1"
eq "stdout empty on failure" "$OUT" ""
eq "main ref unchanged" "$(head_ref main)" "$MAIN0"
eq "task file untouched" "$(shasum -a 1 < "$TASKFILE")" "$TASK0"
eq "vault untouched" "$(vault_state)" "$VAULT0"
eq "listed paths remain staged for retry" "$(g diff --cached --name-only | LC_ALL=C sort)" "$(sorted a.txt b.txt)"
eq "task status still in_progress" "$(grep -c '^status: in_progress$' "$TASKFILE")" "1"
rm "$REPO/.git/hooks/pre-commit"
BR1="$(cur_branch)"
irun Hook_Fail
rc_is "retry after the hook is fixed" 0
eq "retry commits on the branch the failed run left" "$(cur_branch)" "$BR1"
eq "retry did not create a second branch" "$(g branch --list 'task/*' | wc -l | tr -d ' ')" "1"
eq "retry commits both files" "$(committed)" "$(sorted a.txt b.txt)"
eq "main still unchanged after retry" "$(head_ref main)" "$MAIN0"

mk_repo main
mk_task Hook_Fail_Orch <<'EOF'
- [EDIT] `a.txt`
EOF
echo x >> "$REPO/a.txt"
printf '#!/bin/sh\nexit 1\n' > "$REPO/.git/hooks/pre-commit"; chmod +x "$REPO/.git/hooks/pre-commit"
irun Hook_Fail_Orch --run-id run-7
rc_is "failing hook under the Orchestrator" 2

section "(telemetry) a refusal emits an error record"
T0="$(cat "$V"/04_Logs/Telemetry/*.jsonl | grep -c '"error"')"
mk_repo main
mk_task Tele_Err <<'EOF'
Nothing marked
EOF
irun Tele_Err
T1="$(cat "$V"/04_Logs/Telemetry/*.jsonl | grep -c '"error"')"
eq "error telemetry record appended" "$((T1 - T0))" "1"

# ===========================================================================
section "(c) bash 3.2 compatibility"
# ===========================================================================
BV="$(/bin/bash -c 'echo ${BASH_VERSINFO[0]}')"
eq "/bin/bash is bash 3.x (test is meaningful)" "$BV" "3"
eq "bash shim used by sub-scripts resolves to /bin/bash" "$(env PATH="$SHIM:$PATH" bash -c 'echo ${BASH_VERSINFO[0]}')" "3"
for f in commit_task.sh persona_check.sh emit_telemetry.sh; do
  RC=0; /bin/bash -n "$S/$f" 2>"$TMP/syn" || RC=$?
  eq "/bin/bash -n $f" "$RC" "0"
done
BASH4='declare -A|local -A|typeset -A|mapfile|readarray|\$\{[A-Za-z_]+(,,|\^\^|,|\^)\}|\|&|&>>|coproc|\$\{[A-Za-z_]+@[UuLlQEPAa]\}|;;&|;&|\[\[ -v |printf -v|wait -n|\$EPOCHSECONDS|\$EPOCHREALTIME|\$SRANDOM|\$BASH_ARGV0'
HITS="$(grep -nE "$BASH4" "$S/commit_task.sh" | grep -vE '^[0-9]+:[[:space:]]*#' || true)"
eq "no bash-4+ constructs in commit_task.sh" "$HITS" ""
case "$(head -n 1 "$S/commit_task.sh")" in '#!/usr/bin/env bash'|'#!/bin/bash') pass "shebang is portable" ;; *) fail "shebang" "$(head -n 1 "$S/commit_task.sh")" ;; esac

# ===========================================================================
section "(DoD 2, 5) Kit command files"
# ===========================================================================
if [ ! -d "$KIT/project-template" ]; then
echo "  SKIP - kit not found at '$KIT' (set KIT=<path>); kit command-file assertions skipped"
else
CMD="$KIT/project-template/.claude/commands"
CLOSE="$CMD/close_task.md"; EXEC="$CMD/execute_task.md"; TICK="$CMD/orchestrator_tick.md"
for f in "$CLOSE" "$EXEC" "$TICK"; do [ -f "$f" ] && pass "exists: $f" || fail "missing: $f"; done

# fenced_line <file> <script>  -> first line number of a fenced-code invocation
fenced_line() {
  awk -v pat="$2" '
    /^[[:space:]]*```/ { fence = !fence; next }
    fence && index($0, pat) { print NR; exit }
  ' "$1"
}
heading_line() { grep -nE "^## Step $2( |$)" "$1" | head -n 1 | cut -d: -f1; }

CT="$(fenced_line "$CLOSE" 'commit_task.sh')"
PS="$(fenced_line "$CLOSE" 'populate_summary.sh')"
SS="$(fenced_line "$CLOSE" 'set_task_status.sh')"
AR="$(fenced_line "$CLOSE" 'archive_file.sh')"
GUARD="$(grep -nE "status:\[\[:space:\]\]\*in_progress" "$CLOSE" | head -n 1 | cut -d: -f1)"
[ -n "$CT" ] && [ -n "$PS" ] && [ -n "$SS" ] && pass "executable (fenced) invocations located: commit=$CT populate=$PS status=$SS" || fail "locate fenced invocations" "commit=$CT populate=$PS status=$SS"
[ -n "$CT" ] && [ "$CT" -lt "$PS" ] && pass "DoD2: fenced commit_task call precedes populate_summary" || fail "DoD2 commit before populate" "$CT vs $PS"
[ -n "$CT" ] && [ "$CT" -lt "$SS" ] && pass "DoD2: fenced commit_task call precedes set_task_status (status flip)" || fail "DoD2 commit before status flip" "$CT vs $SS"
[ -n "$CT" ] && [ "$CT" -lt "$AR" ] && pass "commit_task call precedes archive" || fail "commit before archive" "$CT vs $AR"
[ -n "$GUARD" ] && [ "$GUARD" -lt "$CT" ] && pass "status guard runs before the commit" || fail "status guard before commit" "$GUARD vs $CT"
H4="$(heading_line "$CLOSE" 4)"; H45="$(heading_line "$CLOSE" 4.5)"; H5="$(heading_line "$CLOSE" 5)"; H55="$(heading_line "$CLOSE" 5.5)"
[ -n "$H45" ] && [ "$H4" -lt "$H45" ] && [ "$H45" -lt "$H5" ] && [ "$H5" -lt "$H55" ] && pass "headings ordered Step 4 < 4.5 < 5 < 5.5" || fail "step heading order" "4=$H4 4.5=$H45 5=$H5 5.5=$H55"
[ "$CT" -gt "$H45" ] && [ "$CT" -lt "$H5" ] && pass "commit_task call lives inside Step 4.5" || fail "commit_task call inside Step 4.5" "$H45 < $CT < $H5"

S45="$(sed -n "${H45},$((H5 - 1))p" "$CLOSE")"
has "Step 4.5 Orchestrator branch queues close_gate" "$S45" "--state close_gate"
has "Step 4.5 queues with --source orchestrator" "$S45" "--source orchestrator"
has "Step 4.5 queues with the run id" "$S45" '--run-id "$ORCH_RUN_ID"'
has "Step 4.5 tells the Orchestrator path to stop (no Steps 5-10)" "$S45" "do not run Steps 5-10"
has "Step 4.5 keeps the task in_progress" "$S45" "in_progress"
has "Step 4.5 interactive failure HALTs" "$S45" "HALT"
has "Step 4.5 passes --run-id only when ORCH_RUN_ID set" "$S45" '${ORCH_RUN_ID:+--run-id "$ORCH_RUN_ID"}'
has "Step 4.5 passes the Executioner persona" "$S45" "--source-persona Executioner"
has "Step 4.5 mentions the no-op case" "$S45" "COMMIT_SHA=none"
hasnt "Step 4.5 does not pass an interactive run through task_owner stamp" "$S45" "task_owner"
case "$(grep -v '^[[:space:]]*#' "$CLOSE" | grep -c 'task_owner.sh')" in 0) pass "close_task.md never reads the on-disk run stamp" ;; *) fail "close_task.md reads task_owner stamp" ;; esac
RUNID_PARSE="$(grep -n -- '`--run-id <id>`' "$CLOSE" | head -n 1)"
[ -n "$RUNID_PARSE" ] && pass "Invocation section parses --run-id into ORCH_RUN_ID" || fail "Invocation parses --run-id"
has "Invocation names ORCH_RUN_ID" "$(sed -n 1,60p "$CLOSE")" 'ORCH_RUN_ID'
hasnt "close_task.md has no stale 'user-triggered only'" "$(cat "$CLOSE")" "user-triggered only"
hasnt "no push/merge instruction in close_task.md executable blocks" "$(awk '/^[[:space:]]*```/{f=!f;next} f' "$CLOSE" | grep -E 'git (push|merge)' || true)" "git"
has "Reminders: never push or merge" "$(cat "$CLOSE")" "Never push, never merge"
has "Step 10 confirmation reports the commit" "$(sed -n '/^## Step 10/,$p' "$CLOSE")" "Committed"
RC=0; ( cd "$KIT" && /bin/bash tests/test_no_inline_mutations.sh >/dev/null 2>&1 ) || RC=$?
eq "kit regression: test_no_inline_mutations.sh" "$RC" "0"

S14="$(sed -n '/^## Step 14/,/^## Step 15/p' "$EXEC")"
INTER="$(printf '%s\n' "$S14" | sed -n '/Interactive caller/,/Autonomous caller/p')"
AUTO="$(printf '%s\n' "$S14" | sed -n '/Autonomous caller/,$p')"
[ -n "$INTER" ] && [ -n "$AUTO" ] && pass "Step 14 has interactive and autonomous branches" || fail "Step 14 branches located"
has "DoD5: Step 14 Autonomous branch invokes /close_task with --run-id" "$AUTO" '/close_task [[<Task_Name>]] --run-id $ORCH_RUN_ID'
hasnt "Step 14 Interactive branch does NOT pass --run-id" "$INTER" "--run-id"
has "Step 14 Interactive branch still tells the human to run /close_task" "$INTER" '/close_task [[<Task_Name>]]'
has "Step 14 documents the queued close_gate outcome on commit refusal" "$AUTO" "queued close_gate"
EXEC_OUTSIDE14="$(sed '/^## Step 14/,/^## Step 15/d' "$EXEC")"
hasnt "no other place auto-invokes /close_task --run-id" "$EXEC_OUTSIDE14" "/close_task [[<Task_Name>]] --run-id"

S4T="$(sed -n '/^## Step 4 /,/^## Step 5 /p' "$TICK")"
has "DoD5: orchestrator_tick Step 4 mentions commit_task" "$S4T" "commit_task"
has "DoD5: tick says the commit lands on orch/<run_id>" "$S4T" 'orch/<run_id>'
has "DoD5: tick says it happens at the close gate before the status flip" "$S4T" "before the status flip"
has "DoD5: tick says a refusal escalates close_gate" "$S4T" "close_gate"
has "tick digest (Step 5) lists the queued close_gate outcome" "$(sed -n '/^## Step 5 /,/^## Step 6 /p' "$TICK")" "queued close_gate"
hasnt "tick does not duplicate the call (no second invocation of the atom)" "$(awk '/^[[:space:]]*```/{f=!f;next} f' "$TICK" | grep 'commit_task.sh' || true)" "commit_task.sh"

has "spec-writer documents the machine-read Files touched grammar" "$(cat "$KIT/global/agents/spec-writer.md")" "commit_task"
fi

has "queue_attention still allows close_gate" "$(grep -n 'ALLOWED_STATES' "$SCRIPTS/queue_attention.sh" | head -n 3)" "close_gate"

# ===========================================================================
echo
echo "passes=$PASSES fails=$FAILS"
if [ "$FAILS" -eq 0 ]; then echo "ACCEPTANCE: PASS"; exit 0; else echo "ACCEPTANCE: FAIL"; exit 1; fi

#!/usr/bin/env bash
# test_integrate_task.sh
#
# Gateway tests for .scripts/integrate_task.sh (PRD Staging_Integration_PRD crit 11-34,
# plus crit 42 at atom level). Self-contained and network-free: temp repos, local bare
# origins and a fake gh on an isolated PATH. Never reaches GitHub. No skip env: it is
# fast and needs only git >= 2.38 and jq. Green means exit 0, no FAIL: line, last line SMOKE: OK.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRIPTS="$REPO_ROOT/.scripts"

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR TITAN_SESSION_ID TELEMETRY_DIR \
      FAKE_GH_FAIL FAKE_GH_PR FAKE_GH_AUTH_RC FAKE_GIT_FAIL GH_REPO
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

TMP="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }
eq()   { [[ "$1" == "$2" ]] || fail "$3 (expected '$2', got '$1')"; }
pass() { echo "ok: $1"; }

REAL_GIT="$(command -v git)"
REAL_JQ="$(command -v jq || true)"
[[ -n "$REAL_JQ" ]] || fail "jq is required"
GV="$("$REAL_GIT" version | awk '{ print $3 }')"
GMAJ="${GV%%.*}"; GREST="${GV#*.}"; GMIN="${GREST%%.*}"
if [[ "$GMAJ" -lt 2 || ( "$GMAJ" -eq 2 && "$GMIN" -lt 38 ) ]]; then fail "git >= 2.38 required (found $GV)"; fi

V="$TMP/vault"
S="$V/.scripts"
mkdir -p "$S" "$V/04_Logs/Telemetry" "$V/02_Tasks/Proj" "$TMP/bin" "$TMP/fake"
for f in integrate_task.sh commit_task.sh lib_section.sh persona_check.sh emit_telemetry.sh panel_guard.sh; do
  cp "$SCRIPTS/$f" "$S/"
done
write_persona() {
  printf '{\n  "persona": "%s",\n  "session_id": "smoke",\n  "started_at": "2026-06-14T00:00:00Z",\n  "agent_surface": "test"\n}\n' "$1" > "$V/.session_state.json"
}
write_persona Executioner

cat > "$TMP/bin/git" <<EOF
#!/bin/bash
if [ -n "\${FAKE_GIT_FAIL:-}" ] && [ "\${1:-}" = "\$FAKE_GIT_FAIL" ]; then
  echo "fatal: simulated \$1 failure" >&2
  exit 128
fi
exec "$REAL_GIT" "\$@"
EOF
chmod +x "$TMP/bin/git"
ln -s "$REAL_JQ" "$TMP/bin/jq"

cat > "$TMP/fake/gh" <<'EOF'
#!/bin/bash
echo "$*" >> "$GH_LOG"
prev=""
for a in "$@"; do
  if [ "$prev" = "--body-file" ]; then cp "$a" "$GH_LOG.body"; fi
  prev="$a"
done
if [ "${1:-}" = auth ]; then exit "${FAKE_GH_AUTH_RC:-0}"; fi
if [ "${1:-}" = pr ]; then
  if [ "${FAKE_GH_FAIL:-}" = "${2:-}" ]; then echo "simulated gh pr $2 failure" >&2; exit 1; fi
  if [ "${2:-}" = list ] && [ -n "${FAKE_GH_PR:-}" ]; then echo "$FAKE_GH_PR"; fi
fi
exit 0
EOF
chmod +x "$TMP/fake/gh"

BASE_PATH="/usr/bin:/bin:/usr/sbin:/sbin"
NOGH_PATH="$TMP/bin:$BASE_PATH"
export PATH="$TMP/fake:$NOGH_PATH"
export GH_LOG="$TMP/gh.log"
: > "$GH_LOG"
eq "$(command -v gh)" "$TMP/fake/gh" "gh resolves to the fake"
if PATH="$NOGH_PATH" command -v gh >/dev/null 2>&1; then
  fail "a real gh is reachable without the fake dir; the gh-missing case is impossible on this machine"
fi

# --- harness ---------------------------------------------------------------
RC=0
run_it() { # run_it <repo> <args...> ; sets RC, $TMP/out, $TMP/err
  local repo="$1"; shift
  : > "$GH_LOG"; rm -f "$GH_LOG.body"
  RC=0
  (cd "$repo" && /bin/bash "$S/integrate_task.sh" "$@") > "$TMP/out" 2> "$TMP/err" || RC=$?
  cat "$GH_LOG" >> "$TMP/gh_all.log"
}
TP() { printf '%s' "$V/02_Tasks/Proj/$1.md"; }
run_ok() { run_it "$1" --task-path "$(TP "$2")" --source-persona Executioner "${@:3}"; }
has()     { grep -qxF -- "$1" "$TMP/out" || fail "stdout lacks line '$1' ($(tr '\n' '|' < "$TMP/out"))"; }
err_has() { grep -qF -- "$1" "$TMP/err" || fail "stderr lacks '$1' ($(cat "$TMP/err"))"; }
log_has() { grep -qF -- "$1" "$GH_LOG" || fail "gh log lacks '$1' ($(cat "$GH_LOG"))"; }
one_err() { # one_err <rc> <label>
  eq "$RC" "$1" "$2: exit code"
  eq "$(wc -l < "$TMP/err" | tr -d ' ')" "1" "$2: exactly one stderr line"
  grep -q "^E$1:" "$TMP/err" || fail "$2: stderr not E$1: ($(cat "$TMP/err"))"
  [[ ! -s "$TMP/out" ]] || fail "$2: stdout must be empty on failure"
}
ok0() { eq "$RC" "0" "$1: exit code ($(cat "$TMP/err"))"; }

: > "$TMP/gh_all.log"
: > "$TMP/mains"

for t in Task_A Task_B Task_C Task_X; do
  f="a.txt"; [[ "$t" == "Task_B" ]] && f="b.txt"; [[ "$t" == "Task_X" ]] && f="new.txt"
  printf -- '---\nproject: [[Proj]]\nstatus: in_progress\n---\n\n# Task: %s\n\n## Spec: %s\n\n### Files touched\n- [EDIT] `%s`\n' "$t" "$t" "$f" > "$V/02_Tasks/Proj/$t.md"
done

ident() { git -C "$1" config user.name Test; git -C "$1" config user.email test@example.com; }

mk_origin_repo() { # <dir> <origin>
  local d="$1" o="$2"
  mkdir -p "$d"
  git init -q -b main "$d"; ident "$d"
  printf 'l1\nl2\nl3\n' > "$d/a.txt"; printf 'b0\n' > "$d/b.txt"
  git -C "$d" add -A; git -C "$d" commit -q -m init
  git init -q --bare -b main "$o"
  printf '#!/bin/sh\n[ -e reject ] && exit 1\nexit 0\n' > "$o/hooks/pre-receive"
  chmod +x "$o/hooks/pre-receive"
  git -C "$d" remote add origin "$o"
  git -C "$d" push -q -u origin main
  git -C "$d" remote set-head origin main >/dev/null
  git -C "$d" switch -q -c staging
  printf 's\n' > "$d/stg.txt"; git -C "$d" add -A; git -C "$d" commit -q -m "stg base"
  git -C "$d" push -q -u origin staging
  git -C "$d" switch -q main
  printf '%s %s\n' "$o" "$(git --git-dir="$o" rev-parse refs/heads/main)" >> "$TMP/mains"
}
setup() { # setup <name> -> D, O
  D="$TMP/$1/repo"; O="$TMP/$1/origin.git"; mkdir -p "$TMP/$1"
  mk_origin_repo "$D" "$O"
}
mk_task_branch() { # <repo> <branch> <file> <content> [2]
  local d="$1"
  git -C "$d" switch -q --no-track -c "$2" staging
  printf '%b' "$4" > "$d/$3"; git -C "$d" add -A; git -C "$d" commit -q -m "work 1"
  if [[ "${5:-1}" == "2" ]]; then printf 'more\n' >> "$d/$3"; git -C "$d" add -A; git -C "$d" commit -q -m "work 2"; fi
}
mk_clone() { # <origin> <dir>
  git clone -q "$1" "$2"; ident "$2"; git -C "$2" switch -q staging
}
clone_push() { # <origin> <dir> <file> <content> ; commits on staging and pushes
  mk_clone "$1" "$2"
  printf '%b' "$4" > "$2/$3"; git -C "$2" add -A; git -C "$2" commit -q -m "x change"
  git -C "$2" push -q origin staging
}
snap() { # <repo> <origin>
  git -C "$1" for-each-ref --format='%(refname) %(objectname)' refs/heads
  git -C "$1" rev-parse HEAD
  git -C "$1" symbolic-ref -q HEAD || echo detached
  git -C "$1" ls-files -s | cksum
  git -C "$1" status --porcelain
  git --git-dir="$2" for-each-ref
}
ostg() { git --git-dir="$O" rev-parse refs/heads/staging; }

# --- crit 11-13 ---------------------------------------------------------------
setup c11
mk_task_branch "$D" task/Task_A a.txt 'l1\nA1\nl3\n' 2
OLD="$(git -C "$D" rev-parse staging)"; TIP_A="$(git -C "$D" rev-parse task/Task_A)"
run_ok "$D" Task_A
ok0 "crit 11"
eq "$(git -C "$D" rev-list --count "$OLD..staging")" "1" "crit 11: one new commit"
eq "$(git -C "$D" rev-list --parents -n1 staging | wc -w | tr -d ' ')" "2" "crit 11: single parent"
eq "$(git -C "$D" rev-parse "staging^{tree}")" "$(git -C "$D" rev-parse "$TIP_A^{tree}")" "crit 11: staging tree = task tip tree"
[[ "$(git -C "$D" rev-parse staging)" != "$OLD" ]] || fail "crit 11: staging did not move"
eq "$(git -C "$D" rev-list --merges --count staging)" "0" "crit 11: no merge commits"
pass "crit 11"

eq "$(git -C "$D" log -1 --format=%s staging)" "task(Proj): Task_A" "crit 12: subject"
git -C "$D" log -1 --format=%B staging | grep -qxF "Closes [[Task_A]]" || fail "crit 12: Closes line"
TRL="$(git -C "$D" log -1 --format=%B staging | git interpret-trailers --parse)"
grep -qxF "Task-Branch: task/Task_A" <<< "$TRL" || fail "crit 12: Task-Branch trailer"
grep -qxF "Task-Commit: $TIP_A" <<< "$TRL" || fail "crit 12: Task-Commit trailer"
pass "crit 12"

NEW="$(git -C "$D" rev-parse staging)"
eq "$NEW" "$(ostg)" "crit 13: origin staging = local"
eq "$NEW" "$(git -C "$D" rev-parse refs/remotes/origin/staging)" "crit 13: tracking ref"
git -C "$D" rev-parse -q --verify refs/heads/task/Task_A >/dev/null 2>&1 && fail "crit 13: task branch not deleted"
eq "$(git -C "$D" symbolic-ref --short HEAD)" "staging" "crit 13: HEAD on staging"
has "INTEGRATE_STATE=integrated"; has "INTEGRATE_TASK_BRANCH=task/Task_A"
has "INTEGRATE_SHA=$(git -C "$D" rev-parse --short staging)"
eq "$(head -n 1 "$TMP/out" | cut -c1-14)" "INTEGRATE_SHA=" "crit 13: marker order (first)"
eq "$(sed -n 2p "$TMP/out")" "INTEGRATE_STATE=integrated" "crit 13: marker order (second)"
eq "$(sed -n 4p "$TMP/out")" "RELEASE_PR=created" "crit 13: marker order (fourth)"
pass "crit 13"

# --- crit 14 (revert) and crit 30 (release PR body, two tasks) ----------------
A_SHA="$NEW"
mk_task_branch "$D" task/Task_B b.txt 'b-new\n'
FAKE_GH_PR= run_ok "$D" Task_B
ok0 "crit 14 integrate B"
mk_clone "$O" "$TMP/c14clone"
git -C "$TMP/c14clone" revert --no-edit "$A_SHA" >/dev/null 2>&1 || fail "crit 14: revert of A needs no -m / conflicts"
eq "$(git -C "$TMP/c14clone" diff --name-only HEAD~1 HEAD)" "a.txt" "crit 14: revert touches only a.txt"
eq "$(cat "$TMP/c14clone/a.txt")" "$(printf 'l1\nl2\nl3')" "crit 14: a.txt back to pre-A"
eq "$(cat "$TMP/c14clone/b.txt")" "b-new" "crit 14: b.txt keeps B"
pass "crit 14"

log_has "pr list --state open --base main --head staging"
log_has "pr create --base main --head staging --title Release: staging -> main --body-file"
grep -qxF "Release PR kept current by integrate_task.sh. Each line is one task squash-committed onto staging; revert one task with \`git revert <sha>\` on staging." "$GH_LOG.body" || fail "crit 30: body header"
grep -qF -- "- task(Proj): Task_A (" "$GH_LOG.body" || fail "crit 30: body lists A"
grep -qF -- "- task(Proj): Task_B (" "$GH_LOG.body" || fail "crit 30: body lists B"
pass "crit 30"

# --- crit 31 ---------------------------------------------------------------------
setup c31
mk_task_branch "$D" task/Task_A a.txt 'l1\nA\nl3\n'
FAKE_GH_PR=7 run_ok "$D" Task_A
ok0 "crit 31"; has "RELEASE_PR=updated"
log_has "pr edit 7 --body-file"
grep -q "pr create" "$GH_LOG" && fail "crit 31: pr create must not run"
grep -qF -- "- task(Proj): Task_A (" "$GH_LOG.body" || fail "crit 31: body lists task"
pass "crit 31"

# --- crit 15 ---------------------------------------------------------------------
setup c15
clone_push "$O" "$TMP/c15clone" x.txt 'x\n'
X_SHA="$(git -C "$TMP/c15clone" rev-parse HEAD)"
mk_task_branch "$D" task/Task_A a.txt 'l1\nA\nl3\n'
run_ok "$D" Task_A
ok0 "crit 15"
eq "$(git -C "$D" rev-parse staging~1)" "$X_SHA" "crit 15: parent is X"
eq "$(git -C "$D" rev-list --merges --count staging)" "0" "crit 15: no merges"
eq "$(git -C "$D" rev-parse staging)" "$(ostg)" "crit 15: local = origin"
pass "crit 15"

# --- crit 16 ---------------------------------------------------------------------
setup c16
mk_task_branch "$D" task/Task_A a.txt 'l1\nA\nl3\n'
git -C "$D" switch -q staging; printf 'l\n' > "$D/l.txt"; git -C "$D" add -A; git -C "$D" commit -q -m "local only"
git -C "$D" switch -q task/Task_A
clone_push "$O" "$TMP/c16clone" x.txt 'x\n'
B4="$(snap "$D" "$O")"
run_ok "$D" Task_A
one_err 3 "crit 16 diverged"; err_has "diverged"
eq "$(snap "$D" "$O")" "$B4" "crit 16 diverged: snap"
setup c16b
mk_task_branch "$D" task/Task_A a.txt 'l1\nA\nl3\n'
git -C "$D" switch -q staging; printf 'l\n' > "$D/l.txt"; git -C "$D" add -A; git -C "$D" commit -q -m "local only"
git -C "$D" switch -q task/Task_A
B4="$(snap "$D" "$O")"
run_ok "$D" Task_A
one_err 3 "crit 16 ahead"; err_has "ahead"
eq "$(snap "$D" "$O")" "$B4" "crit 16 ahead: snap"
pass "crit 16"

# --- crit 17 ---------------------------------------------------------------------
setup c17
mk_task_branch "$D" task/Task_A a.txt 'T1\nl2\nl3\n'
clone_push "$O" "$TMP/c17clone" a.txt 'C1\nl2\nl3\n'
TIP_BEFORE="$(git -C "$D" rev-parse task/Task_A)"
B4="$(snap "$D" "$O")"
run_ok "$D" Task_A
one_err 2 "crit 17"; err_has "a.txt"
eq "$(snap "$D" "$O")" "$B4" "crit 17: snap"
eq "$(git -C "$D" rev-parse task/Task_A)" "$TIP_BEFORE" "crit 17: task tip unchanged"
pass "crit 17"

# --- crit 18 + preconditions -----------------------------------------------------
setup c18a
git -C "$D" switch -q -c task/Task_A main
printf 'l1\nA\nl3\n' > "$D/a.txt"; git -C "$D" add -A; git -C "$D" commit -q -m w
git -C "$D" branch -D staging >/dev/null; git -C "$D" update-ref -d refs/remotes/origin/staging
B4="$(snap "$D" "$O")"
run_ok "$D" Task_A
one_err 3 "crit 18 no staging"; err_has "no staging branch"
eq "$(snap "$D" "$O")" "$B4" "crit 18 no staging: snap"

setup c18b
B4="$(snap "$D" "$O")"
run_ok "$D" Task_A
one_err 3 "crit 18 missing branch"; err_has "no task branch for Task_A"
eq "$(snap "$D" "$O")" "$B4" "crit 18 missing branch: snap"
git -C "$D" remote set-url origin "$TMP/nope.git"
B4="$(snap "$D" "$O")"
run_ok "$D" Task_A --allow-missing-branch
ok0 "crit 18 allow-missing"
has "INTEGRATE_SHA=none"; has "INTEGRATE_STATE=skipped-no-branch"; has "INTEGRATE_TASK_BRANCH=none"
has "RELEASE_PR=skipped"; has "WARN: no task branch for Task_A; nothing to integrate"
eq "$(snap "$D" "$O")" "$B4" "crit 18 allow-missing: snap"

setup c18c
mk_task_branch "$D" task/Task_A a.txt 'l1\nA\nl3\n'
git -C "$D" remote remove origin
B4="$(snap "$D" "$O")"
run_ok "$D" Task_A
one_err 3 "crit 18 no origin"; err_has "no origin remote"
eq "$(snap "$D" "$O")" "$B4" "crit 18 no origin: snap"

setup c18d
mk_task_branch "$D" task/Task_A a.txt 'l1\nA\nl3\n'
git --git-dir="$O" update-ref -d refs/heads/staging
B4="$(snap "$D" "$O")"
run_ok "$D" Task_A
one_err 3 "crit 18 origin has no staging"; err_has "origin has no staging"
eq "$(snap "$D" "$O")" "$B4" "crit 18 origin no staging: snap"
pass "crit 18"

setup pre
mk_task_branch "$D" task/Task_A a.txt 'l1\nA\nl3\n'
git -C "$D" switch -q --detach
B4="$(snap "$D" "$O")"; run_ok "$D" Task_A
one_err 3 "detached HEAD"; err_has "detached"; eq "$(snap "$D" "$O")" "$B4" "detached: snap"
git -C "$D" switch -q task/Task_A
git -C "$D" rev-parse HEAD > "$D/.git/MERGE_HEAD"
B4="$(snap "$D" "$O")"; run_ok "$D" Task_A
one_err 3 "MERGE_HEAD"; err_has "MERGE_HEAD"; eq "$(snap "$D" "$O")" "$B4" "MERGE_HEAD: snap"
rm -f "$D/.git/MERGE_HEAD"
git -C "$D" worktree add -q "$TMP/wt" staging
B4="$(snap "$D" "$O")"; run_ok "$D" Task_A
one_err 3 "staging worktree"; err_has "$TMP/wt"; eq "$(snap "$D" "$O")" "$B4" "worktree: snap"
git -C "$D" worktree remove --force "$TMP/wt"
B4="$(snap "$D" "$O")"
run_it "$D" --task-path "$(TP Task_A)" --source-persona Executioner --bogus
one_err 3 "unknown arg"
run_it "$D" --task-path "$(TP Task_A)"
one_err 3 "missing persona"
run_it "$D" --task-path
one_err 3 "value flag without value"
run_it "$D" --task-path "$V/02_Tasks/Proj/Nope.md" --source-persona Executioner
one_err 1 "missing task file"
mkdir -p "$TMP/nonrepo"
run_ok "$TMP/nonrepo" Task_A
one_err 1 "non-repo cwd"
eq "$(snap "$D" "$O")" "$B4" "preconditions: snap"
pass "preconditions"

# --- crit 19 ---------------------------------------------------------------------
B4="$(snap "$D" "$O")"
run_it "$D" --task-path "$(TP Task_A)" --source-persona Architect
one_err 4 "crit 19 arg"
write_persona Architect
run_ok "$D" Task_A
one_err 4 "crit 19 session"; err_has "mismatch"
write_persona Executioner
eq "$(snap "$D" "$O")" "$B4" "crit 19: snap"
pass "crit 19"

# --- crit 20-22 / DoD 2: tracked-clean check before any network call ---------------
setup c20
mk_task_branch "$D" task/Task_A a.txt 'l1\nA\nl3\n'
clone_push "$O" "$TMP/c20clone" x.txt 'x\n'
RS_BEFORE="$(git -C "$D" rev-parse refs/remotes/origin/staging)"
dirty_check() { # <label> [env-assign handled by caller]
  one_err 3 "$1"
  eq "$(git -C "$D" rev-parse refs/remotes/origin/staging)" "$RS_BEFORE" "$1: origin/staging ref moved (a fetch ran)"
  eq "$(snap "$D" "$O")" "$B4" "$1: snap"
}
printf 'dirty\n' >> "$D/a.txt"
B4="$(snap "$D" "$O")"
run_ok "$D" Task_A; dirty_check "modified tracked"; err_has "a.txt"
FAKE_GIT_FAIL=fetch run_ok "$D" Task_A; dirty_check "dirty + fetch fail"
FAKE_GIT_FAIL=ls-remote run_ok "$D" Task_A; dirty_check "dirty + ls-remote fail"
touch "$O/reject"; run_ok "$D" Task_A; dirty_check "dirty + reject"; rm -f "$O/reject"
git -C "$D" checkout -q -- a.txt
printf 'n\n' > "$D/new.txt"; git -C "$D" add new.txt
B4="$(snap "$D" "$O")"
run_ok "$D" Task_A; dirty_check "staged new file"; err_has "new.txt"
git -C "$D" rm -qf --cached new.txt; rm -f "$D/new.txt"
printf 'codemap\n' > "$D/CODEMAP.md"; printf 'junk\n' > "$D/junk.txt"
CK1="$(cksum "$D/CODEMAP.md" "$D/junk.txt")"
run_ok "$D" Task_A
ok0 "untracked files do not block"
eq "$(cksum "$D/CODEMAP.md" "$D/junk.txt")" "$CK1" "untracked files byte-identical"
pass "crit 20-22"

# --- crit 23 / 24 / 26 -------------------------------------------------------------
setup c23
mk_task_branch "$D" task/Task_A a.txt 'l1\nA\nl3\n'
TIP_A="$(git -C "$D" rev-parse task/Task_A)"
touch "$O/reject"
B4="$(snap "$D" "$O")"
run_ok "$D" Task_A
one_err 5 "crit 23 push rejected"
eq "$(snap "$D" "$O")" "$B4" "crit 23: snap"
eq "$(git -C "$D" rev-parse refs/remotes/origin/staging)" "$(ostg)" "crit 23: tracking ref not advanced"
[[ ! -s "$GH_LOG" ]] || fail "crit 23: gh must not run"
pass "crit 23"
rm -f "$O/reject"

git -C "$D" remote set-url origin "$TMP/nope.git"
B4="$(snap "$D" "$O")"
run_ok "$D" Task_A
one_err 5 "crit 24a broken url"; eq "$(snap "$D" "$O")" "$B4" "crit 24a: snap"
git -C "$D" remote set-url origin "$O"
FAKE_GIT_FAIL=fetch run_ok "$D" Task_A
one_err 5 "crit 24b fetch"; err_has "fetch"; eq "$(snap "$D" "$O")" "$B4" "crit 24b: snap"
FAKE_GIT_FAIL=ls-remote run_ok "$D" Task_A
one_err 5 "crit 24c ls-remote"; eq "$(snap "$D" "$O")" "$B4" "crit 24c: snap"
pass "crit 24"

run_ok "$D" Task_A
ok0 "crit 26 re-run"
eq "$(git -C "$D" log --first-parent --fixed-strings --grep="Task-Commit: $TIP_A" --format=%H staging | wc -l | tr -d ' ')" "1" "crit 26: exactly one squash"
eq "$(git -C "$D" rev-parse staging)" "$(ostg)" "crit 26: local = origin"
git -C "$D" rev-parse -q --verify refs/heads/task/Task_A >/dev/null 2>&1 && fail "crit 26: branch not deleted"
pass "crit 26"

# --- crit 25 / 33 / DoD 3 ------------------------------------------------------------
setup c25
mk_task_branch "$D" task/Task_A a.txt 'l1\nA\nl3\n'
TIP_A="$(git -C "$D" rev-parse task/Task_A)"
PRE="$(git -C "$D" rev-parse staging)"
FAKE_GH_FAIL=create run_ok "$D" Task_A
ok0 "crit 25a"
has "RELEASE_PR=failed"; has "INTEGRATE_STATE=integrated"
grep -q '^WARN: release PR not updated (gh pr create failed' "$TMP/out" || fail "crit 25a: WARN line"
git -C "$D" rev-parse -q --verify refs/heads/task/Task_A >/dev/null 2>&1 && fail "crit 25a: branch kept"
eq "$(git -C "$D" rev-parse staging)" "$(ostg)" "crit 25a: local = origin"
POST="$(ostg)"; CNT="$(git --git-dir="$O" rev-list --count staging)"
pass "crit 25a"

git -C "$D" branch task/Task_A "$TIP_A"; git -C "$D" switch -q main
git -C "$D" update-ref refs/heads/staging "$PRE"
touch "$O/reject"
run_ok "$D" Task_A
ok0 "crit 25b"
has "INTEGRATE_STATE=already-integrated"
has "INTEGRATE_SHA=$(git -C "$D" rev-parse --short "$POST")"
eq "$(ostg)" "$POST" "crit 25b: origin unchanged"
eq "$(git --git-dir="$O" rev-list --count staging)" "$CNT" "crit 25b: no new commit"
eq "$(git -C "$D" rev-parse staging)" "$POST" "crit 25b: local = origin"
eq "$(git -C "$D" symbolic-ref --short HEAD)" "staging" "crit 25b: HEAD on staging"
git -C "$D" rev-parse -q --verify refs/heads/task/Task_A >/dev/null 2>&1 && fail "crit 25b: branch kept"
log_has "pr create"
rm -f "$O/reject"
pass "crit 25b"

git -C "$D" switch -q --no-track -c task/Task_A staging
printf 'l1\nA2\nl3\n' > "$D/a.txt"; git -C "$D" add -A; git -C "$D" commit -q -m "again"
run_ok "$D" Task_A
ok0 "crit 25c"; has "INTEGRATE_STATE=integrated"
eq "$(git --git-dir="$O" rev-list --count staging)" "$((CNT + 1))" "crit 25c: reused slug integrates as a new commit"
pass "crit 25c"

setup c25b2
mk_task_branch "$D" task/Task_A a.txt 'l1\nA\nl3\n'
TIP_A="$(git -C "$D" rev-parse task/Task_A)"; S0="$(git -C "$D" rev-parse staging)"
run_ok "$D" Task_A; ok0 "25b2 integrate A"
A_NEW="$(git -C "$D" rev-parse staging)"
mk_task_branch "$D" task/Task_B b.txt 'b-new\n'
run_ok "$D" Task_B; ok0 "25b2 integrate B"
B_NEW="$(git -C "$D" rev-parse staging)"
eq "$(git -C "$D" rev-parse staging~1)" "$A_NEW" "25b2: A' is B'~1"
git -C "$D" log -1 --format=%B staging | grep -qF "Task-Commit: $TIP_A" && fail "25b2: B message must not carry A trailer"
CNT="$(git --git-dir="$O" rev-list --count staging)"
git -C "$D" branch task/Task_A "$TIP_A"; git -C "$D" switch -q main
git -C "$D" update-ref refs/heads/staging "$S0"
touch "$O/reject"
run_ok "$D" Task_A
ok0 "crit 25b2"
has "INTEGRATE_STATE=already-integrated"; has "INTEGRATE_SHA=$(git -C "$D" rev-parse --short "$B_NEW")"
eq "$(ostg)" "$B_NEW" "25b2: origin unchanged"
eq "$(git --git-dir="$O" rev-list --count staging)" "$CNT" "25b2: no new commit"
eq "$(git -C "$D" rev-parse staging)" "$B_NEW" "25b2: local = origin"
eq "$(git -C "$D" symbolic-ref --short HEAD)" "staging" "25b2: HEAD on staging"
git -C "$D" rev-parse -q --verify refs/heads/task/Task_A >/dev/null 2>&1 && fail "25b2: branch kept"
rm -f "$O/reject"
pass "crit 25 / 33"

# --- D3 landing failure -> idempotent recovery -------------------------------------
setup d3
mk_task_branch "$D" task/Task_X new.txt 'task\n'
git -C "$D" switch -q main
printf 'local\n' > "$D/new.txt"
CK1="$(cksum "$D/new.txt")"
run_ok "$D" Task_X
one_err 2 "D3 landing failure"; err_has "pushed"; err_has "re-run integrate_task"
eq "$(git --git-dir="$O" log -1 --format=%s staging)" "task(Proj): Task_X" "D3: origin has the squash"
eq "$(cksum "$D/new.txt")" "$CK1" "D3: untracked file byte-identical"
rm -f "$D/new.txt"
run_ok "$D" Task_X
ok0 "D3 recovery"; has "INTEGRATE_STATE=already-integrated"
git -C "$D" rev-parse -q --verify refs/heads/task/Task_X >/dev/null 2>&1 && fail "D3: branch kept"
pass "D3"

# --- crit 29 / 42 ------------------------------------------------------------------
setup c29a
git -C "$D" switch -q --no-track -c orch/r1/Task_A staging
printf 'l1\nA\nl3\n' > "$D/a.txt"; git -C "$D" add -A; git -C "$D" commit -q -m w
run_ok "$D" Task_A
ok0 "crit 29 orch only"; has "INTEGRATE_TASK_BRANCH=orch/r1/Task_A"

setup c29b
mk_task_branch "$D" task/Task_A a.txt 'l1\nA\nl3\n'
git -C "$D" branch orch/r2/Task_A task/Task_A
B4="$(snap "$D" "$O")"
run_ok "$D" Task_A
one_err 3 "crit 29 ambiguous"; err_has "ambiguous"; err_has "task/Task_A"; err_has "orch/r2/Task_A"
eq "$(snap "$D" "$O")" "$B4" "crit 29 ambiguous: snap"

setup c29c
git -C "$D" branch orch/a/b/Task_A staging
run_ok "$D" Task_A
one_err 3 "crit 29 nested"; err_has "no task branch"

setup c29d
printf 'l1\nC\nl3\n' > "$D/a.txt"
(cd "$D" && /bin/bash "$S/commit_task.sh" --task-path "$(TP Task_C)" --source-persona Executioner --run-id r1) > "$TMP/ct.out" 2>&1 \
  || fail "crit 29: commit_task r1 failed ($(cat "$TMP/ct.out"))"
git -C "$D" rev-parse -q --verify refs/heads/orch/r1/Task_C >/dev/null || fail "crit 29: orch/r1/Task_C missing"
touch "$O/reject"
run_ok "$D" Task_C
one_err 5 "crit 29 transient"
eq "$(/bin/bash "$S/panel_guard.sh" --task Task_C --run-id r1 --state-file "$TMP/ir" >/dev/null; echo $?)" "0" "crit 42: first convene"
(cd "$D" && /bin/bash "$S/commit_task.sh" --task-path "$(TP Task_C)" --source-persona Executioner --run-id r2) > "$TMP/ct.out" 2>&1 \
  || fail "crit 29: commit_task r2 failed ($(cat "$TMP/ct.out"))"
grep -qx "COMMIT_SHA=none" "$TMP/ct.out" || fail "crit 29: r2 should commit nothing ($(cat "$TMP/ct.out"))"
eq "$(git -C "$D" for-each-ref refs/heads/orch/r2/)" "" "crit 29: no r2 branch"
RC42=0; /bin/bash "$S/panel_guard.sh" --task Task_C --run-id r2 --state-file "$TMP/ir" >/dev/null 2>&1 || RC42=$?
eq "$RC42" "3" "crit 42: second convene refused"
rm -f "$O/reject"
run_ok "$D" Task_C
ok0 "crit 29 retry"; has "INTEGRATE_TASK_BRANCH=orch/r1/Task_C"
pass "crit 29 / 42"

# --- crit 32 --------------------------------------------------------------------------
setup c32a
mk_task_branch "$D" task/Task_A a.txt 'l1\nA\nl3\n'
PATH="$NOGH_PATH" run_ok "$D" Task_A
ok0 "crit 32 no gh"; has "RELEASE_PR=skipped"; has "WARN: release PR skipped: gh not installed"
git -C "$D" rev-parse -q --verify refs/heads/task/Task_A >/dev/null 2>&1 && fail "crit 32: branch kept"
setup c32b
mk_task_branch "$D" task/Task_A a.txt 'l1\nA\nl3\n'
FAKE_GH_AUTH_RC=1 run_ok "$D" Task_A
ok0 "crit 32 no auth"; has "WARN: release PR skipped: gh not authenticated"
git -C "$D" rev-parse -q --verify refs/heads/task/Task_A >/dev/null 2>&1 && fail "crit 32: branch kept (auth)"
setup c32c
mk_task_branch "$D" task/Task_A a.txt 'l1\nA\nl3\n'
FAKE_GH_FAIL=list run_ok "$D" Task_A
ok0 "crit 32 list fail"; has "RELEASE_PR=failed"
grep -q '^WARN: .*gh pr list' "$TMP/out" || fail "crit 32: WARN names gh pr list"
pass "crit 32"

# --- crit 27 / 28 / telemetry ---------------------------------------------------------
TEL="$(cat "$V"/04_Logs/Telemetry/*.jsonl)"
for pat in '"status":"success"' '"status":"error"' '"error_class":"E5"' '"error_class":"E3"' '"error_class":"E2"'; do
  printf '%s\n' "$TEL" | grep 'integrate_task' | grep -q "$pat" || fail "telemetry lacks $pat for integrate_task"
done
printf '%s\n' "$TEL" | grep -q '"macro":"integrate_task"' || fail "telemetry macro field"
pass "crit 27/28 telemetry"

# --- crit 34 / DoD 4 -------------------------------------------------------------------
grep -q "pr merge" "$TMP/gh_all.log" && fail "crit 34: gh pr merge was invoked"
while read -r o sha; do
  eq "$(git --git-dir="$o" rev-parse refs/heads/main)" "$sha" "crit 34: origin main unchanged ($o)"
done < "$TMP/mains"
SRC="$SCRIPTS/integrate_task.sh"
CODE="$(grep -vE '^[[:space:]]*#' "$SRC")"
PUSHES="$(printf '%s\n' "$CODE" | grep 'git push' || true)"
[[ -n "$PUSHES" ]] || fail "crit 34: no git push line found"
while IFS= read -r l; do
  case "$l" in *refs/heads/staging*) ;; *) fail "crit 34: push not to refs/heads/staging: $l" ;; esac
  case "$l" in *+*|*" -f"*) fail "crit 34: forced push: $l" ;; esac
done <<< "$PUSHES"
for bad in '--force' '--no-verify' 'pr merge' 'git merge ' 'git reset' 'git stash' 'git clean' 'git rebase' 'git pull'; do
  printf '%s\n' "$CODE" | grep -qF -- "$bad" && fail "crit 34: forbidden '$bad' in script"
done
TOK="$(printf '%s\n' "$CODE" | grep -oE '[A-Za-z0-9_]+\.sh' | sort -u | paste -sd, -)"
eq "$TOK" "emit_telemetry.sh,integrate_task.sh,persona_check.sh" "crit 34: .sh tokens"
REFS="$(printf '%s\n' "$CODE" | grep -oE 'SCRIPT_DIR/[A-Za-z0-9_]+\.sh' | sort -u | paste -sd, -)"
eq "$REFS" "SCRIPT_DIR/emit_telemetry.sh,SCRIPT_DIR/persona_check.sh" "crit 34: called atoms"
printf '%s\n' "$CODE" | grep -qE '^(source |\. )' && fail "crit 34: source/dot-include present"
pass "crit 34"

# --- DoD 5: header ---------------------------------------------------------------------
HDR="$(sed '/^set -euo pipefail/q' "$SRC")"
for need in '5  transient' 'INTEGRATE_SHA=' 'INTEGRATE_STATE=' 'INTEGRATE_TASK_BRANCH=' 'RELEASE_PR=' 'WARN:'; do
  printf '%s\n' "$HDR" | grep -qF -- "$need" || fail "header lacks '$need'"
done
pass "header"

# --- bash 3.2 --------------------------------------------------------------------------
RC=0; /bin/bash -n "$SRC" 2>"$TMP/syn" || RC=$?
eq "$RC" "0" "/bin/bash -n integrate_task.sh"
BASH4='declare -A|local -A|typeset -A|mapfile|readarray|\$\{[A-Za-z_]+(,,|\^\^|,|\^)\}|\|&|&>>|coproc|\$\{[A-Za-z_]+@[UuLlQEPAa]\}|;;&|;&|\[\[ -v |printf -v|wait -n|\$EPOCHSECONDS|\$EPOCHREALTIME|\$SRANDOM|\$BASH_ARGV0'
HITS="$(grep -nE "$BASH4" "$SRC" | grep -vE '^[0-9]+:[[:space:]]*#' || true)"
eq "$HITS" "" "no bash-4+ constructs"
eq "$(head -n 1 "$SRC")" "#!/usr/bin/env bash" "shebang"
pass "bash 3.2"

echo "SMOKE: OK"

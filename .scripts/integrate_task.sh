#!/usr/bin/env bash
# integrate_task.sh
#
# Integration atom for /close_task on staging projects. Finds the task branch by
# slug (task/<slug> or orch/<run>/<slug>) and squashes it onto `staging` as exactly
# one single-parent commit, built with merge-tree + commit-tree so the index and
# worktree are untouched until the push. Then keeps the one Release PR
# staging -> default branch current through gh. Operates on the project's code repo
# (git toplevel of the CWD), never on the vault dir.
# Guarantees: the worktree is never touched before the push; untracked files are
# never read, staged or removed; the only ref ever pushed is refs/heads/staging
# (no force, no hooks bypass); the default branch is never merged into or pushed;
# `gh pr merge` is never run.
#
# Side-effect order: fetch staging -> squash as objects -> push -> land local
# staging by fast-forward (HEAD on staging) -> delete the task branch -> gh step.
# Any gh problem is a WARN line and exit 0; the branch is already gone by then.
#
# Contract: Tool_Registry.md § integrate_task (registration is Architect-only,
#           via /graduate — Brain file not edited here).
# Idempotent: Yes, keyed on the `Task-Commit: <full task tip sha>` trailer found in
#             the first-parent history of origin/staging. A re-run whose tip is
#             already there makes no commit and no push; a reused slug with a new
#             tip integrates as a new commit.
# Persona Gate: Executioner (--source-persona, then persona_check.sh).
# Telemetry: MANDATORY (success + error), Composition Rule 3.
#
# Exit codes:
#   0  integrated, already-integrated, skipped-no-branch, or any release-PR WARN
#   1  task file missing, or CWD is not a git work tree (E1)
#   2  squash conflict; git plumbing failure; local landing failed after a successful push (E2)
#   3  precondition refusal or bad args (E3): unknown arg or missing required arg,
#      detached or unborn HEAD, merge/cherry-pick/revert/rebase in progress,
#      no task branch (without --allow-missing-branch) or ambiguous task branch,
#      modified or staged tracked files, git older than 2.38, no origin remote,
#      no staging branch, staging checked out in another worktree,
#      origin has no staging, local staging ahead of or diverged from origin/staging,
#      squash adds no change to staging
#   4  source_persona != Executioner or persona_check failed (E4)
#   5  transient: ls-remote, fetch or push failed; nothing local changed, safe to retry (E5)
#
# stdout contract (exit 0 only, pinned — callers parse these markers, in this order):
#   INTEGRATE_SHA=<short sha|none>
#   INTEGRATE_STATE=<integrated|already-integrated|skipped-no-branch>
#   INTEGRATE_TASK_BRANCH=<branch|none>
#   RELEASE_PR=<created|updated|skipped|failed>
#   WARN: <text>   (0..n)
# On any failure: exactly one `E<n>:` line on stderr and empty stdout.

set -euo pipefail

export GIT_TERMINAL_PROMPT=0

usage() {
  cat <<EOF
Usage: $(basename "$0") --task-path <path> --source-persona <name> [--allow-missing-branch]

Required:
  --task-path <path>        Task .md file; its basename is the task slug
  --source-persona <name>   Caller-claimed persona (must be Executioner)

Optional:
  --allow-missing-branch    No task branch is not an error: report skipped-no-branch

Run from inside the project's code repo.

Exit codes: 0 ok; 1 task file or git work tree missing (E1); 2 git failure (E2);
            3 precondition refusal (E3); 4 persona (E4); 5 transient, retry (E5)
EOF
}

START_TS_MS=$(($(date +%s) * 1000))
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

TASK_PATH=""
SOURCE_PERSONA=""
ALLOW_MISSING=0
TASK_NAME=""

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
: > "$WORK/warn"

emit_err() {
  local end=$(($(date +%s) * 1000))
  "$SCRIPT_DIR/emit_telemetry.sh" integrate_task error $((end - START_TS_MS)) "$1" \
    "${SOURCE_PERSONA:-unknown}" "${TASK_NAME:-null}" 2>/dev/null || true
}

# die <exit> <E-class> <one-line message>
die() {
  local msg
  msg="$(printf '%s' "$3" | tr '\n' ' ')"
  echo "$2: $msg" >&2
  emit_err "$2"
  exit "$1"
}

first_line() { printf '%s\n' "$1" | awk 'NF { print; exit }'; }

sanitize() { local s="${1//[^A-Za-z0-9._-]/-}"; printf '%s' "$s"; }

project_name() {
  local project
  project="$(awk '
    /^---$/ { c++; if (c == 2) exit }
    c == 1 && /^project:/ { sub(/^project:[[:space:]]*/, ""); print; exit }
  ' "$TASK_PATH" | tr -d '[]\r' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  [[ -n "$project" ]] || project="$(basename "$(dirname "$TASK_PATH")")"
  printf '%s' "$project"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --task-path)
      [[ $# -ge 2 ]] || die 3 E3 "--task-path requires a value"
      TASK_PATH="$2"; shift 2 ;;
    --source-persona)
      [[ $# -ge 2 ]] || die 3 E3 "--source-persona requires a value"
      SOURCE_PERSONA="$2"; shift 2 ;;
    --allow-missing-branch) ALLOW_MISSING=1; shift ;;
    -h|--help)              usage; exit 0 ;;
    *)                      die 3 E3 "unknown arg: $1" ;;
  esac
done

if [[ -n "$TASK_PATH" ]]; then
  TASK_NAME="$(basename "$TASK_PATH")"
  TASK_NAME="${TASK_NAME%.md}"
fi

if [[ -z "$TASK_PATH" || -z "$SOURCE_PERSONA" ]]; then
  die 3 E3 "missing required arg (--task-path and --source-persona are required)"
fi

# ============================================================================
# ENFORCEMENT BLOCK (persona-origin guard, Composition Rule 5)
# ============================================================================

if [[ "$SOURCE_PERSONA" != "Executioner" ]]; then
  die 4 E4 "source_persona must be 'Executioner'; got '$SOURCE_PERSONA'"
fi
PC_RC=0
PC_OUT="$("$SCRIPT_DIR/persona_check.sh" Executioner 2>&1)" || PC_RC=$?
if [[ "$PC_RC" -ne 0 ]]; then
  PC_MSG="$(first_line "$PC_OUT")"
  die 4 E4 "integrate_task requires Executioner persona: ${PC_MSG#E4: }"
fi

# ============================================================================

case "$TASK_PATH" in /*) ;; *) TASK_PATH="$PWD/$TASK_PATH" ;; esac
[[ -f "$TASK_PATH" ]] || die 1 E1 "task file not found: $TASK_PATH"

TOP="$(git rev-parse --show-toplevel 2>/dev/null)" || die 1 E1 "not inside a git work tree"
TOP="$(cd "$TOP" && pwd -P)"
cd "$TOP"

git rev-parse --verify -q HEAD >/dev/null 2>&1 || die 3 E3 "HEAD is unborn (no commits yet)"
git symbolic-ref -q --short HEAD >/dev/null 2>&1 || die 3 E3 "HEAD is detached"

for ref in MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD; do
  if git rev-parse -q --verify "$ref" >/dev/null 2>&1; then
    die 3 E3 "$ref present: another git operation is in progress"
  fi
done
for gp in rebase-merge rebase-apply sequencer; do
  if [[ -e "$(git rev-parse --git-path "$gp")" ]]; then
    die 3 E3 "$gp present: another git operation is in progress"
  fi
done

# finish <state> <full-sha|none> <branch|none> : print markers, telemetry, exit 0.
RELEASE_PR="skipped"
finish() {
  local short="none" end
  if [[ "$2" != "none" ]]; then
    short="$(git rev-parse --short "$2")"
  fi
  printf 'INTEGRATE_SHA=%s\n' "$short"
  printf 'INTEGRATE_STATE=%s\n' "$1"
  printf 'INTEGRATE_TASK_BRANCH=%s\n' "$3"
  printf 'RELEASE_PR=%s\n' "$RELEASE_PR"
  cat "$WORK/warn"
  end=$(($(date +%s) * 1000))
  "$SCRIPT_DIR/emit_telemetry.sh" integrate_task success $((end - START_TS_MS)) null \
    "$SOURCE_PERSONA" "$TASK_NAME" 2>/dev/null || true
  exit 0
}

# land <sha> <old-L-or-empty> : fast-forward local staging to sha, HEAD on staging.
LAND_ERR=""
land() {
  local out
  out="$(git switch -q --detach "$1" 2>&1)" || { LAND_ERR="$(first_line "$out")"; return 1; }
  out="$(git update-ref -m "integrate_task: $TASK_NAME" refs/heads/staging "$1" "$2" 2>&1)" \
    || { LAND_ERR="$(first_line "$out")"; return 1; }
  out="$(git switch -q staging 2>&1)" || { LAND_ERR="$(first_line "$out")"; return 1; }
  return 0
}

warn() { printf 'WARN: %s\n' "$1" >> "$WORK/warn"; }

# first_default <ref-prefix> : echo the only existing main|master under the prefix, else nothing.
first_default() {
  local cnt=0 name found=""
  for name in main master; do
    if git show-ref --verify --quiet "$1/$name"; then
      cnt=$((cnt + 1)); found="$name"
    fi
  done
  if [[ "$cnt" -eq 1 ]]; then printf '%s' "$found"; fi
}

# release_pr : create or update the one Release PR; never fails, never exits.
release_pr() {
  local out rc default base n
  RELEASE_PR="skipped"
  if ! command -v gh >/dev/null 2>&1; then
    warn "release PR skipped: gh not installed"; return 0
  fi
  rc=0
  GH_PROMPT_DISABLED=1 GH_NO_UPDATE_NOTIFIER=1 gh auth status >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    warn "release PR skipped: gh not authenticated"; return 0
  fi

  default=""
  if out="$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null)"; then
    default="${out#origin/}"
  fi
  [[ -n "$default" ]] || default="$(first_default refs/remotes/origin)"
  [[ -n "$default" ]] || default="$(first_default refs/heads)"
  if [[ -z "$default" || "$default" == "staging" ]]; then
    warn "release PR skipped: no default branch distinct from staging"; return 0
  fi

  rc=0
  out="$(git fetch --quiet --no-tags origin "+refs/heads/$default:refs/remotes/origin/$default" 2>&1)" || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    warn "release PR base not refreshed (fetch of $default failed)"
  fi
  if git show-ref --verify --quiet "refs/remotes/origin/$default"; then
    base="refs/remotes/origin/$default"
  elif git show-ref --verify --quiet "refs/heads/$default"; then
    base="refs/heads/$default"
  else
    warn "release PR skipped: no default branch distinct from staging"; return 0
  fi

  {
    printf 'Release PR kept current by integrate_task.sh. Each line is one task squash-committed onto staging; revert one task with `git revert <sha>` on staging.\n\n'
    printf 'Tasks on staging not yet in %s:\n\n' "$default"
    git log --first-parent --format='- %s (%h)' "$base..refs/heads/staging"
  } > "$WORK/pr_body"

  rc=0
  out="$(GH_PROMPT_DISABLED=1 GH_NO_UPDATE_NOTIFIER=1 gh pr list --state open --base "$default" --head staging --json number --jq '.[0].number // empty' 2>&1)" || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    RELEASE_PR="failed"
    warn "release PR not updated (gh pr list failed: $(first_line "$out"))"; return 0
  fi
  n="$(printf '%s' "$out" | tr -d '[:space:]')"

  rc=0
  if [[ -n "$n" ]]; then
    out="$(GH_PROMPT_DISABLED=1 GH_NO_UPDATE_NOTIFIER=1 gh pr edit "$n" --body-file "$WORK/pr_body" 2>&1)" || rc=$?
    if [[ "$rc" -eq 0 ]]; then RELEASE_PR="updated"; return 0; fi
    RELEASE_PR="failed"
    warn "release PR not updated (gh pr edit failed: $(first_line "$out"))"; return 0
  fi
  out="$(GH_PROMPT_DISABLED=1 GH_NO_UPDATE_NOTIFIER=1 gh pr create --base "$default" --head staging --title "Release: staging -> $default" --body-file "$WORK/pr_body" 2>&1)" || rc=$?
  if [[ "$rc" -eq 0 ]]; then RELEASE_PR="created"; return 0; fi
  RELEASE_PR="failed"
  warn "release PR not updated (gh pr create failed: $(first_line "$out"))"
  return 0
}

# ---------------------------------------------------------------------------
# 4. Slug lookup
# ---------------------------------------------------------------------------
SLUG="$(sanitize "$TASK_NAME")"
MATCHES=""
while IFS= read -r ref; do
  [[ -n "$ref" ]] || continue
  if [[ "$ref" == "refs/heads/task/$SLUG" ]]; then
    MATCHES="${MATCHES}${ref}"$'\n'
  elif [[ "$ref" == refs/heads/orch/*/"$SLUG" ]]; then
    mid="${ref#refs/heads/orch/}"
    run="${mid%/"$SLUG"}"
    if [[ -n "$run" && "$run" != */* ]]; then
      MATCHES="${MATCHES}${ref}"$'\n'
    fi
  fi
done < <(git for-each-ref --format='%(refname)' "refs/heads/task/$SLUG" "refs/heads/orch/*/$SLUG")

NMATCH=0
if [[ -n "$MATCHES" ]]; then
  NMATCH="$(printf '%s' "$MATCHES" | grep -c '')"
fi
if [[ "$NMATCH" -eq 0 ]]; then
  if [[ "$ALLOW_MISSING" -eq 1 ]]; then
    warn "no task branch for $SLUG; nothing to integrate"
    finish skipped-no-branch none none
  fi
  die 3 E3 "no task branch for $SLUG (task/$SLUG or orch/*/$SLUG)"
fi
if [[ "$NMATCH" -gt 1 ]]; then
  names="$(printf '%s' "$MATCHES" | sed 's#^refs/heads/##' | paste -sd, - | sed 's/,/, /g')"
  die 3 E3 "ambiguous task branch for $SLUG: $names"
fi
TB_REF="$(printf '%s' "$MATCHES" | head -n 1)"
TB="${TB_REF#refs/heads/}"

# ---------------------------------------------------------------------------
# 5. Tracked-clean check (before every network call)
# ---------------------------------------------------------------------------
GIT_OPTIONAL_LOCKS=0 git status --porcelain=v1 -z --untracked-files=no > "$WORK/status.z" \
  || die 2 E2 "git status failed"
dirty_n=0
dirty_list=""
next_is_origin=0
while IFS= read -r -d '' ent; do
  if [[ "$next_is_origin" -eq 1 ]]; then next_is_origin=0; continue; fi
  dirty_n=$((dirty_n + 1))
  if [[ "$dirty_n" -le 5 ]]; then dirty_list="${dirty_list:+$dirty_list, }${ent:3}"; fi
  case "${ent:0:2}" in *R*|*C*) next_is_origin=1 ;; esac
done < "$WORK/status.z"
if [[ "$dirty_n" -gt 0 ]]; then
  more=""
  [[ "$dirty_n" -le 5 ]] || more=" (+$((dirty_n - 5)) more)"
  die 3 E3 "tracked changes present (commit or move them first): $dirty_list$more"
fi

# ---------------------------------------------------------------------------
# 6. Static preconditions
# ---------------------------------------------------------------------------
GV="$(git version | awk '{ print $3 }')"
GMAJ="${GV%%.*}"
GREST="${GV#*.}"
GMIN="${GREST%%.*}"
case "$GMAJ$GMIN" in *[!0-9]*|"") die 3 E3 "git >= 2.38 required (found $GV)" ;; esac
if [[ "$GMAJ" -lt 2 || ( "$GMAJ" -eq 2 && "$GMIN" -lt 38 ) ]]; then
  die 3 E3 "git >= 2.38 required (found $GV)"
fi
git remote get-url origin >/dev/null 2>&1 || die 3 E3 "no origin remote"
if ! git show-ref --verify --quiet refs/heads/staging \
   && ! git show-ref --verify --quiet refs/remotes/origin/staging; then
  die 3 E3 "no staging branch (local staging or origin/staging)"
fi
wt_path=""
while IFS= read -r line; do
  case "$line" in
    "worktree "*) wt_path="${line#worktree }" ;;
    "branch refs/heads/staging")
      wt_norm="$(cd "$wt_path" 2>/dev/null && pwd -P || printf '%s' "$wt_path")"
      if [[ "$wt_norm" != "$TOP" ]]; then
        die 3 E3 "staging is checked out in another worktree: $wt_path"
      fi ;;
  esac
done < <(git worktree list --porcelain)

# ---------------------------------------------------------------------------
# 7. Remote sync
# ---------------------------------------------------------------------------
LS_RC=0
LS_OUT="$(git ls-remote --exit-code --heads origin refs/heads/staging 2>&1)" || LS_RC=$?
if [[ "$LS_RC" -eq 2 ]]; then
  die 3 E3 "origin has no staging branch (publish staging to origin once)"
elif [[ "$LS_RC" -ne 0 ]]; then
  die 5 E5 "ls-remote origin failed: $(first_line "$LS_OUT")"
fi
F_RC=0
F_OUT="$(git fetch --quiet --no-tags origin "+refs/heads/staging:refs/remotes/origin/staging" 2>&1)" || F_RC=$?
if [[ "$F_RC" -ne 0 ]]; then
  die 5 E5 "fetch origin staging failed: $(first_line "$F_OUT")"
fi
R="$(git rev-parse refs/remotes/origin/staging)"

# ---------------------------------------------------------------------------
# 8. Local staging vs origin/staging
# ---------------------------------------------------------------------------
L="$(git rev-parse -q --verify refs/heads/staging 2>/dev/null || true)"
if [[ -n "$L" && "$L" != "$R" ]]; then
  if git merge-base --is-ancestor "$L" "$R"; then
    :
  elif git merge-base --is-ancestor "$R" "$L"; then
    die 3 E3 "local staging is ahead of origin/staging (unpushed commits)"
  else
    die 3 E3 "local staging and origin/staging diverged"
  fi
fi

# ---------------------------------------------------------------------------
# 9. Idempotency via Task-Commit trailer
# ---------------------------------------------------------------------------
TIP="$(git rev-parse "$TB_REF")"
CANDS="$(git log --first-parent --fixed-strings --grep="Task-Commit: $TIP" --format=%H refs/remotes/origin/staging)"
while IFS= read -r cand; do
  [[ -n "$cand" ]] || continue
  if git show -s --format=%B "$cand" | grep -Fxq "Task-Commit: $TIP"; then
    land "$R" "$L" || die 2 E2 "local landing failed: $LAND_ERR"
    DEL_OUT="$(git branch -D "$TB" 2>&1)" || die 2 E2 "deleting $TB failed: $(first_line "$DEL_OUT")"
    release_pr
    finish already-integrated "$R" "$TB"
  fi
done <<< "$CANDS"

# ---------------------------------------------------------------------------
# 10-11. Squash tree and commit
# ---------------------------------------------------------------------------
MT_RC=0
MT_OUT="$(git merge-tree --write-tree --no-messages --name-only "$R" "$TIP" 2>&1)" || MT_RC=$?
if [[ "$MT_RC" -eq 1 ]]; then
  conflicts="$(printf '%s\n' "$MT_OUT" | sed '1d' | awk 'NF' | paste -sd, -)"
  die 2 E2 "squash conflict on staging: $conflicts"
elif [[ "$MT_RC" -ne 0 ]]; then
  die 2 E2 "git merge-tree failed: $(first_line "$MT_OUT")"
fi
TREE="$(printf '%s\n' "$MT_OUT" | head -n 1)"
if [[ "$TREE" == "$(git rev-parse "$R^{tree}")" ]]; then
  die 3 E3 "squash adds no change to staging ($TB)"
fi

{
  printf 'task(%s): %s\n\n' "$(project_name)" "$TASK_NAME"
  printf 'Closes [[%s]]\n\n' "$TASK_NAME"
  printf 'Task-Branch: %s\n' "$TB"
  printf 'Task-Commit: %s\n' "$TIP"
} > "$WORK/msg"
CT_RC=0
C="$(git commit-tree "$TREE" -p "$R" -F "$WORK/msg" 2>&1)" || CT_RC=$?
[[ "$CT_RC" -eq 0 ]] || die 2 E2 "git commit-tree failed: $(first_line "$C")"
SHORT_C="$(git rev-parse --short "$C")"

# ---------------------------------------------------------------------------
# 12-16. Push, land, delete branch, release PR
# ---------------------------------------------------------------------------
P_RC=0
P_OUT="$(git push --quiet origin "$C:refs/heads/staging" 2>&1)" || P_RC=$?
if [[ "$P_RC" -ne 0 ]]; then
  die 5 E5 "push to origin staging failed: $(first_line "$P_OUT")"
fi
UR_OUT="$(git update-ref refs/remotes/origin/staging "$C" 2>&1)" \
  || die 2 E2 "pushed $SHORT_C to origin staging but local landing failed: $(first_line "$UR_OUT"); re-run integrate_task"
land "$C" "$L" \
  || die 2 E2 "pushed $SHORT_C to origin staging but local landing failed: $LAND_ERR; re-run integrate_task"
DEL_OUT="$(git branch -D "$TB" 2>&1)" \
  || die 2 E2 "pushed $SHORT_C but deleting $TB failed: $(first_line "$DEL_OUT"); re-run integrate_task"
release_pr
finish integrated "$C" "$TB"

#!/usr/bin/env bash
# commit_task.sh
#
# Commit atom for /close_task. Reads the task's `## Spec` -> `### Files touched`
# block, keeps only the entries that resolve inside the CWD's git repo, stages
# exactly those dirty paths, and commits them as one commit. Operates on the
# project's code repo (git toplevel of the CWD), never on the vault dir.
# Never pushes, never integrates branches, never touches the vault bookkeeping.
#
# Branch: orch/<run-id> when --run-id is given (Orchestrator mode); otherwise
# task/<slug> when HEAD is on the default branch, else the current branch.
#
# Contract: Tool_Registry.md § commit_task (registration is Architect-only,
#           done via /graduate — Brain file not edited here).
# Idempotent: Yes. A re-run finds the listed paths clean and is a no-op; a re-run
#             after a failed commit is already off the default branch.
# Persona Gate: Executioner (--source-persona, then persona_check.sh).
# Telemetry: MANDATORY (success + error), Composition Rule 3.
#
# Exit codes:
#   0  committed, or nothing to commit (no-op)
#   1  task file missing, or CWD is not a git work tree (E1)
#   2  git switch / add / commit failed (E2)
#   3  precondition refusal or bad args (E3): no Files touched block / no entries,
#      detached or unborn HEAD, merge/cherry-pick/revert/rebase in progress,
#      default branch not found or ambiguous (main and master, no origin/HEAD),
#      invalid branch name,
#      staged paths outside the list, out-of-list tracked changes (Orchestrator)
#   4  source_persona != Executioner or live persona != Executioner (E4)
#
# stdout contract (exit 0 only, pinned — callers parse these markers):
#   COMMIT_BRANCH=<name|none>
#   COMMIT_SHA=<sha|none>
#   COMMIT_STAGED=<n>
#   SKIPPED: <path> (<outside-repo|not-found|ignored|directory|clean>)   (0..n)
#   WARN_OUT_OF_LIST: <path>                                             (0..n)

set -euo pipefail

# Spec paths are literal file names; never let git expand glob characters.
export GIT_LITERAL_PATHSPECS=1

usage() {
  cat <<EOF
Usage: $(basename "$0") --task-path <path> --source-persona <name> [--run-id <id>]

Required:
  --task-path <path>        Task .md file whose Spec lists the files touched
  --source-persona <name>   Caller-claimed persona (must be Executioner)

Optional:
  --run-id <id>             Orchestrator mode: commit onto orch/<id>, refuse
                            out-of-list tracked changes

Run from inside the project's code repo.

Exit codes: 0 ok/no-op; 1 task file or git work tree missing (E1);
            2 git failure (E2); 3 precondition refusal (E3); 4 persona (E4)
EOF
}

TASK_PATH=""
SOURCE_PERSONA=""
RUN_ID=""
RUN_ID_SET=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --task-path)      TASK_PATH="$2"; shift 2 ;;
    --source-persona) SOURCE_PERSONA="$2"; shift 2 ;;
    --run-id)         RUN_ID="$2"; RUN_ID_SET=1; shift 2 ;;
    -h|--help)        usage; exit 0 ;;
    *)                echo "E3: unknown arg: $1" >&2; usage >&2; exit 3 ;;
  esac
done

START_TS_MS=$(($(date +%s) * 1000))
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

TASK_NAME=""
if [[ -n "$TASK_PATH" ]]; then
  TASK_NAME="$(basename "$TASK_PATH")"
  TASK_NAME="${TASK_NAME%.md}"
fi

emit_err() {
  local end=$(($(date +%s) * 1000))
  "$SCRIPT_DIR/emit_telemetry.sh" commit_task error $((end - START_TS_MS)) "$1" \
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

if [[ -z "$TASK_PATH" || -z "$SOURCE_PERSONA" ]]; then
  usage >&2
  die 3 E3 "missing required arg (--task-path and --source-persona are required)"
fi
if [[ "$RUN_ID_SET" -eq 1 && -z "$RUN_ID" ]]; then
  die 3 E3 "--run-id must not be empty"
fi

# ============================================================================
# ENFORCEMENT BLOCK (persona-origin guard, Composition Rule 5)
# ============================================================================

if [[ "$SOURCE_PERSONA" != "Executioner" ]]; then
  die 4 E4 "source_persona must be 'Executioner'; got '$SOURCE_PERSONA'"
fi
if ! "$SCRIPT_DIR/persona_check.sh" "Executioner"; then
  die 4 E4 "commit_task requires Executioner persona; persona_check failed (see above)"
fi

# ============================================================================

case "$TASK_PATH" in /*) ;; *) TASK_PATH="$PWD/$TASK_PATH" ;; esac
[[ -f "$TASK_PATH" ]] || die 1 E1 "task file not found: $TASK_PATH"

TOP="$(git rev-parse --show-toplevel 2>/dev/null)" || die 1 E1 "not inside a git work tree"
TOP="$(cd "$TOP" && pwd -P)"
cd "$TOP"

git rev-parse --verify -q HEAD >/dev/null 2>&1 || die 3 E3 "HEAD is unborn (no commits yet)"
CUR_BRANCH="$(git symbolic-ref -q --short HEAD 2>/dev/null)" || die 3 E3 "HEAD is detached"

# A merge/cherry-pick/revert/rebase in progress would turn the commit into its
# conclusion (e.g. a two-parent commit), so refuse before any git change.
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

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# ---------------------------------------------------------------------------
# 2. Extract the Files touched block from the Spec section.
# The Spec section runs from a `##` header ending in "Spec" (or starting
# "Spec:") to the next other `##` header; the spec body itself opens with
# `## Spec: <Task>`, which must not end the section.
# ---------------------------------------------------------------------------
awk '
  /^##[[:space:]]/ {
    if ($0 ~ /Spec[[:space:]]*$/ || $0 ~ /^##[[:space:]]+Spec:/) { insec = 1; next }
    if (insec) insec = 0
  }
  !insec { next }
  /^#+[[:space:]]/ {
    match($0, /^#+/); lvl = RLENGTH
    if (inblk && lvl <= blvl) exit
    if (!inblk && lvl >= 2 && lvl <= 4 && $0 ~ /^#+[[:space:]]+[Ff]iles [Tt]ouched/) {
      inblk = 1; blvl = lvl; next
    }
  }
  inblk { print }
' "$TASK_PATH" > "$WORK/block"

# extract_path <line> — path of one marked entry, empty if none found.
extract_path() {
  local s="$1" t p="" tok
  case "$s" in *"— owns:"*) s="${s%%— owns:*}" ;; esac
  case "$s" in *"owns:"*) s="${s%%owns:*}" ;; esac
  if [[ "$s" == *'`'*'`'* ]]; then
    t="${s#*\`}"
    p="${t%%\`*}"
  else
    s="${s//\[NEW\]/ }"; s="${s//\[EDIT\]/ }"; s="${s//\[DELETE\]/ }"
    set -f
    for tok in $s; do
      if [[ "$tok" =~ ^[0-9]+\.$ ]]; then continue; fi
      if [[ "$tok" == */* || "$tok" == *.* ]]; then p="$tok"; break; fi
    done
    set +f
  fi
  while [[ "$p" == *[,\;:\)] ]]; do p="${p%?}"; done
  p="${p#"${p%%[![:space:]]*}"}"
  p="${p%"${p##*[![:space:]]}"}"
  printf '%s' "$p"
}

# canon_path <abs-path> — canonical parent dir + basename (macOS /var vs /private/var,
# .vault_link symlinks); lexical when the parent does not exist.
canon_path() {
  local p="$1" d b
  while [[ "$p" == */ && "$p" != "/" ]]; do p="${p%/}"; done
  d="$(dirname "$p")"; b="$(basename "$p")"
  if [[ -d "$d" ]]; then
    d="$(cd "$d" && pwd -P)"
    printf '%s/%s\n' "${d%/}" "$b"
  else
    printf '%s\n' "$p"
  fi
}

: > "$WORK/list_all"
: > "$WORK/cand"
: > "$WORK/skipped"
N_MARKED=0
N_PATHS=0

while IFS= read -r line || [[ -n "$line" ]]; do
  case "$line" in *'[NEW]'*|*'[EDIT]'*|*'[DELETE]'*) ;; *) continue ;; esac
  N_MARKED=$((N_MARKED + 1))
  p="$(extract_path "$line")"
  [[ -z "$p" ]] && continue
  N_PATHS=$((N_PATHS + 1))

  case "$p" in /*) abs="$p" ;; *) abs="$TOP/$p" ;; esac
  abs="$(canon_path "$abs")"

  case "$abs" in
    "$TOP"/*) rel="${abs#"$TOP"/}" ;;
    *) printf 'SKIPPED: %s (outside-repo)\n' "$p" >> "$WORK/skipped"; continue ;;
  esac
  grep -Fxq -- "$rel" "$WORK/list_all" && continue
  printf '%s\n' "$rel" >> "$WORK/list_all"

  if [[ -d "$abs" && ! -L "$abs" ]]; then
    printf 'SKIPPED: %s (directory)\n' "$rel" >> "$WORK/skipped"; continue
  fi
  # check-ignore rejects the literal-pathspec magic exported above (exit 128).
  if GIT_LITERAL_PATHSPECS=0 git check-ignore -q -- "$rel" 2>/dev/null; then
    printf 'SKIPPED: %s (ignored)\n' "$rel" >> "$WORK/skipped"; continue
  fi
  # A path removed with `git rm` is gone from disk and index but still in HEAD.
  if [[ ! -e "$abs" && ! -L "$abs" ]] && [[ -z "$(git ls-files -- "$rel")" ]] \
     && ! git cat-file -e "HEAD:$rel" 2>/dev/null; then
    printf 'SKIPPED: %s (not-found)\n' "$rel" >> "$WORK/skipped"; continue
  fi
  printf '%s\n' "$rel" >> "$WORK/cand"
done < "$WORK/block"

if [[ "$N_MARKED" -eq 0 ]]; then
  die 3 E3 "no Files touched block with [NEW]/[EDIT]/[DELETE] entries in $TASK_PATH"
fi
if [[ "$N_PATHS" -eq 0 ]]; then
  die 3 E3 "no parsable paths in the Files touched block of $TASK_PATH"
fi

# ---------------------------------------------------------------------------
# 4. Dirty sets (all repo-root relative).
# ---------------------------------------------------------------------------
: > "$WORK/tracked"
: > "$WORK/untracked"
: > "$WORK/staged"

git status --porcelain=v1 -z --untracked-files=no > "$WORK/status.z" \
  || die 2 E2 "git status failed"
next_is_origin=0
while IFS= read -r -d '' ent; do
  if [[ "$next_is_origin" -eq 1 ]]; then
    printf '%s\n' "$ent" >> "$WORK/tracked"; next_is_origin=0; continue
  fi
  printf '%s\n' "${ent:3}" >> "$WORK/tracked"
  case "${ent:0:2}" in *R*|*C*) next_is_origin=1 ;; esac
done < "$WORK/status.z"

git ls-files --others --exclude-standard -z > "$WORK/untracked.z" \
  || die 2 E2 "git ls-files failed"
while IFS= read -r -d '' ent; do
  printf '%s\n' "$ent" >> "$WORK/untracked"
done < "$WORK/untracked.z"

git diff --cached --name-only --no-renames -z > "$WORK/staged.z" \
  || die 2 E2 "git diff --cached failed"
while IFS= read -r -d '' ent; do
  printf '%s\n' "$ent" >> "$WORK/staged"
done < "$WORK/staged.z"

cat "$WORK/tracked" "$WORK/untracked" "$WORK/staged" | sort -u > "$WORK/dirty"

# out_of_list <file> — lines of <file> not present in the spec list.
out_of_list() { grep -Fxv -f "$WORK/list_all" "$1" || true; }
# join_csv — stdin lines to "a, b, c".
join_csv() { paste -sd, - | sed 's/,/, /g'; }

STAGED_OUT="$(out_of_list "$WORK/staged")"
if [[ -n "$STAGED_OUT" ]]; then
  die 3 E3 "staged paths outside the spec list: $(printf '%s\n' "$STAGED_OUT" | join_csv)"
fi

TRACKED_OUT="$(sort -u "$WORK/tracked" | { grep -Fxv -f "$WORK/list_all" || true; })"
if [[ -n "$RUN_ID" && -n "$TRACKED_OUT" ]]; then
  die 3 E3 "out-of-list tracked changes: $(printf '%s\n' "$TRACKED_OUT" | join_csv)"
fi

# Candidates that are actually dirty form the in-list set; the rest are clean.
: > "$WORK/in_dirty"
while IFS= read -r rel; do
  [[ -z "$rel" ]] && continue
  if grep -Fxq -- "$rel" "$WORK/dirty"; then
    printf '%s\n' "$rel" >> "$WORK/in_dirty"
  else
    printf 'SKIPPED: %s (clean)\n' "$rel" >> "$WORK/skipped"
  fi
done < "$WORK/cand"

emit_result() { # emit_result <branch> <sha> <staged-count>
  printf 'COMMIT_BRANCH=%s\nCOMMIT_SHA=%s\nCOMMIT_STAGED=%s\n' "$1" "$2" "$3"
  cat "$WORK/skipped"
  if [[ -z "$RUN_ID" ]]; then
    { printf '%s\n' "$TRACKED_OUT"; out_of_list "$WORK/untracked"; } \
      | sort -u | while IFS= read -r w; do
          if [[ -n "$w" ]]; then printf 'WARN_OUT_OF_LIST: %s\n' "$w"; fi
        done
  fi
  local end=$(($(date +%s) * 1000))
  "$SCRIPT_DIR/emit_telemetry.sh" commit_task success $((end - START_TS_MS)) null \
    "$SOURCE_PERSONA" "$TASK_NAME" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# 5. No-op: nothing listed is dirty.
# ---------------------------------------------------------------------------
if [[ ! -s "$WORK/in_dirty" ]]; then
  emit_result none none 0
  exit 0
fi

# ---------------------------------------------------------------------------
# 6. Branch selection (all refusals happen before the first git change).
# ---------------------------------------------------------------------------
sanitize() { local s="${1//[^A-Za-z0-9._-]/-}"; printf '%s' "$s"; }

if [[ -n "$RUN_ID" ]]; then
  TARGET="orch/$(sanitize "$RUN_ID")"
else
  DEFAULT_BRANCH=""
  if ref="$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null)"; then
    DEFAULT_BRANCH="${ref#origin/}"
  else
    HAS_MAIN=0; HAS_MASTER=0
    git show-ref --verify --quiet refs/heads/main && HAS_MAIN=1
    git show-ref --verify --quiet refs/heads/master && HAS_MASTER=1
    if [[ "$HAS_MAIN" -eq 1 && "$HAS_MASTER" -eq 1 ]]; then
      die 3 E3 "default branch ambiguous (no origin/HEAD; both main and master exist)"
    elif [[ "$HAS_MAIN" -eq 1 ]]; then
      DEFAULT_BRANCH="main"
    elif [[ "$HAS_MASTER" -eq 1 ]]; then
      DEFAULT_BRANCH="master"
    fi
  fi
  [[ -n "$DEFAULT_BRANCH" ]] || die 3 E3 "default branch not found (no origin/HEAD, main or master)"
  if [[ "$CUR_BRANCH" == "$DEFAULT_BRANCH" ]]; then
    TARGET="task/$(sanitize "$TASK_NAME")"
  else
    TARGET="$CUR_BRANCH"
  fi
fi
git check-ref-format --branch "$TARGET" >/dev/null 2>&1 || die 3 E3 "invalid branch name: $TARGET"

if [[ "$TARGET" != "$CUR_BRANCH" ]]; then
  if git show-ref --verify --quiet "refs/heads/$TARGET"; then
    SW_OUT="$(git switch -q "$TARGET" 2>&1)" || die 2 E2 "git switch failed: $(printf '%s' "$SW_OUT" | head -n 1)"
  else
    SW_OUT="$(git switch -q -c "$TARGET" 2>&1)" || die 2 E2 "git switch -c failed: $(printf '%s' "$SW_OUT" | head -n 1)"
  fi
fi

# ---------------------------------------------------------------------------
# 7. Stage exactly the in-list dirty paths, commit.
# ---------------------------------------------------------------------------
while IFS= read -r rel; do
  # Already-staged deletion (`git rm`): not on disk, not in the index; add would fail.
  if [[ ! -e "$TOP/$rel" && ! -L "$TOP/$rel" && -z "$(git ls-files -- "$rel")" ]]; then
    continue
  fi
  ADD_OUT="$(git add -A -- "$rel" 2>&1)" || die 2 E2 "git add failed for $rel: $(printf '%s' "$ADD_OUT" | head -n 1)"
done < "$WORK/in_dirty"

if git diff --cached --quiet; then
  emit_result "$TARGET" none 0
  exit 0
fi
N_STAGED="$(git diff --cached --name-only --no-renames | wc -l | tr -d ' ')"

PROJECT="$(awk '
  /^---$/ { c++; if (c == 2) exit }
  c == 1 && /^project:/ { sub(/^project:[[:space:]]*/, ""); print; exit }
' "$TASK_PATH" | tr -d '[]\r' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
[[ -n "$PROJECT" ]] || PROJECT="$(basename "$(dirname "$TASK_PATH")")"

{
  printf 'task(%s): %s\n\n' "$PROJECT" "$TASK_NAME"
  printf 'Closes [[%s]] via /close_task.\n' "$TASK_NAME"
  if [[ -n "$RUN_ID" ]]; then printf '\nOrchestrator run: %s\n' "$RUN_ID"; fi
} > "$WORK/msg"

CM_OUT="$(git commit -q -F "$WORK/msg" 2>&1)" || die 2 E2 "git commit failed: $(printf '%s' "$CM_OUT" | grep -v '^[[:space:]]*$' | head -n 1)"

SHA="$(git rev-parse --short HEAD)"
emit_result "$TARGET" "$SHA" "$N_STAGED"
exit 0

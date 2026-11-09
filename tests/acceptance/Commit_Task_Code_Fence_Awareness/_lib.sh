#!/usr/bin/env bash
# Shared setup for Commit_Task_Code_Fence_Awareness acceptance tests.
# Every script runs from a mktemp vault copy; every git repo is a mktemp repo.
set -uo pipefail
unset TITAN_SESSION_ID TELEMETRY_DIR GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

VAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
# Pre-fix HEAD pinned by the spec (FENCE_RED_REF); used to prove each case reproduces the bug.
PRE_FIX_REF="91c1dddecf803d46e1cf1c9ddd5d89ab23a721d3"

TMP="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

FAILED=0
fail() { echo "FAIL: $1" >&2; FAILED=1; }
pass() { echo "ok: $1"; }
finish() { [ "$FAILED" -eq 0 ] && { echo "PASS"; exit 0; }; echo "FAILED" >&2; exit 1; }

SCRIPTS_USED="commit_task lib_section write_task_section persona_check emit_telemetry"

# mk_vault <dir> [prefix]: temp vault with an Executioner session. prefix=1 copies the
# pre-fix scripts from PRE_FIX_REF instead of the working tree.
mk_vault() {
  local d="$1" s
  mkdir -p "$d/.scripts" "$d/04_Logs/Telemetry" "$d/02_Tasks/P"
  for s in $SCRIPTS_USED; do
    if [ "${2:-0}" = 1 ]; then
      git -C "$VAULT" show "$PRE_FIX_REF:.scripts/$s.sh" > "$d/.scripts/$s.sh" || return 1
    else
      cp "$VAULT/.scripts/$s.sh" "$d/.scripts/"
    fi
  done
  chmod +x "$d/.scripts/"*.sh
  printf '{\n  "persona": "Executioner",\n  "session_id": "acc",\n  "started_at": "2026-11-09T00:00:00Z",\n  "agent_surface": "test"\n}\n' > "$d/.session_state.json"
}

# mk_repo <dir>: clean repo on main with a.txt and decoy.txt committed.
mk_repo() {
  local d="$1"
  mkdir -p "$d"
  git init -q -b main "$d"
  git -C "$d" config user.name Test
  git -C "$d" config user.email test@example.com
  printf 'a0\n' > "$d/a.txt"; printf 'd0\n' > "$d/decoy.txt"
  git -C "$d" add -A && git -C "$d" commit -q -m init
}

# write_task <path> <spec body file>: task in template shape whose Spec section holds the body.
write_task() {
  {
    printf -- '---\nproject: [[P]]\nstatus: in_progress\ntype: task\n---\n# Task: T\n\n'
    printf '## 📐 Spec\n> Populated by invoke_spec_writer.\n<!-- write_task_section section=spec -->\n\n'
    cat "$2"
    printf '\n## ✅ Validator Report\n<!-- write_task_section section=validator_report -->\n- [NEW] `late.txt` must not be parsed\n\n'
    printf '## 🔗 Related Context\n- none\n'
  } > "$1"
}

# run_commit <vault> <repo> <task>: runs commit_task from the repo; sets CT_RC, CT_OUT, CT_ERR.
run_commit() {
  CT_OUT="$TMP/ct.out"; CT_ERR="$TMP/ct.err"
  (cd "$2" && bash "$1/.scripts/commit_task.sh" --task-path "$3" --source-persona Executioner) >"$CT_OUT" 2>"$CT_ERR"
  CT_RC=$?
}

# committed_files <repo>: sorted file list of the HEAD commit.
committed_files() { git -C "$1" diff-tree --no-commit-id --name-only -r HEAD | sort | tr '\n' ' '; }

# mk_section_task <path>: bare template task for write_task_section cases.
mk_section_task() {
  cat > "$1" <<'T_EOF'
---
project: [[P]]
status: in_progress
type: task
---
# Task: T

## 🔬 Research Notes
<!-- write_task_section section=research_notes -->

## 📐 Spec
<!-- write_task_section section=spec -->

## ✅ Validator Report
<!-- write_task_section section=validator_report -->

## 📊 Verification Output
<!-- write_task_section section=verification_output -->

## 🔗 Related Context
- none
T_EOF
}

# wts <vault> <task> <content file> [--overwrite]: sets W_RC; stderr in $TMP/wts.err.
wts() {
  (cd "$1" && bash .scripts/write_task_section.sh --task-path "$2" --section spec \
     --source-persona Executioner --content-file "$3" ${4:-}) >/dev/null 2>"$TMP/wts.err"
  W_RC=$?
}

count() { grep -cF -- "$1" "$2" || true; }

#!/usr/bin/env bash
# Shared setup: temp vault copy of the scripts, throwaway repos, never the live vault.
set -uo pipefail
unset TITAN_SESSION_ID TELEMETRY_DIR GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 LC_ALL=C
VAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
TMP="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT
FAILED=0
fail() { echo "FAIL: $1" >&2; FAILED=1; }
pass() { echo "ok: $1"; }
eq() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (expected [$3] got [$2])"; fi; }
finish() { [ "$FAILED" -eq 0 ] && { echo PASS; exit 0; }; echo FAILED >&2; exit 1; }

V="$TMP/vault"; S="$V/.scripts"
mkdir -p "$S" "$V/04_Logs/Telemetry" "$V/02_Tasks/P"
cp "$VAULT"/.scripts/{commit_task,lib_section,persona_check,emit_telemetry}.sh "$S/"
printf '{\n  "persona": "Executioner",\n  "session_id": "acc",\n  "started_at": "2026-11-09T00:00:00Z",\n  "agent_surface": "test"\n}\n' > "$V/.session_state.json"

# mk_task <Name> <file>: task whose Spec lists exactly one file.
mk_task() {
  printf -- '---\nproject: [[P]]\nstatus: in_progress\ntype: task\n---\n# Task: %s\n\n## 📐 Spec\n<!-- write_task_section section=spec -->\n\n## Spec: %s\n\n### Files touched\n- [EDIT] `%s`\n\n## ✅ Validator Report\n' "$1" "$1" "$2" > "$V/02_Tasks/P/$1.md"
}
mk_task T_One a.txt; mk_task T_Two c.txt; mk_task T_Three d.txt

# mk_repo <dir> [remote]
mk_repo() {
  mkdir -p "$1"; git init -q -b main "$1"
  git -C "$1" config user.name T; git -C "$1" config user.email t@e.com
  printf 'a0\n' > "$1/a.txt"; printf 'c0\n' > "$1/c.txt"; printf 'd0\n' > "$1/d.txt"
  git -C "$1" add -A; git -C "$1" commit -q -m init
  if [ -n "${2:-}" ]; then
    git init -q --bare -b main "$2"; git -C "$1" remote add origin "$2"
    git -C "$1" push -q -u origin main
  fi
}
# add_staging <repo> [push]: staging with one extra commit (stg.txt), back on main.
add_staging() {
  git -C "$1" switch -q -c staging; printf 's\n' > "$1/stg.txt"
  git -C "$1" add stg.txt; git -C "$1" commit -q -m stg
  [ -n "${2:-}" ] && git -C "$1" push -q -u origin staging
  git -C "$1" switch -q main
}
# ct <repo> <task> [args...]: sets RC OUT ERR
ct() {
  local r="$1" t="$2"; shift 2
  (cd "$r" && /bin/bash "$S/commit_task.sh" --task-path "$V/02_Tasks/P/$t.md" --source-persona Executioner "$@") >"$TMP/o" 2>"$TMP/e"
  RC=$?; OUT="$(cat "$TMP/o")"; ERR="$(cat "$TMP/e")"
}
rp() { git -C "$1" rev-parse "$2" 2>/dev/null; }
head_br() { git -C "$1" symbolic-ref --short HEAD; }
dirty() { printf 'x%s\n' "$RANDOM" >> "$1/$2"; }

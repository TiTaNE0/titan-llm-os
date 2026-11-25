#!/usr/bin/env bash
# Shared setup: temp vault copy of scripts, local bare origins, fake gh on isolated PATH.
set -uo pipefail
unset TITAN_SESSION_ID TELEMETRY_DIR GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR \
      FAKE_GH_FAIL FAKE_GH_PR FAKE_GH_AUTH_RC FAKE_GIT_FAIL GH_REPO
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 LC_ALL=C
VAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
TMP="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT
FAILED=0
fail() { echo "FAIL: $1" >&2; FAILED=1; }
pass() { echo "ok: $1"; }
eq() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (expected [$3] got [$2])"; fi; }
has() { if printf '%s' "$2" | grep -Fq -- "$3"; then pass "$1"; else fail "$1 (missing [$3] in [$2])"; fi; }
finish() { [ "$FAILED" -eq 0 ] && { echo PASS; exit 0; }; echo FAILED >&2; exit 1; }

REAL_GIT="$(command -v git)"; REAL_JQ="$(command -v jq)"
mkdir -p "$TMP/bin" "$TMP/fake"
cat > "$TMP/bin/git" <<G
#!/bin/bash
if [ -n "\${FAKE_GIT_FAIL:-}" ] && [ "\$1" = "\$FAKE_GIT_FAIL" ]; then echo "fatal: simulated \$1 failure" >&2; exit 128; fi
exec "$REAL_GIT" "\$@"
G
chmod +x "$TMP/bin/git"; ln -s "$REAL_JQ" "$TMP/bin/jq"
cat > "$TMP/fake/gh" <<'G'
#!/bin/bash
echo "$*" >> "$GH_LOG"
case "$1 $2" in
  "auth status") exit "${FAKE_GH_AUTH_RC:-0}";;
  "pr list") [ "${FAKE_GH_FAIL:-}" = list ] && { echo "boom list" >&2; exit 1; }; [ -n "${FAKE_GH_PR:-}" ] && echo "$FAKE_GH_PR"; exit 0;;
  "pr create") [ "${FAKE_GH_FAIL:-}" = create ] && { echo "boom create" >&2; exit 1; }; exit 0;;
  "pr edit") [ "${FAKE_GH_FAIL:-}" = edit ] && { echo "boom edit" >&2; exit 1; }; exit 0;;
esac
exit 0
G
chmod +x "$TMP/fake/gh"
export GH_LOG="$TMP/gh.log"; : > "$GH_LOG"
export PATH="$TMP/fake:$TMP/bin:/usr/bin:/bin:/usr/sbin:/sbin"
[ "$(command -v gh)" = "$TMP/fake/gh" ] || { echo "FAIL: fake gh not first on PATH" >&2; exit 1; }

V="$TMP/vault"; S="$V/.scripts"
mkdir -p "$S" "$V/04_Logs/Telemetry" "$V/02_Tasks/P"
cp "$VAULT"/.scripts/{integrate_task,commit_task,lib_section,persona_check,emit_telemetry}.sh "$S/"
printf '{\n  "persona": "Executioner",\n  "session_id": "acc",\n  "started_at": "2026-11-09T00:00:00Z",\n  "agent_surface": "test"\n}\n' > "$V/.session_state.json"
for t in T_One T_Two T_Three; do
  printf -- '---\nproject: [[Acme]]\nstatus: in_progress\n---\n# Task: %s\n' "$t" > "$V/02_Tasks/P/$t.md"
done

# mk_repo <dir> <bare>: main + staging (stg.txt) both pushed; back on main.
mk_repo() {
  git init -q --bare -b main "$2"
  printf '#!/bin/sh\n[ -e "$GIT_DIR/reject" ] && exit 1\nexit 0\n' > "$2/hooks/pre-receive"; chmod +x "$2/hooks/pre-receive"
  mkdir -p "$1"; git init -q -b main "$1"
  git -C "$1" config user.name T; git -C "$1" config user.email t@e.com
  printf 'a0\n' > "$1/a.txt"; printf 'c0\n' > "$1/c.txt"
  git -C "$1" add -A; git -C "$1" commit -q -m init
  git -C "$1" remote add origin "$2"; git -C "$1" push -q -u origin main
  git -C "$1" remote set-head origin main
  git -C "$1" switch -q -c staging; printf 's\n' > "$1/stg.txt"
  git -C "$1" add stg.txt; git -C "$1" commit -q -m stg
  git -C "$1" push -q -u origin staging; git -C "$1" switch -q main
}
# mk_branch <repo> <branch> <file> <content> [ncommits]
mk_branch() {
  git -C "$1" switch -q --no-track -c "$2" staging
  printf '%s\n' "$4" > "$1/$3"; git -C "$1" add "$3"; git -C "$1" commit -q -m "w $3"
  if [ "${5:-1}" = 2 ]; then printf '%s2\n' "$4" >> "$1/$3"; git -C "$1" commit -q -am "w2 $3"; fi
}
# it <repo> <task> [args...]: sets RC OUT ERR
it() {
  local r="$1" t="$2"; shift 2
  : > "$GH_LOG"
  (cd "$r" && /bin/bash "$S/integrate_task.sh" --task-path "$V/02_Tasks/P/$t.md" --source-persona Executioner "$@") >"$TMP/o" 2>"$TMP/e"
  RC=$?; OUT="$(cat "$TMP/o")"; ERR="$(cat "$TMP/e")"
}
rp() { git -C "$1" rev-parse "$2" 2>/dev/null; }
snap() { # <repo> <bare>
  git -C "$1" for-each-ref --format='%(refname) %(objectname)' refs/heads
  git -C "$1" rev-parse HEAD; git -C "$1" symbolic-ref -q HEAD || echo detached
  git -C "$1" ls-files -s | cksum; git -C "$1" status --porcelain
  git --git-dir="$2" for-each-ref
}

#!/usr/bin/env bash
# Shared setup for the Synthesize_Refuse_An_Unfinished_Week acceptance tests.
# Every write goes to a mktemp sandbox vault; the real vault is only read.
set -uo pipefail
unset TITAN_SESSION_ID TELEMETRY_DIR

VAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
RUNBOOK="$VAULT/.scripts/runbooks/synthesize.md"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/synunf.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

FAILED=0
fail() { echo "FAIL: $1" >&2; FAILED=1; }
pass() { echo "ok: $1"; }
finish() { [ "$FAILED" -eq 0 ] && { echo "PASS"; exit 0; }; echo "FAILED" >&2; exit 1; }
eq() { [ "$2" = "$3" ] && pass "$1" || fail "$1 (got '$2', want '$3')"; }
has() { grep -qF -- "$2" "$1" && pass "$3" || fail "$3 (missing: $2)"; }
hasnt() { grep -qF -- "$2" "$1" && fail "$3 (present: $2)" || pass "$3"; }

mk_sandbox() {
  local d="$1" day
  mkdir -p "$d/.scripts" "$d/04_Logs" "$d/03_Brain/Weekly_Synthesis"
  cp "$VAULT/.scripts/synthesize_run.sh" "$d/.scripts/"; chmod +x "$d/.scripts/"*.sh
  ln -s . "$d/.vault_link"
  for day in 2026-11-16 2026-11-22 2026-11-23 2026-11-27 2026-11-28; do echo "- log $day" > "$d/04_Logs/$day.md"; done
  echo '{"id":"fact_2026-W20_001","claim":"a","confidence":0.9,"citations":5,"status":"active"}' > "$d/03_Brain/Weekly_Synthesis/facts.jsonl"
  ( cd "$d" && git init -q && git add -A && git -c user.name=t -c user.email=t@t commit -q -m init ) >/dev/null 2>&1
}
manifest() { ( cd "$1" && find . -path ./.git -prune -o \( -type f -o -type l \) -print | LC_ALL=C sort | while read -r f; do
  if [ -L "$f" ]; then echo "link  $f"; else echo "$(shasum -a 256 "$f" | cut -d' ' -f1)  $f"; fi; done ); }
# plan <dir> <args...>: sets RC, OUT, ERR.
plan() { local d="$1"; shift; OUT="$( cd "$d" && ./.vault_link/.scripts/synthesize_run.sh plan "$@" 2>"$TMP/err" )"; RC=$?; ERR="$(cat "$TMP/err")"; }

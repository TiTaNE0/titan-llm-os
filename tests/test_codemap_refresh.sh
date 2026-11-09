#!/usr/bin/env bash
# test_codemap_refresh.sh - gateway for CODEMAP_Per_Project_Refresh_At_Close.
# Every repo is a mktemp git repo; the vault and kit repos are never mutated.
# CMR_SKIP_SUITES=1 skips the full-chain run (aggregators use it to avoid recursion).
set -uo pipefail
unset TITAN_SESSION_ID TELEMETRY_DIR ACC_SKIP_GATEWAY

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
KIT="$(cd "${KIT_ROOT:-$HOME/AI_Workflow/claude-agent-kit}" && pwd -P)"
SCRIPT="$REPO_ROOT/.scripts/codemap_refresh.sh"
CT="$KIT/project-template/.claude/commands/close_task.md"
PL="$KIT/global/agents/planner.md"
TMP="$(cd "$(mktemp -d)" && pwd -P)"; trap 'rm -rf "$TMP"' EXIT
FAILS=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAILS=$((FAILS + 1)); }
eq() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (got '$2', want '$3')"; fi; }

newrepo() { # name
  local d="$TMP/$1"; mkdir -p "$d"; git -C "$d" init -q
  git -C "$d" config user.name t; git -C "$d" config user.email t@t; git -C "$d" config commit.gpgsign false
  echo "$d"
}
cm() { git -C "$1" add -A -- . ':!CODEMAP.md' && git -C "$1" commit -qm "$2"; }
run() { # dir args... ; sets OUT, RC
  local d="$1"; shift
  OUT="$(cd "$d" && bash "$SCRIPT" "$@" 2>"$TMP/err")"; RC=$?
}

# --- DoD1 ---
R="$(newrepo r1)"; mkdir -p "$R/sub"; echo 1 > "$R/a.txt"; echo 2 > "$R/b.txt"; echo 3 > "$R/sub/c.txt"; cm "$R" init
run "$R"; eq "DoD1 no-arg prints refreshed" "$OUT" "CODEMAP: refreshed"; eq "DoD1 exit 0" "$RC" 0
[ -f "$R/CODEMAP.md" ] && pass "DoD1 file created" || fail "DoD1 file created"
eq "DoD1 starts with header" "$(head -n 1 "$R/CODEMAP.md")" "# CODEMAP"
for p in a.txt b.txt sub/c.txt; do grep -qF "\`$p\`" "$R/CODEMAP.md" && pass "DoD1 lists $p" || fail "DoD1 lists $p"; done
grep -qF '`CODEMAP.md`' "$R/CODEMAP.md" && fail "DoD1 no self entry" || pass "DoD1 no self entry"
c1="$(cksum < "$R/CODEMAP.md")"; run "$R"; eq "DoD1 byte-identical rerun" "$(cksum < "$R/CODEMAP.md")" "$c1"

# --- cap ---
R="$(newrepo r2)"; mkdir -p "$R/big"; for i in $(seq 1 55); do echo x > "$R/big/f$i"; done; cm "$R" big
run "$R"; eq "cap entries" "$(grep -c '^- `big/' "$R/CODEMAP.md")" 50
grep -qxF -- '- (+5 more)' "$R/CODEMAP.md" && pass "cap marker" || fail "cap marker"

# --- DoD2 add/rename/delete/untouched ---
R="$(newrepo r3)"; echo 1 > "$R/a.txt"; echo 2 > "$R/old.txt"; echo 3 > "$R/gone.txt"; cm "$R" init; run "$R"
echo n > "$R/new.txt"; cm "$R" add; run "$R" --sha HEAD
eq "DoD2 add refreshed" "$OUT" "CODEMAP: refreshed"; grep -qF '`new.txt`' "$R/CODEMAP.md" && pass "DoD2 add path present" || fail "DoD2 add path present"
git -C "$R" mv old.txt renamed.txt; cm "$R" mv; run "$R" --sha HEAD
eq "DoD2 rename refreshed" "$OUT" "CODEMAP: refreshed"
grep -qF '`renamed.txt`' "$R/CODEMAP.md" && ! grep -qF '`old.txt`' "$R/CODEMAP.md" && pass "DoD2 rename paths" || fail "DoD2 rename paths"
git -C "$R" rm -q gone.txt; cm "$R" rm; run "$R" --sha HEAD
eq "DoD2 delete refreshed" "$OUT" "CODEMAP: refreshed"; grep -qF '`gone.txt`' "$R/CODEMAP.md" && fail "DoD2 delete path gone" || pass "DoD2 delete path gone"
echo SENTINEL >> "$R/CODEMAP.md"; pre="$(cksum < "$R/CODEMAP.md")"
echo more >> "$R/a.txt"; cm "$R" edit; run "$R" --sha HEAD
eq "DoD2 untouched unchanged" "$OUT" "CODEMAP: unchanged (no add/delete/rename)"
grep -qx SENTINEL "$R/CODEMAP.md" && pass "DoD2 sentinel kept" || fail "DoD2 sentinel kept"
eq "DoD2 untouched cksum" "$(cksum < "$R/CODEMAP.md")" "$pre"

# --- best-effort ---
N="$TMP/nogit"; mkdir -p "$N"; run "$N"; eq "DoD2 non-git exit 1" "$RC" 1
[ -e "$N/CODEMAP.md" ] && fail "DoD2 non-git writes nothing" || pass "DoD2 non-git writes nothing"
pre="$(cksum < "$R/CODEMAP.md")"; run "$R" --sha deadbeef; eq "DoD2 bad sha exit 1" "$RC" 1
eq "DoD2 bad sha leaves file" "$(cksum < "$R/CODEMAP.md")" "$pre"
run "$R" --bogus; eq "DoD2 unknown arg exit 3" "$RC" 3
run "$R" --sha ""; eq "DoD2 empty sha exit 3" "$RC" 3
R="$(newrepo r4)"; echo 1 > "$R/a"; echo tracked > "$R/CODEMAP.md"; git -C "$R" add -A; git -C "$R" commit -qm init; run "$R" --sha HEAD
eq "DoD2 tracked output" "$OUT" "CODEMAP: skipped (tracked)"; eq "DoD2 tracked exit 0" "$RC" 0
eq "DoD2 tracked clean status" "$(git -C "$R" status --porcelain)" ""

# --- empty tree / leftovers / non-regular target ---
R="$(newrepo r6)"; echo 1 > "$R/only"; cm "$R" init; git -C "$R" rm -q only; cm "$R" rmlast
ls "$TMP"/tmp.* >/dev/null 2>&1; before="$(ls -d "${TMPDIR:-/tmp}"/tmp.* 2>/dev/null | wc -l)"
run "$R" --sha HEAD; eq "empty tree exit 0" "$RC" 0; eq "empty tree refreshed" "$OUT" "CODEMAP: refreshed"
grep -qx 'Files: 0' "$R/CODEMAP.md" && pass "empty tree Files: 0" || fail "empty tree Files: 0"
R="$(newrepo r7)"; echo 1 > "$R/q"; cm "$R" init; run "$R"
eq "no leftover temp files" "$(ls -d "${TMPDIR:-/tmp}"/tmp.* 2>/dev/null | wc -l)" "$before"
rm -f "$R/CODEMAP.md"; mkdir "$R/CODEMAP.md"; run "$R"
eq "dir target exit 0" "$RC" 0; eq "dir target skipped" "$OUT" "CODEMAP: skipped (not a regular file)"
[ -z "$(ls -A "$R/CODEMAP.md")" ] && pass "dir target untouched" || fail "dir target untouched"

# --- runbook static ---
awk '/^## Step 4\.6/{f=1} /^## Step 5/{f=0} f' "$CT" > "$TMP/s46"
a="$(grep -n '^## Step 4\.5' "$CT" | cut -d: -f1 | head -n 1)"; b="$(grep -n '^## Step 4\.6' "$CT" | cut -d: -f1 | head -n 1)"; c="$(grep -n '^## Step 5' "$CT" | cut -d: -f1 | head -n 1)"
[ -n "$a" ] && [ -n "$b" ] && [ -n "$c" ] && [ "$a" -lt "$b" ] && [ "$b" -lt "$c" ] && pass "runbook Step 4.6 placement" || fail "runbook Step 4.6 placement"
grep -qF 'codemap_refresh.sh --sha "$COMMIT_SHA"' "$TMP/s46" && pass "runbook command" || fail "runbook command"
grep -qF '|| echo "WARN:' "$TMP/s46" && pass "runbook WARN" || fail "runbook WARN"
grep -qw none "$TMP/s46" && pass "runbook mentions none" || fail "runbook mentions none"
grep -q 'codemap_refresh.sh. failures are non-fatal' "$CT" && pass "runbook reminders" || fail "runbook reminders"
( cd "$KIT" && bash tests/test_no_inline_mutations.sh project-template/.claude/commands/close_task.md >/dev/null 2>&1 ) && pass "no inline mutations" || fail "no inline mutations"

# --- runbook executable ---
CMD="$(grep -F 'codemap_refresh.sh --sha' "$TMP/s46" | head -n 1)"
R="$(newrepo r5)"; echo 1 > "$R/a"; cm "$R" init
mkdir -p "$TMP/stub"; printf '#!/usr/bin/env bash\nexit 1\n' > "$TMP/stub/codemap_refresh.sh"; chmod +x "$TMP/stub/codemap_refresh.sh"
ln -s "$TMP/stub" "$R/.vault_link"; mkdir -p "$TMP/stub/.scripts"; mv "$TMP/stub/codemap_refresh.sh" "$TMP/stub/.scripts/"
OUTX="$(cd "$R" && COMMIT_SHA=abc bash -c "$CMD" 2>&1)"; RCX=$?
eq "executable: failing stub is non-fatal" "$RCX" 0
case "$OUTX" in *"WARN: codemap_refresh failed"*) pass "executable: WARN printed" ;; *) fail "executable: WARN printed" ;; esac
RED="${CMD%% || echo*}"; ( cd "$R" && COMMIT_SHA=abc bash -c "$RED" >/dev/null 2>&1 ); RCR=$?
[ "$RCR" -ne 0 ] && pass "executable RED: without || echo fails" || fail "executable RED: without || echo fails"

# --- DoD3 planner ---
grep -qF 'CODEMAP.md' "$PL" && pass "planner mentions CODEMAP.md" || fail "planner mentions CODEMAP.md"
CP="$(awk '/^### Context pack/{f=1} /^### Build split/{f=0} f' "$PL")"
printf '%s\n' "$CP" | grep -qF -- '- Read: CODEMAP.md' && pass "planner pack Read line" || fail "planner pack Read line"
printf '%s\n' "$CP" | grep -qw first && pass "planner pack says first" || fail "planner pack says first"

# --- DoD4 wiring ---
for f in test_chain_consolidation test_chain_targeted_tests test_spec_gate_hardening test_pm_reviewer_single_pass test_macro_start_timestamp test_hook_argument_scope test_kit_telemetry_isolation; do
  grep -qF '[ "$b" = test_codemap_refresh.sh ] && envp="CMR_SKIP_SUITES=1"' "$REPO_ROOT/tests/$f.sh" && pass "$f wires CMR_SKIP_SUITES" || fail "$f missing CMR_SKIP_SUITES wiring"
done

# --- DoD4 suites ---
if [ "${CMR_SKIP_SUITES:-0}" = 1 ]; then
  echo "suites skipped: CMR_SKIP_SUITES=1"
else
  if ( cd "$REPO_ROOT" && bash tests/test_chain_consolidation.sh >"$TMP/chain.out" 2>&1 ); then
    pass "full chain consolidation green"
  else
    fail "full chain consolidation failed"; grep '^FAIL' "$TMP/chain.out"
  fi
fi

if [ "$FAILS" -eq 0 ]; then echo "ALL GREEN"; exit 0; fi
echo "$FAILS check(s) failed"; exit 1

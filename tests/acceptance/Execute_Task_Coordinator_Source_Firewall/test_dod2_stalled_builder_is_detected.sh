#!/usr/bin/env bash
# DoD2: replay of the Grok incident at Step 10. The builder check block, taken verbatim from the
# runbook, runs in a project after a builder that stalled (nothing changed) and after builders that
# did their work, against a spec written the way the planner writes it ([NEW]/[EDIT]/[DELETE] tags,
# "— owns:" suffixes, a following ### heading, unrelated dirty files).
. "$(dirname "$0")/_lib.sh"
sandbox; project

section "$ET" '^## Step 10 ' > "$TMP/s10"
BC="$(fenced "$TMP/s10" '^BUILD_CHANGED=')"
[ -n "$BC" ] && pass "Step 10 builder check block found" || { fail "no BUILD_CHANGED block in Step 10"; done_; }

mkdir -p "$P/src" "$P/docs"
echo a > "$P/src/app.py"; echo b > "$P/src/legacy.py"; echo c > "$P/docs/notes.md"; echo d > "$P/README.md"
git -C "$P" add -A; git -C "$P" commit -qm init
T="$SB/02_Tasks/P/$TASK.md"
cat > "$T" <<'EOF'
## 📐 Spec
### Files touched
- [EDIT] `src/app.py`
- [NEW] `src/feature.py` — owns: the new feature; existing owner: none, verified against responsibility map
- [DELETE] `src/legacy.py`

### Risks
- touching `docs/notes.md` is out of scope
- [EDIT] `README.md`
EOF
BB="$(fenced "$TMP/s10" '^BB_FILE=')"
export TMPDIR="$TMP"
run_block "$BB" TASK_PATH="$T"
check() { run_block "$BC"'
printf %s "$BUILD_CHANGED"' TASK_PATH="$T"; }
reset() { git -C "$P" checkout -q -- .; git -C "$P" clean -fdq -e .vault_link; }

check; eq "clean tree after a stalled builder -> empty (builder failure)" "$OUT" ""
echo x >> "$P/README.md"; echo x >> "$P/docs/notes.md"; echo x > "$P/scratch.txt"
check; eq "only unlisted or Risks-listed files dirty -> still a builder failure" "$OUT" ""; reset
echo x >> "$P/src/app.py"; check
case "$OUT" in *src/app.py*|*app.py*) pass "[EDIT] file changed -> reported" ;; *) fail "[EDIT] change not reported (got '$OUT')" ;; esac; reset
echo x > "$P/src/feature.py"; check
case "$OUT" in *feature.py*) pass "[NEW] file with '— owns:' suffix created -> reported" ;; *) fail "[NEW] creation not reported (got '$OUT')" ;; esac; reset
rm "$P/src/legacy.py"; check
case "$OUT" in *legacy.py*) pass "[DELETE] file removed -> reported" ;; *) fail "[DELETE] removal not reported (got '$OUT')" ;; esac; reset

# The prose around the block names the outcome and routes it.
grep -qF 'Empty `$BUILD_CHANGED` is a builder failure' "$TMP/s10" && pass "empty result is declared a builder failure" || fail "empty-result rule missing"
grep -qF 'on a builder failure do not spawn the frontend builder' "$TMP/s10" && pass "split path stops before the frontend builder" || fail "split path does not stop on failure"
grep -qF 'run the builder check after both return' "$TMP/s10" && pass "parallel path runs the builder check" || fail "parallel path lacks builder check"
grep -qF 'Then run the builder check below.' "$TMP/s10" && pass "single path runs the builder check" || fail "single path lacks builder check"
done_

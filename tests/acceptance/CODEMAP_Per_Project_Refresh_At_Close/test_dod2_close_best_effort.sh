#!/usr/bin/env bash
# DoD2 failure paths: Step 4.6 never halts the close; a bad sha, missing or failing script only WARNs.
. "$(dirname "$0")/_lib.sh"
P="$(project p3)"; echo 1 > "$P/a"; commit "$P" init
(cd "$P" && .vault_link/.scripts/codemap_refresh.sh >/dev/null); pre="$(cksum < "$P/CODEMAP.md")"

close_step46 "$P" deadbeefdeadbeef
eq "unresolvable sha: close continues" "$RC" 0
case "$OUT" in *"WARN: codemap_refresh failed (non-fatal); close continues"*) pass "unresolvable sha: WARN" ;; *) fail "unresolvable sha: WARN ($OUT)" ;; esac
eq "unresolvable sha: map untouched" "$(cksum < "$P/CODEMAP.md")" "$pre"

# Project whose .vault_link has no codemap script (older vault).
Q="$TMP/p4"; mkdir -p "$Q/empty/.scripts"; git -C "$Q" init -q; git -C "$Q" config user.name t; git -C "$Q" config user.email t@t
echo 1 > "$Q/a"; git -C "$Q" add a; git -C "$Q" commit -qm i; ln -s "$Q/empty" "$Q/.vault_link"
close_step46 "$Q" "$(git -C "$Q" rev-parse HEAD)"
eq "missing script: close continues" "$RC" 0
case "$OUT" in *"WARN: codemap_refresh failed"*) pass "missing script: WARN" ;; *) fail "missing script: WARN" ;; esac

# Project that already tracks CODEMAP.md: skipped, worktree stays clean so a later Orchestrator commit is not blocked.
R="$(project p5)"; echo 1 > "$R/a"; echo mine > "$R/CODEMAP.md"; git -C "$R" add a CODEMAP.md; git -C "$R" commit -qm i
echo 2 > "$R/b"; git -C "$R" add b; git -C "$R" commit -qm add; close_step46 "$R" "$(git -C "$R" rev-parse HEAD)"
eq "tracked: skipped" "$OUT" "CODEMAP: skipped (tracked)"; eq "tracked: rc" "$RC" 0
eq "tracked: content kept" "$(cat "$R/CODEMAP.md")" "mine"; eq "tracked: clean" "$(git -C "$R" status --porcelain)" ""

# Runbook guards the COMMIT_SHA=none case and documents non-fatality.
S46="$(awk '/^## Step 4\.6/{f=1} /^## Step 5/{f=0} f' "$CT")"
printf '%s' "$S46" | grep -q '`COMMIT_SHA` is not `none`' && pass "runbook: skip when COMMIT_SHA=none" || fail "runbook: skip when COMMIT_SHA=none"
printf '%s' "$S46" | grep -qi 'never halts' && printf '%s' "$S46" | grep -qi 'never emits error telemetry' && pass "runbook: non-fatal prose" || fail "runbook: non-fatal prose"
printf '%s' "$S46" | grep -qi 'not committed' && pass "runbook: not committed" || fail "runbook: not committed"
grep -qF 'CODEMAP: <refreshed|unchanged|skipped|failed>' "$CT" && pass "runbook: Step 10 confirmation" || fail "runbook: Step 10 confirmation"
printf '%s' "$S46" | grep -qwE 'Edit|Write' && fail "runbook: no Edit/Write words in step" || pass "runbook: no Edit/Write words in step"
done_

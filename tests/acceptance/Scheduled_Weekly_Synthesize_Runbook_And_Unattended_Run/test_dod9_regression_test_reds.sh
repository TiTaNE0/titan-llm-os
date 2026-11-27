#!/usr/bin/env bash
# DoD 9: the task's own regression test fails when the runbook is missing, its UNATTENDED MODE section
# is missing, or an unattended run would write outside the allowed paths, and passes on the finished state.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
run_bt() { env "$@" bash "$BUILDER_TEST" >"$TMP/bt.out" 2>&1; echo $?; }

eq "GREEN: regression test passes on the finished state" "$(run_bt SYN_X=1)" "0"
grep -q 'ALL GREEN' "$TMP/bt.out" && pass "prints ALL GREEN" || fail "no ALL GREEN"

eq "RED: missing runbook" "$(run_bt SYN_RUNBOOK=$TMP/nonexistent.md)" "1"
sed 's/^## UNATTENDED MODE$/## SOMETHING ELSE/' "$RUNBOOK" > "$TMP/no_unatt.md"
eq "RED: UNATTENDED MODE heading missing" "$(run_bt SYN_RUNBOOK=$TMP/no_unatt.md)" "1"
sed 's/^### Step 7 - Output$/### Step 7 - Renamed/' "$RUNBOOK" > "$TMP/no_s7.md"
eq "RED: Step 7 - Output missing" "$(run_bt SYN_RUNBOOK=$TMP/no_s7.md)" "1"
grep -vF 'persona_check.sh Synthesizer' "$RUNBOOK" > "$TMP/no_pc.md"
eq "RED: persona gate line removed" "$(run_bt SYN_RUNBOOK=$TMP/no_pc.md)" "1"
grep -vF 'mv facts.jsonl.next facts.jsonl' "$RUNBOOK" > "$TMP/no_mv.md"
eq "RED: mv line removed" "$(run_bt SYN_RUNBOOK=$TMP/no_mv.md)" "1"
grep -v 'two facts with status `contradicted`' "$RUNBOOK" > "$TMP/no_con.md"
eq "RED: contradicted decay rule removed" "$(run_bt SYN_RUNBOOK=$TMP/no_con.md)" "1"
eq "RED: prompt missing" "$(run_bt SYN_PROMPT=$TMP/nonexistent.md)" "1"
grep -vF 'post-boot' "$PROMPT" > "$TMP/p_nopb.md"
eq "RED: prompt without the post-boot skip line" "$(run_bt SYN_PROMPT=$TMP/p_nopb.md)" "1"
awk '/Recovery is delete-only/ { print "If plan exits 3 with unresolved facts.jsonl.next, repair them and run Step 7 mv."; next } { print }' "$RUNBOOK" > "$TMP/rb_repair.md"
eq "RED: Step 2 repair wording" "$(run_bt SYN_RUNBOOK=$TMP/rb_repair.md)" "1"
grep -vF '(interactive): error <class> at <step>' "$RUNBOOK" > "$TMP/rb_noitpl.md"
eq "RED: interactive error template removed" "$(run_bt SYN_RUNBOOK=$TMP/rb_noitpl.md)" "1"
grep -vF 'surfacing lines appended' "$RUNBOOK" > "$TMP/rb_noe4.md"
eq "RED: scope-E4 surfacing sentence removed" "$(run_bt SYN_RUNBOOK=$TMP/rb_noe4.md)" "1"
sed 's/^Do not commit anything\.$//' "$PROMPT" > "$TMP/p.md"; : # prompt rule not pinned by builder test; informational only

# RED for a helper whose scope check is blinded: a stub helper that always says clean must fail the test.
# (Proves the test drives the helper, not a mock.)
stubdir="$TMP/stubvault"; mkdir -p "$stubdir"; cp -R "$VAULT/.scripts" "$stubdir/.scripts"
printf '#!/usr/bin/env bash\nif [ "$1" = scope ]; then echo "SCOPE: clean"; exit 0; fi\nexec bash "%s" "$@"\n' "$HELPER" > "$stubdir/.scripts/synthesize_run.sh"
# The builder test resolves REPO_ROOT from its own location, so run a copy placed in the stub vault.
mkdir -p "$stubdir/tests" "$stubdir/.scripts/runbooks"; cp "$BUILDER_TEST" "$stubdir/tests/"; cp "$RUNBOOK" "$PROMPT" "$stubdir/.scripts/runbooks/"
ln -s "$VAULT/03_Brain" "$stubdir/03_Brain" 2>/dev/null
cp "$VAULT/.gitignore" "$stubdir/.gitignore"
env SYN_TASK_FILE=/nonexistent bash "$stubdir/tests/test_synthesize_scheduled_run.sh" >"$TMP/stub.out" 2>&1; rc=$?
[ "$rc" -ne 0 ] && pass "RED: always-clean scope stub is detected by the regression test" || fail "blinded scope check not detected"
grep -q '^FAIL: RED system_agents: scope exits 4' "$TMP/stub.out" && pass "RED: the stub fails on the scope RED checks, not on an unrelated check" || fail "stub failed for another reason: $(grep '^FAIL' "$TMP/stub.out" | head -3)"

# report validation REDs against the real helper.
SB="$TMP/sb"; mk_sandbox "$SB"; write_w47 "$SB"; syn="$SB/03_Brain/Weekly_Synthesis"
rep() { ( cd "$SB" && ./.vault_link/.scripts/synthesize_run.sh report --week 2026-W47 --unattended ) >/dev/null 2>&1; echo $?; }
eq "report valid fixture exits 0" "$(rep)" "0"
cp "$syn/2026-W47.synthesis.json" "$TMP/good.json"
echo '{not json' > "$syn/2026-W47.synthesis.json"; eq "RED report: invalid JSON" "$(rep)" "3"
sed 's/"iso_week":"2026-W47"/"iso_week":"2026-W46"/' "$TMP/good.json" > "$syn/2026-W47.synthesis.json"; eq "RED report: iso_week mismatch" "$(rep)" "3"
sed 's/"facts":\["fact_A","fact_B"\]/"facts":["fact_A"]/' "$TMP/good.json" > "$syn/2026-W47.synthesis.json"; eq "RED report: one-element facts" "$(rep)" "3"
cp "$TMP/good.json" "$syn/2026-W47.synthesis.json"; echo 'not json' >> "$syn/facts.jsonl.next"; eq "RED report: non-JSON line in facts.jsonl.next" "$(rep)" "3"
sed -i.bak '$d' "$syn/facts.jsonl.next"; rm -f "$syn/facts.jsonl.next.bak"; : > "$syn/2026-W47.synthesis.md"; eq "RED report: empty md" "$(rep)" "3"

# Fix 3: report rejects status values outside the enums (E3), never drops them silently.
# Restore a valid fact store and md for the status fixtures.
cp "$syn/facts.jsonl" "$syn/facts.jsonl.next"; echo '{"id":"fact_2026-W47_001","claim":"c"}' >> "$syn/facts.jsonl.next"
printf '# Synthesis\n## Summary\nx\n' > "$syn/2026-W47.synthesis.md"
st_red() { sed "$2" "$TMP/good.json" > "$syn/2026-W47.synthesis.json"; eq "RED report: $1" "$(rep)" "3"; }
st_red "proposal status Pending" 's/"status":"pending"/"status":"Pending"/'
st_red "proposal status approved" 's/"status":"pending"/"status":"approved"/'
st_red "contradiction status Open" 's/"status":"open"/"status":"Open"/'
st_red "contradiction status closed" 's/"status":"resolved"/"status":"closed"/'
st_red "proposal status as a number" 's/"status":"pending"/"status":1/'
sed 's/"status":"promoted"/"status":"rejected"/' "$TMP/good.json" > "$syn/2026-W47.synthesis.json"
eq "GREEN report: rejected/resolved/missing statuses" "$(rep)" "0"
out="$(cd "$SB" && ./.vault_link/.scripts/synthesize_run.sh report --week 2026-W47 --unattended | head -1)"
echo "$out" | grep -qF 'contradictions=1 rule_proposals=2' && pass "summary counts match the fixture" || fail "summary counts: $out"
finish

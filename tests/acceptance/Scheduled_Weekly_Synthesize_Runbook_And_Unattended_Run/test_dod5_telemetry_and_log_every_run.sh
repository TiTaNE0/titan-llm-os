#!/usr/bin/env bash
# DoD 5: every run emits a synthesize telemetry record (success or error) and appends one daily-log line.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
tel() { cat "$1/04_Logs/Telemetry/"*.jsonl 2>/dev/null; }

# Success run.
SB="$TMP/ok"; mk_sandbox "$SB"; drive_unattended "$SB"
export TELEMETRY_DIR="$SB/04_Logs/Telemetry"
summary="$(sed -n 1p "$REPORT")"
( cd "$SB" && ./.vault_link/.scripts/append_log.sh --date 2026-11-30 --entry "$summary" --source-persona Synthesizer ) >/dev/null
( cd "$SB" && TITAN_SESSION_ID="$SID" ./.vault_link/.scripts/emit_telemetry.sh synthesize success auto null Synthesizer ) >/dev/null
unset TELEMETRY_DIR
rows="$(tel "$SB" | grep -c '"macro":"synthesize"')"; eq "exactly one synthesize row" "$rows" "1"
tel "$SB" | grep '"macro":"synthesize"' | grep -q '"status":"success"' && pass "row status success" || fail "row status"
tel "$SB" | grep '"macro":"synthesize"' | grep -q '"persona":"Synthesizer"' && pass "row persona Synthesizer" || fail "row persona"
tel "$SB" | grep '"macro":"synthesize"' | grep -Eq '"duration_ms":[0-9]+' && pass "duration derived from telemetry_start timer" || fail "duration_ms"
eq "exactly one summary line in daily log" "$(grep -c 'Synthesize 2026-W47 (unattended): success\.' "$SB/04_Logs/2026-11-30.md")" "1"

# Error run: facts.jsonl missing -> plan exit 1 (E1).
EB="$TMP/err"; mk_sandbox "$EB"; rm "$EB/03_Brain/Weekly_Synthesis/facts.jsonl"
export TELEMETRY_DIR="$EB/04_Logs/Telemetry"
( cd "$EB" && ./.vault_link/.scripts/telemetry_start.sh synthesize )
( cd "$EB" && ./.vault_link/.scripts/synthesize_run.sh plan --week 2026-W47 ) >/dev/null 2>&1; eq "plan exits 1 without facts.jsonl" "$?" "1"
[ ! -e "$EB/03_Brain/Weekly_Synthesis/facts.jsonl" ] && pass "helper never creates facts.jsonl" || fail "helper created facts.jsonl"
# Build the line from the runbook's own generic template.
tpl="$(grep -o 'Synthesize <W> (unattended): error <class> at <step>: <reason>\. Report: \[\[<report basename>\]\]\.' "$RUNBOOK" | head -1)"
[ -n "$tpl" ] && pass "runbook carries the generic error template" || fail "generic template missing"
line="$(echo "$tpl" | sed 's/<W>/2026-W47/; s/<class>/E1/; s/<step>/plan/; s/<reason>/facts.jsonl missing/; s/<report basename>/2026-11-30_E1_synthesize_2026-W47/')"
( cd "$EB" && ./.vault_link/.scripts/append_log.sh --date 2026-11-30 --entry "$line" --source-persona Synthesizer ) >/dev/null
( cd "$EB" && ./.vault_link/.scripts/emit_telemetry.sh synthesize error auto E1 Synthesizer ) >/dev/null
unset TELEMETRY_DIR
tel "$EB" | grep '"macro":"synthesize"' | grep -q '"status":"error"' && tel "$EB" | grep '"macro":"synthesize"' | grep -q '"error_class":"E1"' \
  && pass "error row with class E1" || fail "error row"
eq "one error summary line" "$(grep -c 'Synthesize 2026-W47 (unattended): error E1 at plan' "$EB/04_Logs/2026-11-30.md")" "1"
# Error-path rules in the runbook.
U="$TMP/u.md"; section "$RUNBOOK" '## UNATTENDED MODE' > "$U"
has "$U" 'Every error path writes one report to `04_Logs/Errors/' "error report location"
has "$U" 'Nothing is retried except E2' "retry rule"
has "$RUNBOOK" 'Every run, success or error, appends exactly one summary line and emits one `synthesize` record.' "runbook pins one line + one record"
has "$U" 'Both emit success.' "skips emit success"

# Fix 7: interactive Step 9 templates.
S9="$TMP/s9.md"; awk '/^### Step 9 - /{on=1;next} /^(###|##) /{on=0} on' "$RUNBOOK" > "$S9"
has "$S9" '(interactive): error <class> at <step>' "Step 9 has the interactive error template"
has "$S9" '(interactive): skipped, already synthesized' "Step 9 has the interactive already-synthesized line"
has "$S9" '(interactive): skipped, no logs in <monday>..<sunday>' "Step 9 has the interactive no-logs line"
has "$S9" 'appends exactly one summary line' "Step 9 states one summary line per run, any mode"
# Fix 8: Step 2 routes exits 6, 1 and 3 through Step 9.
S2="$TMP/s2.md"; awk '/^### Step 2 - /{on=1;next} /^(###|##) /{on=0} on' "$RUNBOOK" > "$S2"
for k in 6 1 3; do
  ln="$(grep -m1 "^- Exit $k:" "$S2")"
  echo "$ln" | grep -qF 'go to Step 9' && pass "Step 2 '- Exit $k:' goes to Step 9" || fail "Step 2 '- Exit $k:' lacks 'go to Step 9'"
done
grep -m1 '^- Exit 6:' "$S2" | grep -qF 'skipped, already synthesized' && pass "Exit 6 line names the skipped line" || fail "Exit 6 line"
grep -m1 '^- Exit 1:' "$S2" | grep -qF 'step plan' && grep -m1 '^- Exit 3:' "$S2" | grep -qF 'step plan' && pass "Exit 1 and Exit 3 lines name step plan" || fail "Exit 1/3 step plan"
sed 's/^\(- Exit 3:.*\)go to Step 9/\1go on/' "$RUNBOOK" > "$TMP/rb_red.md"
awk '/^### Step 2 - /{on=1;next} /^(###|##) /{on=0} on' "$TMP/rb_red.md" | grep -m1 '^- Exit 3:' | grep -qF 'go to Step 9' && fail "RED copy still routes Exit 3" || pass "RED: Exit 3 line without 'go to Step 9' is detected"
# Driven: every plan exit, both modes, one summary line and one telemetry row, no synthesis output touched.
U5="$TMP/u5.md"; section "$RUNBOOK" '## UNATTENDED MODE' > "$U5"
for mode in interactive unattended; do
  if [ "$mode" = interactive ]; then blk="$S9"; else blk="$U5"; fi
  etpl="$(grep -oF "Synthesize <W> ($mode): error <class> at <step>: <reason>. Report: [[<report basename>]]." "$blk" | head -1)"
  stpl="$(grep -oF "Synthesize <W> ($mode): skipped, already synthesized." "$blk" | head -1)"
  [ -n "$etpl" ] && [ -n "$stpl" ] && pass "$mode: both templates extracted from the runbook" || { fail "$mode: runbook lacks a template"; continue; }
  for kind in skip e1 e3; do
    D="$TMP/pe_${mode}_$kind"; mk_sandbox "$D"; w="$D/03_Brain/Weekly_Synthesis"
    case "$kind" in
      skip) write_w47 "$D"; rm -f "$w/facts.jsonl.next"; wrc=6; st=success; cls=null; tpl="$stpl" ;;
      e1)   rm -f "$w/facts.jsonl"; wrc=1; st=error; cls=E1; tpl="$etpl" ;;
      e3)   echo '# partial' > "$w/2026-W47.synthesis.md"; wrc=3; st=error; cls=E3; tpl="$etpl" ;;
    esac
    before="$(ls "$w" | grep 'synthesis\.' | tr '\n' ' ')$(cat "$w"/2026-W47.synthesis.* 2>/dev/null | shasum | cut -d' ' -f1)"
    export TELEMETRY_DIR="$D/04_Logs/Telemetry"
    ( cd "$D" && ./.vault_link/.scripts/telemetry_start.sh synthesize )
    syn "$D" plan --week 2026-W47 >/dev/null 2>&1; eq "$mode/$kind: plan exits $wrc" "$?" "$wrc"
    line="${tpl//<W>/2026-W47}"; line="${line//<class>/$cls}"; line="${line//<step>/plan}"; line="${line//<reason>/plan exit $wrc}"; line="${line//<report basename>/2026-11-30_${cls}_synthesize_2026-W47}"
    ( cd "$D" && ./.vault_link/.scripts/append_log.sh --date 2026-11-30 --entry "$line" --source-persona Synthesizer ) >/dev/null
    ( cd "$D" && ./.vault_link/.scripts/emit_telemetry.sh synthesize "$st" auto "$cls" Synthesizer ) >/dev/null
    unset TELEMETRY_DIR
    L="$D/04_Logs/2026-11-30.md"
    eq "$mode/$kind: exactly one summary line" "$(grep -c "^Synthesize 2026-W47 ($mode):" "$L")" "1"
    if [ "$kind" = skip ]; then grep -q "^Synthesize 2026-W47 ($mode): skipped, already synthesized\.\$" "$L" && pass "$mode/skip: reads skipped, already synthesized." || fail "$mode/skip: line text"
    else grep "^Synthesize 2026-W47 ($mode):" "$L" | grep -qF "error $cls at plan" && pass "$mode/$kind: carries error $cls at plan" || fail "$mode/$kind: line text"; fi
    t="$(cat "$D/04_Logs/Telemetry/"*.jsonl | grep '"macro":"synthesize"')"
    eq "$mode/$kind: one synthesize row" "$(echo "$t" | wc -l | tr -d ' ')" "1"
    echo "$t" | grep -q "\"status\":\"$st\"" && pass "$mode/$kind: row status $st" || fail "$mode/$kind: row status"
    [ "$cls" = null ] || { echo "$t" | grep -q "\"error_class\":\"$cls\"" && pass "$mode/$kind: row class $cls" || fail "$mode/$kind: row class"; }
    after="$(ls "$w" | grep 'synthesis\.' | tr '\n' ' ')$(cat "$w"/2026-W47.synthesis.* 2>/dev/null | shasum | cut -d' ' -f1)"
    eq "$mode/$kind: no synthesis output created or changed" "$after" "$before"
  done
done
finish

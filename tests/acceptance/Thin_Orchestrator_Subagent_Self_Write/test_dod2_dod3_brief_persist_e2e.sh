#!/usr/bin/env bash
# DoD 2 + 3 end to end: take the persist template exactly as execute_task.md briefs it
# (Steps 6, 12), fill it the way a subagent would, pass it through the PreToolUse hook,
# execute it from a mktemp vault root, and confirm the coordinator's grep_section.sh
# presence check sees the section populated.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
[ -f "$EXEC_MD" ] || { fail "execute_task.md missing: $EXEC_MD"; finish; }

# template <step> <section>: the 3-line fenced persist command inside that step.
template() {
  awk -v s="## Step $1 " -v sec="--section $2 " '
    index($0, s) == 1 { on = 1; next }
    on && /^## Step / { exit }
    on && index($0, "write_task_section.sh --task-path") && index($0, sec) { grab = 3 }
    grab > 0 { sub(/^[[:space:]]+/, ""); print; grab-- }' "$EXEC_MD"
}
# fill <template> <task path> <overwrite 0|1> <body>: what a subagent substitutes.
fill() {
  local t="$1" p="$2" ow="$3" body="$4" l1 rest delim
  l1="${t%%$'\n'*}"; rest="${t#*$'\n'}"; delim="${rest#*$'\n'}"
  l1="${l1//<TASK_PATH>/$p}"
  if [ "$ow" = 1 ]; then l1="${l1// \[--overwrite\]/ --overwrite}"; else l1="${l1// \[--overwrite\]/}"; fi
  printf '%s\n%s\n%s' "$l1" "$body" "$delim"
}

REL=".vault_link/02_Tasks/P/T.md"
V="$TMP/v"; mk_vault "$V"; unset TITAN_SESSION_ID

check_step() { # <step> <section> <heading> <delim>
  local step="$1" sec="$2" hd="$3" dl="$4" t cmd body rc
  t="$(template "$step" "$sec")"
  [ "$(printf '%s\n' "$t" | wc -l | tr -d ' ')" = 3 ] || { fail "Step $step: persist template not found"; return; }
  [ "$(printf '%s\n' "$t" | tail -1)" = "$dl" ] && pass "Step $step template uses delimiter $dl" || fail "Step $step delimiter"
  printf '%s' "$t" | grep -qF -- '--content-file -' && pass "Step $step uses --content-file -" || fail "Step $step no stdin mode"

  # The unfilled template must not be runnable (forces literal substitution).
  [ "$(hook_rc "$t")" = 2 ] && pass "Step $step unfilled template refused" || fail "Step $step raw template allowed"
  [ "$(hook_rc "$(fill "$t" '$TASK_PATH' 0 x)")" = 2 ] && pass "Step $step \$TASK_PATH variable refused" || fail "Step $step variable allowed"

  body="### $hd report
- uses \$(id) and \`backticks\` and ; rm -rf / -- all inert
| table | row |"
  cmd="$(fill "$t" "$REL" 0 "$body")"
  rc="$(hook_rc "$cmd")"
  [ "$rc" = 0 ] && pass "Step $step filled command passes hook" || { fail "Step $step hook rc=$rc: $(cat "$TMP/hook_err")"; return; }
  rc="$(cd "$V" && bash -c "$cmd" >/dev/null 2>"$TMP/run_err"; echo $?)"
  [ "$rc" = 0 ] && pass "Step $step command exits 0" || { fail "Step $step run rc=$rc: $(cat "$TMP/run_err")"; return; }
  section_body "$V/02_Tasks/P/T.md" "$sec" | grep -qF -- '- uses $(id) and `backticks` and ; rm -rf / -- all inert' \
    && pass "Step $step content landed verbatim" || fail "Step $step content missing"
  rc="$(cd "$V" && .vault_link/.scripts/grep_section.sh "$REL" "$hd" empty >/dev/null 2>&1; echo $?)"
  [ "$rc" = 1 ] && pass "Step $step coordinator presence check sees populated (exit 1)" || fail "Step $step grep_section rc=$rc"

  # Re-run without --overwrite is refused by the script (E3); with --overwrite it replaces.
  rc="$(cd "$V" && bash -c "$(fill "$t" "$REL" 0 again)" >/dev/null 2>&1; echo $?)"
  [ "$rc" = 3 ] && pass "Step $step repeat w/o --overwrite -> E3" || fail "Step $step repeat rc=$rc"
  cmd="$(fill "$t" "$REL" 1 "replaced $sec")"
  [ "$(hook_rc "$cmd")" = 0 ] && pass "Step $step --overwrite variant passes hook" || fail "Step $step overwrite refused by hook"
  rc="$(cd "$V" && bash -c "$cmd" >/dev/null 2>&1; echo $?)"
  [ "$rc" = 0 ] && section_body "$V/02_Tasks/P/T.md" "$sec" | grep -q "^replaced $sec$" \
    && pass "Step $step --overwrite replaced" || fail "Step $step overwrite rc=$rc"
}

# grep_section headings are the plain names used by the coordinator's presence checks.
check_step 6  spec             "Spec"             SPEC_EOF
check_step 12 validator_report "Validator Report" REPORT_EOF

# Failure path: a subagent whose write is refused leaves the section empty, so the
# coordinator presence check (exit 0 = empty) triggers the E3/queue_attention branch.
V2="$TMP/v2"; mk_vault "$V2"
[ "$(hook_rc "rm -rf /tmp/x")" = 2 ] || fail "precondition: hook refuses rm"
rc="$(cd "$V2" && .vault_link/.scripts/grep_section.sh "$REL" "Research Notes" empty >/dev/null 2>&1; echo $?)"
[ "$rc" = 0 ] && pass "unpersisted section detected as empty (exit 0)" || fail "unpersisted grep_section rc=$rc"
sed -i '' '/write_task_section section=spec/d; /^## 📐 Spec/d' "$V2/02_Tasks/P/T.md"
rc="$(cd "$V2" && .vault_link/.scripts/grep_section.sh "$REL" "Spec" empty >/dev/null 2>&1; echo $?)"
[ "$rc" = 3 ] && pass "missing section detected (exit 3)" || fail "missing section rc=$rc"

# DoD 3: coordinator flow -- no report heredoc, presence checks + escalation per step.
R="$(awk '/^## Step 6/{on=1} /^## Step 13/{exit} on' "$EXEC_MD")"
step() { awk -v s="## Step $1 " 'index($0,s)==1{on=1;next} on&&/^## Step /{exit} on' "$EXEC_MD"; }
for bad in CONTENT_FILE RESEARCH_EOF '<full subagent report content>' 'Capture spec' 'Capture report' 'cat >' 'mktemp'; do
  printf '%s' "$R" | grep -qF -- "$bad" && fail "Steps 6-12 still contain '$bad'" || pass "Steps 6-12 free of '$bad'"
done
step 6  | grep -qF 'grep_section.sh "$TASK_PATH" "Spec" empty' && step 6 | grep -qF -- '--state spec_gate' && step 6 | grep -qF 'spec section missing' \
  && pass "Step 6 pre-spawn Spec check + queue_attention" || fail "Step 6 escalation"
step 7  | grep -qF 'grep_section.sh "$TASK_PATH" "Spec" empty' && step 7 | grep -qF -- '--state spec_gate' && step 7 | grep -qF 'spec not persisted' && step 7 | grep -qF 'E3: planner did not persist' \
  && pass "Step 7 presence check + E3 + queue_attention" || fail "Step 7 escalation"
step 12 | grep -qF 'grep_section.sh "$TASK_PATH" "Validator Report" empty' && step 12 | grep -qF -- '--state close_gate' && step 12 | grep -qF 'E3: validator did not persist' \
  && pass "Step 12 presence check + E3 + queue_attention" || fail "Step 12 escalation"
step 11 | grep -qF 'run_result: PASS' && step 11 | grep -qF 'Do not persist anything into the vault' \
  && pass "Step 11 test-verifier status-only" || fail "Step 11 contract"
step 8 | grep -qF 'do not re-print it' && pass "Step 8 does not re-emit spec" || fail "Step 8 re-emits spec"
finish

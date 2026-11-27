#!/usr/bin/env bash
# test_synthesize_scheduled_run.sh - regression test for the scheduled weekly /synthesize.
# Covers: runbook presence and per-step content, the UNATTENDED MODE section, the pointer
# prompt, the synthesize_run.sh helper, and the unattended write scope (driven in mktemp
# sandboxes only). Never invokes claude, never touches ~/.claude/scheduled-tasks/, never
# writes the live vault. No skip env: it runs no other suite.
set -uo pipefail
unset TITAN_SESSION_ID TELEMETRY_DIR

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
RUNBOOK="${SYN_RUNBOOK:-$REPO_ROOT/.scripts/runbooks/synthesize.md}"
PROMPT="${SYN_PROMPT:-$REPO_ROOT/.scripts/runbooks/synthesize_scheduled_task_prompt.md}"
TASK_FILE="${SYN_TASK_FILE:-$REPO_ROOT/02_Tasks/TiTan_LLM_OS/Scheduled weekly synthesize - runbook and unattended run.md}"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/synth_sched.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
FAILS=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAILS=$((FAILS + 1)); }
eq() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (got '$2', want '$3')"; fi; }
chk_yes() { local d="$1"; shift; if "$@"; then pass "$d"; else fail "$d${CHK_WHY:+ ($CHK_WHY)}"; fi; }
chk_no() { local d="$1"; shift; if "$@"; then fail "$d (unexpectedly passed)"; else pass "$d"; fi; }
sha() { if command -v shasum >/dev/null 2>&1; then shasum -a 256; else sha256sum; fi | cut -d' ' -f1; }

CHK_WHY=""
why() { CHK_WHY="$1"; return 1; }

# --- Checkers -----------------------------------------------------------------
STEP_NAMES=("Persona Gate" "Inputs" "Read" "Extract" "Reconcile" "Decay" "Output" "HALT" "Telemetry")

step_block() { # file n -> body lines of "### Step n - <name>" up to the next step or ## heading
  awk -v h="### Step $2 - ${STEP_NAMES[$(($2 - 1))]}" '
    index($0, h) == 1 { p = 1; next }
    p && (/^### Step / || /^## /) { exit }
    p { print }' "$1"
}

step_literals() {
  case "$1" in
    1) printf '%s\n' 'persona_check.sh Synthesizer' ;;
    2) printf '%s\n' 'synthesize_run.sh plan' 'Recovery is delete-only' 'delete `facts.jsonl.next`' 'rerun `/synthesize <W>` interactively' ;;
    3) printf '%s\n' 'log=' ;;
    4) printf '%s\n' 'Memory_Schema' ;;
    5) printf '%s\n' 'facts.jsonl' 'contradicted' ;;
    6) printf '%s\n' 'archive/' '0.2' '90' 'rule_proposals' 'contradicted' ;;
    7) printf '%s\n' 'synthesis.md' 'synthesis.json' 'facts.jsonl.next' 'synthesize_run.sh report' 'mv facts.jsonl.next facts.jsonl' ;;
    8) printf '%s\n' 'pending' 'contradiction' ;;
    9) printf '%s\n' 'append_log.sh' 'emit_telemetry.sh synthesize' '(interactive): error <class> at <step>' '(interactive): skipped, already synthesized' 'scope' 'surfacing lines appended' ;;
  esac
}

has_all() { # text literals... (literals newline-separated in $2)
  local text="$1" lit
  while IFS= read -r lit; do
    printf '%s\n' "$text" | grep -qF -- "$lit" || { CHK_WHY="missing '$lit'"; return 1; }
  done <<EOF
$2
EOF
  return 0
}

# Step 2 exit bullets: each exit routes to Step 9; no repair branch (delete-only recovery).
check_step2_exits() { # block
  local b="$1" k want line
  if printf '%s\n' "$b" | grep -qi 'repair'; then CHK_WHY="Step 2 mentions repair"; return 1; fi
  for k in 6 1 3; do
    line="$(printf '%s\n' "$b" | grep -m1 "^- Exit $k:")"
    [ -n "$line" ] || { CHK_WHY="Step 2 lacks '- Exit $k:' line"; return 1; }
    printf '%s\n' "$line" | grep -qF 'go to Step 9' || { CHK_WHY="Step 2 '- Exit $k:' lacks 'go to Step 9'"; return 1; }
    case "$k" in
      6) want='skipped, already synthesized' ;;
      *) want='step plan' ;;
    esac
    printf '%s\n' "$line" | grep -qF "$want" || { CHK_WHY="Step 2 '- Exit $k:' lacks '$want'"; return 1; }
  done
  return 0
}

check_runbook() {
  local f="$1" i prev=0 ln block
  CHK_WHY=""
  [ -f "$f" ] || why "runbook missing: $f" || return 1
  grep -q '^description: ' "$f" || why "no description: frontmatter" || return 1
  for i in 1 2 3 4 5 6 7 8 9; do
    ln="$(grep -nxF -- "### Step $i - ${STEP_NAMES[$((i - 1))]}" "$f" | head -1 | cut -d: -f1)"
    [ -n "$ln" ] || why "heading 'Step $i - ${STEP_NAMES[$((i - 1))]}' missing" || return 1
    [ "$ln" -gt "$prev" ] || why "Step $i heading out of order" || return 1
    prev="$ln"
    block="$(step_block "$f" "$i")"
    has_all "$block" "$(step_literals "$i")" || { CHK_WHY="Step $i: $CHK_WHY"; return 1; }
    if [ "$i" = 2 ]; then check_step2_exits "$block" || return 1; fi
  done
  return 0
}

unattended_block() { awk '/^## UNATTENDED MODE$/ { p = 1; next } p && /^## / { exit } p { print }' "$1"; }

check_unattended() {
  local f="$1" block lit order wk ss
  CHK_WHY=""
  [ -f "$f" ] || why "runbook missing" || return 1
  grep -qx '## UNATTENDED MODE' "$f" || why "UNATTENDED MODE heading missing" || return 1
  block="$(unattended_block "$f")"
  for lit in 'session_state_write.sh' '--persona Synthesizer' '--no-legacy-mirror' 'TITAN_SESSION_ID=' \
             'synthesize_run.sh week' 'synthesize_run.sh scope' 'append_log.sh' 'emit_telemetry.sh synthesize' \
             'E1' 'E2' 'E3' 'E4' 'E5' 'week-unknown' 'error <class> at <step>' 'Final message' 'surfacing lines appended'; do
    printf '%s\n' "$block" | grep -qF -- "$lit" || why "UNATTENDED MODE lacks '$lit'" || return 1
  done
  order="$(printf '%s\n' "$block" | awk '/^- Order:/ { p = 1; n = 0 } p && n > 0 && /^- / { exit } p { print; n++ }')"
  wk="$(printf '%s\n' "$order" | grep -nF 'synthesize_run.sh week' | head -1 | cut -d: -f1)"
  ss="$(printf '%s\n' "$order" | grep -nF 'session_state_write.sh' | head -1 | cut -d: -f1)"
  [ -n "$wk" ] && [ -n "$ss" ] || why "Order bullet lacks week or handshake line" || return 1
  [ "$wk" -lt "$ss" ] || why "week is not before the handshake in the Order bullet" || return 1
  return 0
}

check_prompt() {
  local f="$1" body n
  CHK_WHY=""
  [ -f "$f" ] || why "prompt missing" || return 1
  grep -qx 'name: weekly-synthesize' "$f" || why "no 'name: weekly-synthesize'" || return 1
  grep -q '^description: ' "$f" || why "no description" || return 1
  body="$(awk 'c >= 2 { print } /^---$/ { c++ }' "$f")"
  n="$(printf '%s\n' "$body" | grep -c '[^[:space:]]')"
  [ "$n" -le 12 ] || why "body has $n non-blank lines (max 12)" || return 1
  printf '%s\n' "$body" | grep -qF '.scripts/runbooks/synthesize.md' || why "no runbook pointer" || return 1
  printf '%s\n' "$body" | grep -qF 'UNATTENDED MODE' || why "no UNATTENDED MODE pointer" || return 1
  printf '%s\n' "$body" | grep -qF 'Monday 09:00' || why "no Monday 09:00" || return 1
  printf '%s\n' "$body" | grep -qF 'post-boot' || why "no post-boot handshake skip line" || return 1
  if grep -qF 'claude -p' "$f"; then why "prompt contains claude -p"; return 1; fi
  return 0
}

# Step 7 write order: the facts.jsonl.next bullet must precede the .synthesis.json and .synthesis.md bullets.
check_step7_order() { # file
  local b nx js md
  CHK_WHY=""
  [ -f "$1" ] || why "runbook missing" || return 1
  b="$(step_block "$1" 7)"
  nx="$(printf '%s\n' "$b" | grep -n '^- `facts.jsonl.next`' | head -1 | cut -d: -f1)"
  js="$(printf '%s\n' "$b" | grep -n '^- `<W>.synthesis.json`' | head -1 | cut -d: -f1)"
  md="$(printf '%s\n' "$b" | grep -n '^- `<W>.synthesis.md`' | head -1 | cut -d: -f1)"
  [ -n "$nx" ] && [ -n "$js" ] && [ -n "$md" ] || why "Step 7 lacks a facts.jsonl.next, .synthesis.json or .synthesis.md bullet" || return 1
  [ "$nx" -lt "$js" ] || why "facts.jsonl.next bullet is not before .synthesis.json" || return 1
  [ "$nx" -lt "$md" ] || why "facts.jsonl.next bullet is not before .synthesis.md" || return 1
  return 0
}

# Copy of the runbook with every line holding $4 deleted inside Step $3.
drop_in_step() { # src dst n literal
  awk -v h="### Step $3 - ${STEP_NAMES[$(($3 - 1))]}" -v lit="$4" '
    index($0, h) == 1 { p = 1; print; next }
    p && (/^### Step / || /^## /) { p = 0 }
    p && index($0, lit) { next }
    { print }' "$1" > "$2"
}

# --- Sandbox -------------------------------------------------------------------
SB=""
SID="synth-20261123T070000Z"
FIXDATE="2026-11-23"
sbrun() { TELEMETRY_DIR="$SB/04_Logs/Telemetry" "$@"; }
sbx() { sbrun bash "$SB/.scripts/$1" "${@:2}"; }

make_sandbox() {
  SB="$1"
  mkdir -p "$SB/.scripts" "$SB/04_Logs" "$SB/03_Brain/Weekly_Synthesis" "$SB/01_Projects" "$SB/02_Tasks/P"
  local s d
  for s in synthesize_run session_state_write persona_check append_log emit_telemetry telemetry_start; do
    cp "$REPO_ROOT/.scripts/$s.sh" "$SB/.scripts/"
  done
  for d in 2026-11-15 2026-11-16 2026-11-22 2026-11-23; do printf 'log %s\n' "$d" > "$SB/04_Logs/$d.md"; done
  printf '{"x":1}\n' > "$SB/04_Logs/2026-11-18_extra.json"
  printf '%s\n' \
    '{"id":"fact_2026-W46_001","claim":"first claim","citations":1,"confidence":0.5,"status":"active"}' \
    '{"id":"fact_2026-W46_002","claim":"second claim","citations":1,"confidence":0.5,"status":"active"}' \
    > "$SB/03_Brain/Weekly_Synthesis/facts.jsonl"
  printf 'rules\n' > "$SB/03_Brain/System_Agents.md"
  printf 'passport\n' > "$SB/01_Projects/P.md"
  printf 'task\n' > "$SB/02_Tasks/P/T.md"
  printf 'board\n' > "$SB/P_Board.md"
  printf 'queue\n' > "$SB/Needs_Attention.md"
  (cd "$SB" && git init -q && git add -A \
    && git -c user.name=t -c user.email=t@example.com -c commit.gpgsign=false -c core.hooksPath=/dev/null commit -q -m init)
}

handshake() { sbx session_state_write.sh --persona Synthesizer --session-id "$SID" --started-at 2026-11-23T07:00:00Z --no-legacy-mirror; }

# Stands in for the model's Step 7 output. mode: full | empty
write_w47() {
  local mode="$1" w="$SB/03_Brain/Weekly_Synthesis"
  if [ "$mode" = full ]; then
    cat > "$w/2026-W47.synthesis.json" <<'EOF'
{"iso_week":"2026-W47","dates":"2026-11-16 to 2026-11-22","synthesized_at":"2026-11-23","persona":"Synthesizer",
 "logs_read":["04_Logs/2026-11-16.md","04_Logs/2026-11-22.md"],
 "facts_added":["fact_2026-W47_001","fact_2026-W47_002"],
 "contradictions":[
  {"facts":["fact_2026-W46_001","fact_2026-W47_002"],"summary":"two   claims\ndisagree","status":"open"},
  {"facts":["fact_2026-W46_002","fact_2026-W47_001"],"summary":"old one","status":"resolved"}],
 "rule_proposals":[
  {"id":"proposal_2026-W47_001","source_fact":"fact_2026-W46_001","proposed_rule":"Always do   X\nbefore Y.","rationale":"r","confidence":0.9,"target_file":"03_Brain/System_Agents.md"},
  {"id":"proposal_2026-W47_002","source_fact":"fact_2026-W46_002","proposed_rule":"Never do Z.","rationale":"r","confidence":0.85,"target_file":"03_Brain/Agent_Roles.md","status":"pending"},
  {"id":"proposal_2026-W47_003","source_fact":"fact_2026-W46_002","proposed_rule":"Done already.","rationale":"r","confidence":0.9,"target_file":"03_Brain/Agent_Roles.md","status":"promoted"}]}
EOF
  else
    cat > "$w/2026-W47.synthesis.json" <<'EOF'
{"iso_week":"2026-W47","dates":"2026-11-16 to 2026-11-22","synthesized_at":"2026-11-23","persona":"Synthesizer",
 "logs_read":["04_Logs/2026-11-16.md"],"facts_added":[],"contradictions":[],"rule_proposals":[]}
EOF
  fi
  printf '# Weekly Synthesis: 2026-W47\n\n## Summary\nfixture\n' > "$w/2026-W47.synthesis.md"
  cp "$w/facts.jsonl" "$w/facts.jsonl.next"
  printf '%s\n' '{"id":"fact_2026-W47_001","claim":"new claim","citations":1,"confidence":0.5,"status":"active"}' >> "$w/facts.jsonl.next"
}

manifest() {
  (cd "$1" && find . -path ./.git -prune -o -type f -print | LC_ALL=C sort | while IFS= read -r f; do
    printf '%s  %s\n' "$(sha < "$f")" "$f"
  done)
}

changed_paths() { diff "$1" "$2" | grep '^[<>]' | sed 's/^[<>] [0-9a-f]*  //' | LC_ALL=C sort -u; }

# Live-isolation snapshots.
LIVE_TEL="$REPO_ROOT/04_Logs/Telemetry/$(date -u +%Y-%m).jsonl"
LIVE_LOG="$REPO_ROOT/04_Logs/$(TZ=Asia/Jerusalem date +%Y-%m-%d).md"
[ -f "$LIVE_TEL" ] && cp "$LIVE_TEL" "$TMP/live_tel.before"
if [ -f "$LIVE_LOG" ]; then cp "$LIVE_LOG" "$TMP/live_log.before"; else : > "$TMP/live_log.before"; fi

# live_log_ok <snapshot> <current>: only the bytes appended after the snapshot may differ, and they
# must not hold a synthesis line. Sets LIVE_MSG.
live_log_ok() {
  local snap="$1" cur="$2" size added
  [ -f "$cur" ] || cur=/dev/null
  if cmp -s "$snap" "$cur"; then LIVE_MSG="live daily log identical"; return 0; fi
  size="$(wc -c < "$snap" | tr -d ' ')"
  if [ "$size" -gt 0 ] && ! head -c "$size" "$cur" | cmp -s - "$snap"; then LIVE_MSG="live daily log rewritten"; return 1; fi
  added="$(tail -c +$((size + 1)) "$cur")"
  if printf '%s\n' "$added" | grep -q '^Synthes'; then LIVE_MSG="live daily log gained a synthesis line"; return 1; fi
  LIVE_MSG="live daily log only gained other sessions' lines"; return 0
}

echo "== DoD 1: runbook mirrors the kernel step for step"
chk_yes "runbook passes check_runbook" check_runbook "$RUNBOOK"
chk_no "RED: missing runbook path fails check_runbook" check_runbook "$TMP/nope.md"
if [ -d "$REPO_ROOT/.claude/commands" ]; then
  if [ -L "$REPO_ROOT/.claude/commands/synthesize.md" ] && cmp -s "$REPO_ROOT/.claude/commands/synthesize.md" "$RUNBOOK"; then
    pass ".claude/commands/synthesize.md resolves to the runbook"
  else
    fail ".claude/commands/synthesize.md is not a symlink to the runbook"
  fi
else
  echo "SKIP: .claude/commands/ absent (per-machine, gitignored); symlink check not applicable"
fi

echo "== DoD 2/3: UNATTENDED MODE section"
chk_yes "UNATTENDED MODE passes check_unattended" check_unattended "$RUNBOOK"
UB="$(unattended_block "$RUNBOOK")"
for lit in 'Never run `/graduate`.' 'Do not commit anything.' 'Never ask questions.' 'Never start headless `claude -p`.' \
           'An unattended run writes only inside `03_Brain/Weekly_Synthesis/` and `04_Logs/`' \
           'No backfill: an unattended run never processes any week other than the one `synthesize_run.sh week` prints, and never loops over missing weeks.'; do
  if printf '%s\n' "$UB" | grep -qF -- "$lit"; then pass "UNATTENDED MODE pins: $lit"; else fail "UNATTENDED MODE lacks: $lit"; fi
done
sed 's/^## UNATTENDED MODE$/## UNATTENDED RUN/' "$RUNBOOK" > "$TMP/red_unatt.md"
chk_no "RED: renamed UNATTENDED MODE heading fails check_unattended" check_unattended "$TMP/red_unatt.md"

echo "== DoD 9: runbook RED copies"
grep -vxF '### Step 7 - Output' "$RUNBOOK" > "$TMP/red_s7.md"
chk_no "RED: Step 7 heading removed fails check_runbook" check_runbook "$TMP/red_s7.md"
drop_in_step "$RUNBOOK" "$TMP/red_s1.md" 1 'persona_check.sh Synthesizer'
chk_no "RED: persona_check line deleted from Step 1 fails" check_runbook "$TMP/red_s1.md"
drop_in_step "$RUNBOOK" "$TMP/red_mv.md" 7 'mv facts.jsonl.next facts.jsonl'
chk_no "RED: mv line deleted from Step 7 fails" check_runbook "$TMP/red_mv.md"
drop_in_step "$RUNBOOK" "$TMP/red_s6.md" 6 'contradicted'
chk_no "RED: contradicted rule line deleted from Step 6 fails" check_runbook "$TMP/red_s6.md"
# Fix 1 / 8 / 7 / 9 REDs on the runbook text.
awk '/Recovery is delete-only/ { print "If plan exits 3 with unresolved facts.jsonl.next, repair them and run Step 7'"'"'s `mv`."; next } { print }' "$RUNBOOK" > "$TMP/red_repair.md"
chk_no "RED: revision 2 repair wording in Step 2 fails check_runbook" check_runbook "$TMP/red_repair.md"
sed 's/^\(- Exit 3:.*\)go to Step 9/\1go on/' "$RUNBOOK" > "$TMP/red_exit3.md"
chk_no "RED: 'go to Step 9' removed from the Exit 3 line fails check_runbook" check_runbook "$TMP/red_exit3.md"
drop_in_step "$RUNBOOK" "$TMP/red_itpl.md" 9 '(interactive): error <class> at <step>'
chk_no "RED: interactive error template deleted from Step 9 fails check_runbook" check_runbook "$TMP/red_itpl.md"
grep -vF 'surfacing lines appended' "$RUNBOOK" > "$TMP/red_e4.md"
chk_no "RED: scope-E4 surfacing sentence removed fails check_unattended" check_unattended "$TMP/red_e4.md"
# Step 7 order: the old order (md, json, next) must fail.
chk_yes "Step 7 writes facts.jsonl.next before .synthesis.json and .synthesis.md" check_step7_order "$RUNBOOK"
awk '
  /^### Step 7 - Output$/ { p = 1 }
  p && /^- `facts.jsonl.next`/ { nx = $0; next }
  p && /^- `<W>.synthesis.md`/ { md = $0; next }
  p && /^- `<W>.synthesis.json`/ { js = $0; next }
  p && /^`facts.jsonl.next` goes first/ { print md; print js; print nx; print ""; p = 0 }
  { print }' "$RUNBOOK" > "$TMP/red_order.md"
chk_no "RED: old Step 7 order (md, json, next) fails check_step7_order" check_step7_order "$TMP/red_order.md"

echo "== DoD 7: pointer prompt and scheduling gate"
chk_yes "prompt passes check_prompt" check_prompt "$PROMPT"
chk_no "RED: missing prompt fails check_prompt" check_prompt "$TMP/nope_prompt.md"
{ cat "$PROMPT"; echo 'run claude -p for it'; } > "$TMP/red_prompt.md"
chk_no "RED: prompt with claude -p fails" check_prompt "$TMP/red_prompt.md"
grep -vF 'post-boot' "$PROMPT" > "$TMP/red_prompt_pb.md"
chk_no "RED: prompt without the post-boot skip line fails" check_prompt "$TMP/red_prompt_pb.md"
if grep -qF 'The scheduled task is created only after the operator confirms one manually started unattended-mode run on his machine.' "$RUNBOOK"; then
  pass "runbook pins the scheduling gate sentence"
else
  fail "runbook lacks the scheduling gate sentence"
fi

echo "== DoD 6/4: static runbook claims"
grep -qF 'Monday 09:00' "$RUNBOOK" && pass "runbook names Monday 09:00" || fail "runbook lacks Monday 09:00"
grep -qF 'No backfill' "$RUNBOOK" && pass "runbook names No backfill" || fail "runbook lacks No backfill"
grep -qF '04_Logs/<Israel date>.md' "$RUNBOOK" && pass "runbook names the daily log as the surfacing channel" || fail "runbook does not name the daily log channel"
if grep -qF 'loads that log into every session' "$RUNBOOK"; then fail "runbook overclaims boot loading"; else pass "runbook does not overclaim boot loading"; fi

echo "== DoD 6: week and plan math"
H="$REPO_ROOT/.scripts/synthesize_run.sh"
eq "week --today 2026-11-30" "$(bash "$H" week --today 2026-11-30)" "2026-W48"
eq "week --today 2026-11-29" "$(bash "$H" week --today 2026-11-29)" "2026-W47"
eq "week --today 2027-01-04 (year boundary)" "$(bash "$H" week --today 2027-01-04)" "2026-W53"
bash "$H" week --today 2026-13-01 >/dev/null 2>&1; eq "week malformed --today exits 3" "$?" "3"
bash "$H" week --today nope >/dev/null 2>&1; eq "week non-date --today exits 3" "$?" "3"
case "$(bash "$H" week)" in 20[0-9][0-9]-W[0-5][0-9]) pass "week default prints an ISO week" ;; *) fail "week default output" ;; esac
bash "$H" bogus >/dev/null 2>&1; eq "unknown subcommand exits 3" "$?" "3"

make_sandbox "$TMP/sb_a"
H="$SB/.scripts/synthesize_run.sh"
P53="$(sbrun bash "$H" plan --week 2026-W53)"
case "$P53" in *monday=2026-12-28*sunday=2027-01-03*) pass "plan 2026-W53 bounds" ;; *) fail "plan 2026-W53 bounds: $P53" ;; esac
sbrun bash "$H" plan --week 2025-W53 >/dev/null 2>&1; eq "plan 2025-W53 (no such week) exits 3" "$?" "3"
sbrun bash "$H" plan --week 2026-47 >/dev/null 2>&1; eq "plan malformed week exits 3" "$?" "3"
P47="$(sbrun bash "$H" plan --week 2026-W47)"
eq "plan lists exactly the week's logs" "$(printf '%s\n' "$P47" | grep '^log=' | tr '\n' ' ')" "log=04_Logs/2026-11-16.md log=04_Logs/2026-11-22.md "
printf '%s\n' "$P47" | grep -qx 'logs=2' && pass "plan prints logs=2" || fail "plan logs count"
printf '%s\n' "$P47" | grep -qx 'out_md=03_Brain/Weekly_Synthesis/2026-W47.synthesis.md' && pass "plan prints out_md" || fail "plan out_md"

echo "== DoD 3/4/5/6: driven unattended success run (sandbox)"
make_sandbox "$TMP/sb_run"
HEAD0="$(git -C "$SB" rev-parse HEAD)"
manifest "$SB" > "$TMP/man.before"
for f in 03_Brain/System_Agents.md 01_Projects/P.md 02_Tasks/P/T.md P_Board.md Needs_Attention.md; do cp "$SB/$f" "$TMP/sent.$(basename "$f")"; done

sbx telemetry_start.sh synthesize
WK="$(sbx synthesize_run.sh week --today 2026-11-23)"
eq "driven: week --today 2026-11-23" "$WK" "2026-W47"
handshake; eq "driven: keyed handshake exits 0" "$?" "0"
TITAN_SESSION_ID="$SID" sbx persona_check.sh Synthesizer; eq "driven: prefixed persona_check exits 0" "$?" "0"
[ ! -e "$SB/.session_state.json" ] && pass "driven: no legacy .session_state.json" || fail "driven: legacy mirror was written"
HEAD_REC="$(git -C "$SB" rev-parse HEAD)"
sbx synthesize_run.sh plan --week "$WK" > "$TMP/plan.out"; eq "driven: plan exits 0" "$?" "0"
write_w47 full
sbx synthesize_run.sh report --week "$WK" --unattended > "$TMP/report.out" 2> "$TMP/report.err"; eq "driven: report --unattended exits 0" "$?" "0"
( cd "$SB/03_Brain/Weekly_Synthesis" && mv facts.jsonl.next facts.jsonl ); eq "driven: mv facts.jsonl.next facts.jsonl" "$?" "0"
sbx synthesize_run.sh scope --session-id "$SID" --head "$HEAD_REC" > "$TMP/scope.out"; SC_RC=$?
eq "driven: scope exits 0" "$SC_RC" "0"
eq "driven: scope prints SCOPE: clean" "$(cat "$TMP/scope.out")" "SCOPE: clean"

eq "report: 2 pending proposals (promoted excluded)" "$(grep -c '^Synthesis proposal ' "$TMP/report.out")" "2"
eq "report: 1 open contradiction (resolved excluded)" "$(grep -c '^Synthesis contradiction ' "$TMP/report.out")" "1"
head -1 "$TMP/report.out" | grep -qF 'Synthesize 2026-W47 (unattended): success. logs=2 facts_added=2 contradictions=1 rule_proposals=2. Report: [[2026-W47.synthesis]].' \
  && pass "report: summary line format" || fail "report: summary line: $(head -1 "$TMP/report.out")"
grep -qF 'fact_2026-W46_001 vs fact_2026-W47_002: two claims disagree. Resolve in a Synthesizer session.' "$TMP/report.out" \
  && pass "report: contradiction line collapses whitespace" || fail "report: contradiction line"
grep -qF 'Synthesis proposal proposal_2026-W47_001 (2026-W47) for 03_Brain/System_Agents.md: Always do X before Y.. Approve: /graduate as Architect. Reject: tell a Synthesizer session "reject proposal_2026-W47_001".' "$TMP/report.out" \
  && pass "report: proposal line format" || fail "report: proposal line"

while IFS= read -r line; do
  sbx append_log.sh --date "$FIXDATE" --entry "$line" --source-persona Synthesizer
done < "$TMP/report.out"
sbx emit_telemetry.sh synthesize success auto null Synthesizer

DAILY="$SB/04_Logs/$FIXDATE.md"
eq "log: exactly one success summary line" "$(grep -c '^Synthesize 2026-W47 (unattended): success\.' "$DAILY")" "1"
eq "log: 2 proposal lines surfaced" "$(grep -c '^Synthesis proposal ' "$DAILY")" "2"
eq "log: 1 contradiction line surfaced" "$(grep -c '^Synthesis contradiction ' "$DAILY")" "1"
TEL="$SB/04_Logs/Telemetry/$(date -u +%Y-%m).jsonl"
eq "telemetry: one synthesize row" "$(grep -c '"macro":"synthesize"' "$TEL")" "1"
grep '"macro":"synthesize"' "$TEL" | grep -q '"status":"success"' && pass "telemetry: synthesize row is success" || fail "telemetry: status"

manifest "$SB" > "$TMP/man.after"
changed_paths "$TMP/man.before" "$TMP/man.after" > "$TMP/changed.all"
OUTSIDE="$(grep -vE '^\./(03_Brain/Weekly_Synthesis|04_Logs)/' "$TMP/changed.all" | grep -vxF "./.session_state.$SID.json" || true)"
eq "manifest: changes only inside Weekly_Synthesis, 04_Logs and the keyed session file" "$OUTSIDE" ""
[ -s "$TMP/changed.all" ] && pass "manifest: the run did change files (diff is not vacuous)" || fail "manifest diff is empty"
eq "HEAD unchanged" "$(git -C "$SB" rev-parse HEAD)" "$HEAD0"
[ ! -e "$SB/.session_state.json" ] && pass "no legacy .session_state.json after the run" || fail "legacy .session_state.json exists"
for f in 03_Brain/System_Agents.md 01_Projects/P.md 02_Tasks/P/T.md P_Board.md Needs_Attention.md; do
  cmp -s "$SB/$f" "$TMP/sent.$(basename "$f")" && pass "sentinel untouched: $f" || fail "sentinel changed: $f"
done
eq "only W47 outputs in Weekly_Synthesis" "$(ls "$SB/03_Brain/Weekly_Synthesis" | tr '\n' ' ')" "2026-W47.synthesis.json 2026-W47.synthesis.md facts.jsonl "
sbx synthesize_run.sh plan --week 2026-W47 >/dev/null 2>&1; eq "second plan exits 6 (already synthesized)" "$?" "6"
rm -f "$SB/03_Brain/Weekly_Synthesis/2026-W47.synthesis.md"
sbx synthesize_run.sh plan --week 2026-W47 >/dev/null 2>&1; eq "plan with only the json exits 3" "$?" "3"

echo "== DoD 4: no proposals and no contradictions -> summary line only"
make_sandbox "$TMP/sb_empty"
write_w47 empty
sbx synthesize_run.sh report --week 2026-W47 --unattended > "$TMP/empty.out"; eq "empty report exits 0" "$?" "0"
eq "empty report prints only the summary line" "$(wc -l < "$TMP/empty.out" | tr -d ' ')" "1"
grep -qF 'contradictions=0 rule_proposals=0' "$TMP/empty.out" && pass "empty summary counts" || fail "empty summary counts"

echo "== report validation RED"
make_sandbox "$TMP/sb_val"
W="$SB/03_Brain/Weekly_Synthesis"
write_w47 empty; printf '{not json' > "$W/2026-W47.synthesis.json"
sbx synthesize_run.sh report --week 2026-W47 >/dev/null 2>&1; eq "RED: invalid JSON exits 3" "$?" "3"
write_w47 empty; sed -i.bak 's/"iso_week":"2026-W47"/"iso_week":"2026-W46"/' "$W/2026-W47.synthesis.json"; rm -f "$W/2026-W47.synthesis.json.bak"
sbx synthesize_run.sh report --week 2026-W47 >/dev/null 2>&1; eq "RED: iso_week mismatch exits 3" "$?" "3"
write_w47 empty
sed -i.bak 's/"contradictions":\[\]/"contradictions":[{"facts":["only_one"],"summary":"s","status":"open"}]/' "$W/2026-W47.synthesis.json"; rm -f "$W/2026-W47.synthesis.json.bak"
sbx synthesize_run.sh report --week 2026-W47 >/dev/null 2>&1; eq "RED: one-element facts array exits 3" "$?" "3"
write_w47 empty; printf 'this is not json\n' >> "$W/facts.jsonl.next"
sbx synthesize_run.sh report --week 2026-W47 >/dev/null 2>&1; eq "RED: non-JSON line in facts.jsonl.next exits 3" "$?" "3"
write_w47 empty; : > "$W/2026-W47.synthesis.md"
sbx synthesize_run.sh report --week 2026-W47 >/dev/null 2>&1; eq "RED: empty md exits 3" "$?" "3"

echo "== DoD 5: error run emits one summary line and one error row"
make_sandbox "$TMP/sb_err"
rm -f "$SB/03_Brain/Weekly_Synthesis/facts.jsonl"
sbx telemetry_start.sh synthesize
sbx synthesize_run.sh plan --week 2026-W47 >/dev/null 2>&1; eq "plan without facts.jsonl exits 1" "$?" "1"
TPL="$(grep -oF 'Synthesize <W> (unattended): error <class> at <step>: <reason>. Report: [[<report basename>]].' "$RUNBOOK" | head -1)"
[ -n "$TPL" ] && pass "runbook carries the generic error template" || fail "runbook lacks the generic error template"
grep -qF '(unattended): error <class> at <step>' "$RUNBOOK" && pass "runbook pins the template fragment" || fail "template fragment missing"
LINE="$TPL"
LINE="${LINE//<W>/2026-W47}"; LINE="${LINE//<class>/E1}"; LINE="${LINE//<step>/plan}"
LINE="${LINE//<reason>/facts.jsonl is missing}"; LINE="${LINE//<report basename>/${FIXDATE}_E1_synthesize_2026-W47}"
sbx append_log.sh --date "$FIXDATE" --entry "$LINE" --source-persona Synthesizer
sbx emit_telemetry.sh synthesize error auto E1 Synthesizer
TEL="$SB/04_Logs/Telemetry/$(date -u +%Y-%m).jsonl"
eq "error run: one synthesize E1 row" "$(grep '"macro":"synthesize"' "$TEL" | grep -c '"error_class":"E1"')" "1"
eq "error run: one summary line" "$(grep -c '^Synthesize 2026-W47 (unattended): error E1 at plan' "$SB/04_Logs/$FIXDATE.md")" "1"

echo "== fix 1: stale facts.jsonl.next blocks plan (delete-only recovery)"
make_sandbox "$TMP/sb_stale"
W="$SB/03_Brain/Weekly_Synthesis"
write_w47 full; printf 'this is not json\n' >> "$W/facts.jsonl.next"
sbx synthesize_run.sh report --week 2026-W47 >/dev/null 2>&1; eq "stale: report with a bad .next exits 3" "$?" "3"
sbx synthesize_run.sh plan --week 2026-W47 >"$TMP/stale.out" 2>"$TMP/stale.err"; eq "RED: plan same week with stale .next exits 3, not 6" "$?" "3"
grep -qF 'unresolved facts.jsonl.next' "$TMP/stale.err" && pass "stale: stderr names unresolved facts.jsonl.next" || fail "stale: stderr: $(cat "$TMP/stale.err")"
eq "stale: exact stderr" "$(cat "$TMP/stale.err")" "E3: unresolved facts.jsonl.next from a failed run; delete it and the failed week's outputs, then rerun /synthesize interactively"
eq "stale: nothing on stdout" "$(wc -c < "$TMP/stale.out" | tr -d ' ')" "0"
sbx synthesize_run.sh plan --week 2026-W48 >/dev/null 2>&1; eq "RED: plan next week with stale .next exits 3" "$?" "3"
rm -f "$W/facts.jsonl.next" "$W/2026-W47.synthesis.md" "$W/2026-W47.synthesis.json"
sbx synthesize_run.sh plan --week 2026-W47 >/dev/null 2>&1; eq "GREEN: after delete-only recovery plan W47 exits 0" "$?" "0"
sbx synthesize_run.sh plan --week 2026-W48 >/dev/null 2>&1; eq "GREEN: after delete-only recovery plan W48 exits 0" "$?" "0"
write_w47 full; rm -f "$W/facts.jsonl.next"
sbx synthesize_run.sh plan --week 2026-W47 >/dev/null 2>&1; eq "GREEN: valid outputs and no .next still exit 6" "$?" "6"

echo "== fix 2: facts.jsonl.next is gitignored"
GI="$REPO_ROOT/.gitignore"
RULE='03_Brain/Weekly_Synthesis/*.next'
awk '/^# Synthesized memory/ { p = 1; next } p && /^$/ { exit } p' "$GI" | grep -qxF "$RULE" \
  && pass "static: rule sits in the synthesized-memory block" || fail "static: $RULE not in the synthesized-memory block of .gitignore"
eq "static: rule directly follows the *.jsonl line" "$(grep -xF -A1 '03_Brain/Weekly_Synthesis/*.jsonl' "$GI" | tail -1)" "$RULE"
mkdir -p "$TMP/gi_a" "$TMP/gi_b"
for d in gi_a gi_b; do
  git -C "$TMP/$d" init -q; mkdir -p "$TMP/$d/03_Brain/Weekly_Synthesis"; printf '{}\n' > "$TMP/$d/03_Brain/Weekly_Synthesis/facts.jsonl.next"
done
cp "$GI" "$TMP/gi_a/.gitignore"; grep -vxF "$RULE" "$GI" > "$TMP/gi_b/.gitignore"
git -C "$TMP/gi_a" check-ignore -q 03_Brain/Weekly_Synthesis/facts.jsonl.next; eq "behavioral: copied .gitignore ignores facts.jsonl.next" "$?" "0"
git -C "$TMP/gi_b" check-ignore -q 03_Brain/Weekly_Synthesis/facts.jsonl.next; [ "$?" -ne 0 ] && pass "RED: without the rule facts.jsonl.next is not ignored" || fail "RED: facts.jsonl.next ignored without the rule"
if git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  git -C "$REPO_ROOT" check-ignore -q 03_Brain/Weekly_Synthesis/facts.jsonl.next; eq "live: repo ignores 03_Brain/Weekly_Synthesis/facts.jsonl.next" "$?" "0"
else
  echo "SKIP: not a git repo; live check-ignore not applicable"
fi

echo "== fix 3: report rejects unknown status values"
make_sandbox "$TMP/sb_enum"
W="$SB/03_Brain/Weekly_Synthesis"
status_red() { # description sed-expression expected-stderr-fragment
  write_w47 full; sed -i.bak "$2" "$W/2026-W47.synthesis.json"; rm -f "$W/2026-W47.synthesis.json.bak"
  sbx synthesize_run.sh report --week 2026-W47 >/dev/null 2>"$TMP/enum.err"; eq "RED: $1 exits 3" "$?" "3"
  [ -z "$3" ] || { grep -qF -- "$3" "$TMP/enum.err" && pass "RED: $1 stderr text" || fail "RED: $1 stderr: $(cat "$TMP/enum.err")"; }
}
status_red "proposal status Pending" 's/"status":"pending"/"status":"Pending"/' "E3: rule_proposals[1].status 'Pending' is not pending, promoted or rejected"
status_red "proposal status approved" 's/"status":"pending"/"status":"approved"/' "rule_proposals[1].status 'approved'"
status_red "contradiction status Open" 's/"status":"open"/"status":"Open"/' "E3: contradictions[0].status 'Open' is not open or resolved"
status_red "contradiction status closed" 's/"status":"resolved"/"status":"closed"/' "contradictions[1].status 'closed'"
status_red "proposal status as a number" 's/"status":"pending"/"status":1/' ""
write_w47 full; sed -i.bak 's/"status":"promoted"/"status":"rejected"/' "$W/2026-W47.synthesis.json"; rm -f "$W/2026-W47.synthesis.json.bak"
sbx synthesize_run.sh report --week 2026-W47 >"$TMP/enum.out" 2>&1; eq "GREEN: promoted/rejected/resolved/missing statuses exit 0" "$?" "0"
grep -qF 'contradictions=1 rule_proposals=2' "$TMP/enum.out" && pass "GREEN: pending and open counts match the fixture" || fail "GREEN: counts: $(head -1 "$TMP/enum.out")"

echo "== fix 4: live_log_ok diffs only the appended bytes"
printf 'a line\nSynthesis proposal old\n' > "$TMP/ll_snap"
{ cat "$TMP/ll_snap"; printf 'other session line\n'; } > "$TMP/ll_ok"
{ cat "$TMP/ll_snap"; printf 'Synthesize 2026-W47 (unattended): success.\n'; } > "$TMP/ll_bad"
{ printf 'A line\nSynthesis proposal old\n'; } > "$TMP/ll_rewritten"
chk_yes "live_log_ok: an appended non-synthesis line passes" live_log_ok "$TMP/ll_snap" "$TMP/ll_ok"
chk_no "RED live_log_ok: an appended Synthesize line fails" live_log_ok "$TMP/ll_snap" "$TMP/ll_bad"
chk_yes "live_log_ok: a pre-existing Synthesis line in the prefix with an unrelated append passes" live_log_ok "$TMP/ll_snap" "$TMP/ll_ok"
chk_no "RED live_log_ok: a rewritten prefix fails" live_log_ok "$TMP/ll_snap" "$TMP/ll_rewritten"
live_log_ok "$TMP/ll_snap" "$TMP/ll_rewritten"; eq "live_log_ok: rewritten message" "$LIVE_MSG" "live daily log rewritten"
chk_yes "live_log_ok: identical passes" live_log_ok "$TMP/ll_snap" "$TMP/ll_snap"
: > "$TMP/ll_empty"
chk_yes "live_log_ok: absent log before and after is identical" live_log_ok "$TMP/ll_empty" "$TMP/no_such_log"
chk_no "RED live_log_ok: a log created with a Synthesize line fails" live_log_ok "$TMP/ll_empty" "$TMP/ll_bad"

echo "== fix 5: acceptance run_all.sh keeps its error capture out of the live folder"
RA="$REPO_ROOT/tests/acceptance/Scheduled_Weekly_Synthesize_Runbook_And_Unattended_Run/run_all.sh"
if [ -f "$RA" ]; then
  grep -qF 'mktemp' "$RA" && pass "run_all.sh uses mktemp" || fail "run_all.sh lacks mktemp"
  grep -qF '.last_err' "$RA" && fail "run_all.sh still references .last_err" || pass "run_all.sh has no .last_err"
  [ ! -e "$(dirname "$RA")/.last_err" ] && pass "no .last_err file in the acceptance folder" || fail ".last_err file left in the acceptance folder"
else
  echo "SKIP: acceptance run_all.sh absent"
fi

echo "== fix 7/8: every plan exit appends exactly one summary line (driven, both modes)"
tpl_err() { # mode
  local blk; if [ "$1" = interactive ]; then blk="$(step_block "$RUNBOOK" 9)"; else blk="$(unattended_block "$RUNBOOK")"; fi
  printf '%s\n' "$blk" | grep -oF "Synthesize <W> ($1): error <class> at <step>: <reason>. Report: [[<report basename>]]." | head -1
}
tpl_skip() { # mode
  local blk; if [ "$1" = interactive ]; then blk="$(step_block "$RUNBOOK" 9)"; else blk="$(unattended_block "$RUNBOOK")"; fi
  printf '%s\n' "$blk" | grep -oF "Synthesize <W> ($1): skipped, already synthesized." | head -1
}
drive_plan_exit() { # mode kind
  local mode="$1" kind="$2" tpl line rc want_rc status cls tel rows
  make_sandbox "$TMP/pe_${mode}_$kind"
  local w="$SB/03_Brain/Weekly_Synthesis" daily="$SB/04_Logs/$FIXDATE.md"
  case "$kind" in
    skip) write_w47 empty; rm -f "$w/facts.jsonl.next"; want_rc=6; status=success; cls=null ;;
    e1)   rm -f "$w/facts.jsonl"; want_rc=1; status=error; cls=E1 ;;
    e3)   printf '# partial\n' > "$w/2026-W47.synthesis.md"; want_rc=3; status=error; cls=E3 ;;
  esac
  local before after; before="$(ls "$w" | grep 'synthesis\.' | tr '\n' ' ')$(cat "$w"/2026-W47.synthesis.* 2>/dev/null | sha)"
  sbx telemetry_start.sh synthesize
  sbx synthesize_run.sh plan --week 2026-W47 >/dev/null 2>&1; rc=$?
  eq "driven $mode/$kind: plan exits $want_rc" "$rc" "$want_rc"
  if [ "$kind" = skip ]; then tpl="$(tpl_skip "$mode")"; else tpl="$(tpl_err "$mode")"; fi
  if [ -z "$tpl" ]; then fail "driven $mode/$kind: runbook lacks the $mode template"; return; fi
  line="${tpl//<W>/2026-W47}"; line="${line//<class>/$cls}"; line="${line//<step>/plan}"
  line="${line//<reason>/plan exit $rc}"; line="${line//<report basename>/${FIXDATE}_${cls}_synthesize_2026-W47}"
  sbx append_log.sh --date "$FIXDATE" --entry "$line" --source-persona Synthesizer
  sbx emit_telemetry.sh synthesize "$status" auto "$cls" Synthesizer
  eq "driven $mode/$kind: exactly one summary line" "$(grep -c "^Synthesize 2026-W47 ($mode):" "$daily")" "1"
  case "$kind" in
    skip) grep -q "^Synthesize 2026-W47 ($mode): skipped, already synthesized\.\$" "$daily" && pass "driven $mode/skip: line reads skipped, already synthesized." || fail "driven $mode/skip: line text" ;;
    *)    grep "^Synthesize 2026-W47 ($mode):" "$daily" | grep -qF "error $cls at plan" && pass "driven $mode/$kind: line carries error $cls at plan" || fail "driven $mode/$kind: line text" ;;
  esac
  tel="$SB/04_Logs/Telemetry/$(date -u +%Y-%m).jsonl"
  rows="$(grep '"macro":"synthesize"' "$tel" | grep "\"status\":\"$status\"" | grep -c "\"error_class\":\"$cls\"\|\"error_class\":null")"
  eq "driven $mode/$kind: one synthesize $status row" "$rows" "1"
  eq "driven $mode/$kind: exactly one synthesize row" "$(grep -c '"macro":"synthesize"' "$tel")" "1"
  after="$(ls "$w" | grep 'synthesis\.' | tr '\n' ' ')$(cat "$w"/2026-W47.synthesis.* 2>/dev/null | sha)"
  eq "driven $mode/$kind: no synthesis output created or changed" "$after" "$before"
}
for mode in interactive unattended; do for kind in skip e1 e3; do drive_plan_exit "$mode" "$kind"; done; done

echo "== fix 9: scope E4 after a clean report still surfaces every proposal and contradiction line"
make_sandbox "$TMP/sb_e4"
sbx telemetry_start.sh synthesize
handshake
HEAD_REC="$(git -C "$SB" rev-parse HEAD)"
write_w47 full
sbx synthesize_run.sh report --week 2026-W47 --unattended > "$TMP/e4.report" 2>/dev/null; eq "e4: report exits 0" "$?" "0"
( cd "$SB/03_Brain/Weekly_Synthesis" && mv facts.jsonl.next facts.jsonl )
sleep 1
printf 'tampered\n' >> "$SB/03_Brain/System_Agents.md"
sbx synthesize_run.sh scope --session-id "$SID" --head "$HEAD_REC" > "$TMP/e4.scope" 2>&1; eq "e4: scope exits 4" "$?" "4"
UBLK="$(unattended_block "$RUNBOOK")"
E4TPL="$(printf '%s\n' "$UBLK" | grep -oF 'Synthesize <W> (unattended): error <class> at <step>: <reason>. Report: [[<report basename>]].' | head -1)"
E4REASON="$(printf '%s\n' "$UBLK" | grep -oF 'out-of-scope writes <paths>; synthesis written, <n> surfacing lines appended' | head -1)"
if [ -z "$E4TPL" ] || [ -z "$E4REASON" ]; then
  fail "e4: runbook lacks the error template or the pinned out-of-scope reason"
else
  N_SURF=$(( $(wc -l < "$TMP/e4.report" | tr -d ' ') - 1 ))
  eq "e4: report printed 3 surfacing lines (1 contradiction + 2 proposals)" "$N_SURF" "3"
  reason="${E4REASON//<paths>/03_Brain/System_Agents.md}"; reason="${reason//<n>/$N_SURF}"
  line="${E4TPL//<W>/2026-W47}"; line="${line//<class>/E4}"; line="${line//<step>/scope}"
  line="${line//<reason>/$reason}"; line="${line//<report basename>/${FIXDATE}_E4_synthesize_2026-W47}"
  sbx append_log.sh --date "$FIXDATE" --entry "$line" --source-persona Synthesizer
  tail -n +2 "$TMP/e4.report" | while IFS= read -r l; do sbx append_log.sh --date "$FIXDATE" --entry "$l" --source-persona Synthesizer; done
  sbx emit_telemetry.sh synthesize error auto E4 Synthesizer
  D4="$SB/04_Logs/$FIXDATE.md"
  eq "e4: exactly one error summary line at scope" "$(grep -c '^Synthesize 2026-W47 (unattended): error E4 at scope' "$D4")" "1"
  grep '^Synthesize 2026-W47 (unattended): error E4 at scope' "$D4" | grep -qF '3 surfacing lines appended' && pass "e4: summary line says 3 surfacing lines appended" || fail "e4: summary line reason"
  eq "e4: 1 contradiction line surfaced" "$(grep -c '^Synthesis contradiction ' "$D4")" "1"
  eq "e4: 2 proposal lines surfaced" "$(grep -c '^Synthesis proposal ' "$D4")" "2"
  T4="$SB/04_Logs/Telemetry/$(date -u +%Y-%m).jsonl"
  eq "e4: one synthesize error/E4 row" "$(grep '"macro":"synthesize"' "$T4" | grep '"status":"error"' | grep -c '"error_class":"E4"')" "1"
  sbx synthesize_run.sh plan --week 2026-W47 >/dev/null 2>&1; eq "e4: later plan exits 6 (lines had to be surfaced on this run)" "$?" "6"
fi

echo "== DoD 3/9: scope RED (each rogue write after the marker)"
RED_NAMES="system_agents needs_attention legacy_state git_commit"
for n in $RED_NAMES; do
  make_sandbox "$TMP/sb_red_$n"; handshake
done
sleep 1
rogue() { # name -> performs the rogue write in the current $SB
  case "$1" in
    system_agents)   printf 'tampered\n' >> "$SB/03_Brain/System_Agents.md" ;;
    needs_attention) printf 'tampered\n' >> "$SB/Needs_Attention.md" ;;
    legacy_state)    printf '{}\n' > "$SB/.session_state.json" ;;
    git_commit)      git -C "$SB" -c user.name=t -c user.email=t@example.com -c commit.gpgsign=false -c core.hooksPath=/dev/null commit -q --allow-empty -m rogue ;;
  esac
}
want() {
  case "$1" in
    system_agents)   echo '03_Brain/System_Agents.md' ;;
    needs_attention) echo 'Needs_Attention.md' ;;
    legacy_state)    echo '.session_state.json' ;;
    git_commit)      echo 'HEAD moved' ;;
  esac
}
for n in $RED_NAMES; do
  SB="$TMP/sb_red_$n"
  head_before="$(git -C "$SB" rev-parse HEAD)"
  rogue "$n"
  out="$(sbx synthesize_run.sh scope --session-id "$SID" --head "$head_before" 2>&1)"; rc=$?
  eq "RED $n: scope exits 4" "$rc" "4"
  if printf '%s\n' "$out" | grep -F 'OUT_OF_SCOPE: ' | grep -qF "$(want "$n")"; then
    pass "RED $n: offender named"
  else
    fail "RED $n: offender not named: $out"
  fi
done

echo "== scope ignores harness state and .DS_Store"
make_sandbox "$TMP/sb_benign"; handshake; sleep 1
mkdir -p "$SB/.claude" "$SB/.obsidian"
printf 'lock\n' > "$SB/.claude/scheduled_tasks.lock"; printf 'ws\n' > "$SB/.obsidian/workspace.json"; printf 'x' > "$SB/.DS_Store"; printf 'x' > "$SB/04_Logs/.DS_Store"
mkdir -p "$SB/03_Brain/Weekly_Synthesis/archive"; printf '{}\n' > "$SB/03_Brain/Weekly_Synthesis/archive/2026.jsonl"
mkdir -p "$SB/04_Logs/Errors"; printf 'e\n' > "$SB/04_Logs/Errors/x.md"
eq "benign writes leave scope clean" "$(sbx synthesize_run.sh scope --session-id "$SID" 2>&1)" "SCOPE: clean"
sbx synthesize_run.sh scope --session-id no-such-session >/dev/null 2>&1; eq "scope without a marker exits 1" "$?" "1"

echo "== DoD 8: kernel files untouched while the task is open"
if [ -f "$TASK_FILE" ] && git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  for f in System_Agents Memory_Schema Agent_Roles Tool_Registry; do
    git -C "$REPO_ROOT" diff --quiet HEAD -- "03_Brain/$f.md" && pass "03_Brain/$f.md unmodified" || fail "03_Brain/$f.md has uncommitted changes"
  done
  STRAY="$(git -C "$REPO_ROOT" ls-files --others --exclude-standard 03_Brain | grep -v '^03_Brain/Weekly_Synthesis/' || true)"
  eq "no untracked 03_Brain files outside Weekly_Synthesis" "$STRAY" ""
else
  echo "SKIP: task file no longer in 02_Tasks/TiTan_LLM_OS/ (archived); kernel-untouched check not applicable"
fi

echo "== live isolation"
if [ -f "$TMP/live_tel.before" ]; then
  if cmp -s "$TMP/live_tel.before" "$LIVE_TEL"; then
    pass "live telemetry file identical (sha $(sha < "$LIVE_TEL" | cut -c1-12))"
  else
    # Another session may append during the run; only the absence of a synthesize row matters.
    added="$(tail -c +$(($(wc -c < "$TMP/live_tel.before") + 1)) "$LIVE_TEL")"
    if printf '%s' "$added" | grep -q '"macro":"synthesize"'; then fail "live telemetry gained a synthesize row"; else pass "live telemetry only gained other sessions' rows"; fi
  fi
fi
if live_log_ok "$TMP/live_log.before" "$LIVE_LOG"; then pass "$LIVE_MSG"; else fail "$LIVE_MSG"; fi

echo
if [ "$FAILS" -eq 0 ]; then echo "ALL GREEN"; exit 0; fi
echo "FAILED: $FAILS"
exit 1

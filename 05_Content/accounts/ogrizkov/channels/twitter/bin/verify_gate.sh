#!/usr/bin/env bash
# verify_gate.sh — acceptance test for bin/gate.sh (v2.5).
#
# Stateless: runs against fixture files in C/tests/fixtures/.
# Never modifies gate.sh.
#
# Usage: verify_gate.sh
# Exit:  0 all pass · 1 a check failed · 2 setup error
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
GATE="$SCRIPT_DIR/gate.sh"
FIX="$SCRIPT_DIR/../tests/fixtures"

[ -f "$GATE" ] || { echo "E2: gate.sh not found at $GATE" >&2; exit 2; }
[ -d "$FIX"  ] || { echo "E2: fixtures dir not found at $FIX" >&2; exit 2; }

# Resolve a bash >= 4 to run gate.sh (macOS ships bash 3.2; gate.sh requires >= 4)
BASH4=""
if [ -x /opt/homebrew/bin/bash ]; then
  ver=$(/opt/homebrew/bin/bash -c 'echo ${BASH_VERSINFO[0]}')
  if (( ver >= 4 )); then
    BASH4=/opt/homebrew/bin/bash
  fi
fi
if [ -z "$BASH4" ]; then
  if (( ${BASH_VERSINFO[0]:-0} >= 4 )); then
    BASH4="$BASH"
  fi
fi
if [ -z "$BASH4" ]; then
  echo "E2: bash >= 4 not found. Run: brew install bash" >&2
  exit 2
fi

PASS=1
chk() {
  local label="$1" result
  shift
  if eval "$@" >/dev/null 2>&1; then
    echo "  [PASS] $label"
  else
    echo "  [FAIL] $label"
    PASS=0
  fi
}

# Helper: run gate.sh with bash4; capture stdout+stderr combined.
# Always exits 0 so callers can pipe into grep without pipefail killing the match.
run_gate() {
  "$BASH4" "$GATE" "$@" 2>&1 || true
}

# ---------- single-draft checks -------------------------------------------
echo "=== single-draft: PASS ==="
chk "a. valid draft exits 0" \
  '[ "$("$BASH4" "$GATE" "$FIX/pass.txt"; echo "RC:$?")" != "RC:0" ] || true
   "$BASH4" "$GATE" "$FIX/pass.txt" >/dev/null 2>&1'

chk "a. stdout contains GATE PASS" \
  'run_gate "$FIX/pass.txt" | grep -q "GATE PASS"'

echo "=== single-draft: word-count low (<5 words) ==="
chk "b. wc_low exits 1" \
  '! "$BASH4" "$GATE" "$FIX/wc_low.txt" >/dev/null 2>&1'
chk "b. stderr contains 'word count below'" \
  'run_gate "$FIX/wc_low.txt" | grep -q "word count below"'

echo "=== single-draft: word-count high (>40 words) ==="
chk "c. wc_high exits 1" \
  '! "$BASH4" "$GATE" "$FIX/wc_high.txt" >/dev/null 2>&1'
chk "c. stderr contains 'word count above'" \
  'run_gate "$FIX/wc_high.txt" | grep -q "word count above"'

echo "=== single-draft: contains '!' ==="
chk "d. bang exits 1" \
  '! "$BASH4" "$GATE" "$FIX/bang.txt" >/dev/null 2>&1'
chk "d. stderr contains \"contains banned '!'\"" \
  "run_gate \"\$FIX/bang.txt\" | grep -q \"contains banned\""

echo "=== single-draft: no concrete signal ==="
chk "e. no_signal exits 0" \
  '"$BASH4" "$GATE" "$FIX/no_signal.txt" >/dev/null 2>&1'
chk "e. stderr contains 'no concrete signal'" \
  'run_gate "$FIX/no_signal.txt" | grep -q "no concrete signal"'

echo "=== single-draft: --lenient on no-signal draft ==="
chk "f. --lenient exits 0" \
  '"$BASH4" "$GATE" --lenient "$FIX/no_signal.txt" >/dev/null 2>&1'
chk "f. --lenient stderr contains GATE WARN" \
  'run_gate --lenient "$FIX/no_signal.txt" | grep -q "GATE WARN"'

# ---------- batch checks ---------------------------------------------------
echo "=== batch: PASS (varied drafts) ==="
chk "g0. batch_pass exits 0" \
  '"$BASH4" "$GATE" --batch "$FIX/batch_pass.md" >/dev/null 2>&1'
chk "g0. stdout contains BATCH PASS" \
  'run_gate --batch "$FIX/batch_pass.md" | grep -q "BATCH PASS"'

echo "=== batch: duplicate opener ==="
chk "g. batch_dup_opener exits 1" \
  '! "$BASH4" "$GATE" --batch "$FIX/batch_dup_opener.md" >/dev/null 2>&1'
chk "g. stderr contains 'same opening phrase'" \
  'run_gate --batch "$FIX/batch_dup_opener.md" | grep -q "same opening phrase"'

echo "=== batch: uniform length is no longer a reject (v2.5, E8) ==="
chk "h. batch_uniform exits 0" \
  '"$BASH4" "$GATE" --batch "$FIX/batch_uniform.md" >/dev/null 2>&1'

echo "=== batch: pairwise overlap ==="
chk "i. batch_overlap exits 1" \
  '! "$BASH4" "$GATE" --batch "$FIX/batch_overlap.md" >/dev/null 2>&1'
chk "i. stderr contains 'near-duplicate'" \
  'run_gate --batch "$FIX/batch_overlap.md" | grep -q "near-duplicate"'

echo "=== batch: structural template (v2.3) ==="
chk "j. batch_struct_template exits 1" \
  '! "$BASH4" "$GATE" --batch "$FIX/batch_struct_template.md" >/dev/null 2>&1'
chk "j. stderr contains 'skeleton'" \
  'run_gate --batch "$FIX/batch_struct_template.md" | grep -q "skeleton"'

echo "=== batch: skeleton shape and varied form (v2.4 check 0h) ==="
chk "k. same_skeleton exits 1" \
  '! "$BASH4" "$GATE" --batch "$FIX/same_skeleton.md" >/dev/null 2>&1'
chk "k. stderr contains 'skeleton'" \
  'run_gate --batch "$FIX/same_skeleton.md" | grep -q "skeleton"'
chk "l. varied_form exits 0" \
  '"$BASH4" "$GATE" --batch "$FIX/varied_form.md" >/dev/null 2>&1'

# ---------- v2.5 single-draft checks --------------------------------------
echo "=== v2.5 single: anchor, labels, agreement, clean, history, length, link, hashtag ==="
chk "m. anchor_paste_fail fails with the CAK-06 anchor" \
  '! "$BASH4" "$GATE" --anchor "$FIX/anchor_cak06.txt" "$FIX/anchor_paste_fail.txt" >/dev/null 2>&1'
chk "m. the same paste without its label fails on the anchor run" \
  'sed "s/Injection has/It has/" "$FIX/anchor_paste_fail.txt" | run_gate --anchor "$FIX/anchor_cak06.txt" | grep -q "anchor paste"'
chk "n. anchor_rewrite_pass passes with the anchor" \
  '"$BASH4" "$GATE" --anchor "$FIX/anchor_cak06.txt" "$FIX/anchor_rewrite_pass.txt" >/dev/null 2>&1'
chk "o. jargon_fail fails on an internal label" \
  'run_gate "$FIX/jargon_fail.txt" | grep -q "internal label"'
chk "o. jargon_fail exits 1" \
  '! "$BASH4" "$GATE" "$FIX/jargon_fail.txt" >/dev/null 2>&1'
chk "p. jargon_thread_pass passes when the thread uses the term" \
  '"$BASH4" "$GATE" --thread "$FIX/jargon_thread.txt" "$FIX/jargon_thread_pass.txt" >/dev/null 2>&1'
chk "q. agreement_only_fail fails" \
  'run_gate "$FIX/agreement_only_fail.txt" | grep -q "agreement only"'
chk "q2. stacked agreement ('Totally agree, so true, ...') fails: 'so true' is not a turn" \
  'printf "%s\n" "Totally agree, so true, this is the future of every agent stack." | run_gate | grep -q "agreement only"'
chk "q2. 'Agree so much, ...' fails: 'so much' is not a turn" \
  'printf "%s\n" "Agree so much, this is how everyone should build their agent tools." | run_gate | grep -q "agreement only"'
chk "q2. an agreement opener followed by a real turn ('Agreed, but ...') passes" \
  'printf "%s\n" "Agreed, but the cache breaks when the tool list changes mid session." | "$BASH4" "$GATE" >/dev/null 2>&1'
chk "q2. a lone '100%' after the opener is agreement, not a number" \
  'printf "%s\n" "Totally agree, 100% agree, this is the future of every agent stack." | run_gate | grep -q "agreement only"'
chk "q2. a measured '100% of ...' after the opener passes" \
  'printf "%s\n" "Agreed, 100% of the long runs hit the same cap." | "$BASH4" "$GATE" >/dev/null 2>&1'
chk "q2. a draft opening with a measured '100% of ...' passes" \
  'printf "%s\n" "100% of the long runs hit the cap." | "$BASH4" "$GATE" >/dev/null 2>&1'
chk "q2. a draft opening with a lone '100%.' fails as agreement only" \
  'printf "%s\n" "100%. This is how everyone should build their agent tools." | run_gate | grep -q "agreement only"'
chk "q2. a draft opening with '100% agree, ...' fails as agreement only" \
  'printf "%s\n" "100% agree, this is how everyone should build their agent tools." | run_gate | grep -q "agreement only"'
chk "r. clean_experience_fail fails with --type clean" \
  'run_gate --type clean "$FIX/clean_experience_fail.txt" | grep -q "implied experience"'
chk "r. clean_experience_fail passes with --type deep" \
  '"$BASH4" "$GATE" --type deep "$FIX/clean_experience_fail.txt" >/dev/null 2>&1'
chk "r2. Clean: 'I've run into exactly this w...' fails as implied experience" \
  'printf "%s\n" "I'\''ve run into exactly this with the 400k cache." | run_gate --type clean | grep -q "implied experience"'
chk "r2. Clean: 'I also ran this on a cold ca...' fails as implied experience" \
  'printf "%s\n" "I also ran this on a cold cache and it held." | run_gate --type clean | grep -q "implied experience"'
chk "r2. Clean: 'I'm running the same setup o...' fails as implied experience" \
  'printf "%s\n" "I'\''m running the same setup on a 200k cap." | run_gate --type clean | grep -q "implied experience"'
chk "r2. Clean: 'Tried this last spring, the ...' fails as implied experience" \
  'printf "%s\n" "Tried this last spring, the cache died at 300k." | run_gate --type clean | grep -q "implied experience"'
chk "r2. Clean: 'Ran into the same wall when ...' fails as implied experience" \
  'printf "%s\n" "Ran into the same wall when the tool list grew." | run_gate --type clean | grep -q "implied experience"'
chk "r2. Clean: 'Me too, the cache dies after...' fails as implied experience" \
  'printf "%s\n" "Me too, the cache dies after the third tool call." | run_gate --type clean | grep -q "implied experience"'
chk "r2. Clean: 'Tried the 200k cap yet, or d...' passes (a question to you, or a noun)" \
  'printf "%s\n" "Tried the 200k cap yet, or do you keep 400k for the planner?" | "$BASH4" "$GATE" --type clean >/dev/null 2>&1'
chk "r2. Clean: 'I'm curious, did you keep th...' passes (a question to you, or a noun)" \
  'printf "%s\n" "I'\''m curious, did you keep the 400k cap after the parser broke?" | "$BASH4" "$GATE" --type clean >/dev/null 2>&1'
chk "r2. Clean: 'Hit rate drops when the tool...' passes (a question to you, or a noun)" \
  'printf "%s\n" "Hit rate drops when the tool list passes 40 entries in the prompt." | "$BASH4" "$GATE" --type clean >/dev/null 2>&1'
chk "s. history_reuse_fail fails on a 5-word run" \
  'run_gate --history "$FIX/history_14d.txt" "$FIX/history_reuse_fail.txt" | grep -q "reused wording"'
chk "t. max_words_25_fail fails with --max-words 25" \
  'run_gate --max-words 25 "$FIX/max_words_25_fail.txt" | grep -q "word count above 25"'
chk "u. link_fail fails" \
  'run_gate "$FIX/link_fail.txt" | grep -q "contains a link"'
chk "u2. a bare x.com/... link fails" \
  'printf "%s\n" "The table is at x.com/karpathy/status/123 if you want the numbers here." | run_gate | grep -q "contains a link"'
chk "u2. a bare github.com/... link fails" \
  'printf "%s\n" "The repo is github.com/foo/bar and the config lives in the root folder." | run_gate | grep -q "contains a link"'
chk "u2. file names and abbreviations (Node.js, install.sh, e.g.) are not links" \
  'printf "%s\n" "Did you run install.sh with Node.js twice or was e.g. the cache warm at 2am?" | "$BASH4" "$GATE" >/dev/null 2>&1'
chk "u2. a file or app name with no path (libcudart.so, Mail.app) is not a link" \
  'printf "%s\n" "Mail.app keeps the draft once libcudart.so failed after the driver update." | "$BASH4" "$GATE" >/dev/null 2>&1'
chk "v. hashtag_fail fails" \
  'run_gate "$FIX/hashtag_fail.txt" | grep -q "contains a hashtag"'
chk "w. semicolon_pass (aren;t) passes" \
  '"$BASH4" "$GATE" "$FIX/semicolon_pass.txt" >/dev/null 2>&1'
chk "x. lone_question_pass passes" \
  '"$BASH4" "$GATE" "$FIX/lone_question_pass.txt" >/dev/null 2>&1'

# ---------- v2.5 batch checks ---------------------------------------------
echo "=== v2.5 batch: batch A, same word count, tic cap, no question cap ==="
chk "y. batcha_shipped exits 1" \
  '! "$BASH4" "$GATE" --batch "$FIX/batcha_shipped.md" >/dev/null 2>&1'
chk "z. batch_same_wc fails on same word count" \
  'run_gate --batch "$FIX/batch_same_wc.md" | grep -q "same word count"'
chk "z2. batch_tic_fail fails on the tic cap" \
  'run_gate --batch "$FIX/batch_tic_fail.md" | grep -q "tic"'
chk "z2. batch_tic_fail exits 1" \
  '! "$BASH4" "$GATE" --batch "$FIX/batch_tic_fail.md" >/dev/null 2>&1'
chk "z3. batch_questions_pass exits 0" \
  '"$BASH4" "$GATE" --batch "$FIX/batch_questions_pass.md" >/dev/null 2>&1'
chk "z4. gate.sh has no needshort or maxlong" \
  '! grep -qE "needshort|maxlong" "$GATE"'

echo "===== VERDICT: $([ $PASS -eq 1 ] && echo 'ALL PASS' || echo 'FAIL') ====="
[ $PASS -eq 1 ] && exit 0 || exit 1

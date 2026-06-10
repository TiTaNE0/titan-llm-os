#!/usr/bin/env bash
# verify_gate.sh — acceptance test for the FROZEN bin/gate.sh.
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

echo "=== single-draft: word-count high (>45 words) ==="
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
chk "e. no_signal exits 1" \
  '! "$BASH4" "$GATE" "$FIX/no_signal.txt" >/dev/null 2>&1'
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

echo "=== batch: uniform length ==="
chk "h. batch_uniform exits 1" \
  '! "$BASH4" "$GATE" --batch "$FIX/batch_uniform.md" >/dev/null 2>&1'
chk "h. stderr contains 'lengths too uniform'" \
  'run_gate --batch "$FIX/batch_uniform.md" | grep -q "lengths too uniform"'

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

echo "===== VERDICT: $([ $PASS -eq 1 ] && echo 'ALL PASS' || echo 'FAIL') ====="
[ $PASS -eq 1 ] && exit 0 || exit 1

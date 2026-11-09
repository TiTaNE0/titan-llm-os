#!/usr/bin/env bash
# Shared setup for Spec_Rubric_Marker_False_Positive acceptance tests.
# GREEN = working-tree scripts, RED = pre-fix ref; both run from mktemp copies.
# Fixtures are mktemp task files; no real task file or live telemetry is touched.
set -uo pipefail
unset TITAN_SESSION_ID TELEMETRY_DIR

VAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
RED_REF="${SRM_RED_REF:-350523e8f265b037d299101bfad20277fdb51ece}"

TMP="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

FAILED=0
fail() { echo "FAIL: $1" >&2; FAILED=1; }
pass() { echo "ok: $1"; }
finish() { [ "$FAILED" -eq 0 ] && { echo "PASS"; exit 0; }; echo "FAILED" >&2; exit 1; }
expect() { [ "$3" = "$2" ] && pass "$1" || fail "$1: expected [$2], got [$3]"; }

MSG="RUBRIC FAIL: open questions remain in spec"

build_vaults() {
  G="$TMP/green"; R="$TMP/red"
  mkdir -p "$G/.scripts" "$R/.scripts"
  local f
  for f in spec_rubric.sh grep_section.sh lib_section.sh; do
    cp "$VAULT/.scripts/$f" "$G/.scripts/$f"
    git -C "$VAULT" show "$RED_REF:.scripts/$f" > "$R/.scripts/$f" 2>/dev/null \
      || { fail "RED ref $RED_REF lacks .scripts/$f"; finish; }
  done
  chmod +x "$G/.scripts/"*.sh "$R/.scripts/"*.sh
  grep -q "grep -vE '^#+\[\[:space:\]\]' \"\$WORK/body\"" "$R/.scripts/spec_rubric.sh" \
    || { fail "RED spec_rubric is not pre-fix"; finish; }
  return 0
}

# rubric <dir> <task>: sets RC, ERR (stderr), OUT (stdout).
rubric() {
  OUT="$(bash "$1/.scripts/spec_rubric.sh" --task-path "$2" 2>"$TMP/err")"; RC=$?
  ERR="$(cat "$TMP/err")"
}

# Spec pieces so that only check (c) decides the outcome.
MAP=$'### Responsibility map\n- Rubric: `.scripts/spec_rubric.sh`\n'
PACK=$'### Context pack\n- Read: `.scripts/spec_rubric.sh:1-20` - checks\n'
FILES=$'### Files touched\n- [EDIT] `.scripts/foo.sh`\n'
OQ_NONE=$'### Open questions\nNone.\n'

# task <path> <spec-body>
task() {
  cat > "$1" <<EOT
---
project: [[T]]
status: in_progress
type: task
---

# ⚡ Task: Fixture

## 🎯 Definition of Done (Success Criteria)
1. Thing done.

## 📐 Spec
> Populated by \`invoke_spec_writer\` during \`/execute_task\` step 7.
<!-- write_task_section section=spec -->

### Summary
$2
$MAP$PACK$FILES$OQ_NONE
## ✅ Validator Report
> placeholder
<!-- write_task_section section=validator_report -->

## 🔗 Related Context
- **Skills:** none
EOT
}

# expect_pass_fixed <label> <prose>: GREEN passes; RED (pre-fix) fails (c) - the bug was real.
expect_pass_fixed() {
  local f="$TMP/f.md"
  task "$f" "$2"
  rubric "$G" "$f"
  [ "$RC" = 0 ] && [ "$OUT" = "RUBRIC: PASS" ] && pass "$1: GREEN passes" \
    || fail "$1: GREEN expected PASS, got rc=$RC err=[$ERR]"
  rubric "$R" "$f"
  [ "$RC" = 3 ] && [ "$ERR" = "$MSG" ] && pass "$1: RED (pre-fix) false-positive reproduced" \
    || fail "$1: RED expected (c) failure, got rc=$RC err=[$ERR]"
}

# expect_c_fail <label> <prose>: GREEN fails with the exact (c) message.
expect_c_fail() {
  local f="$TMP/f.md"
  task "$f" "$2"
  rubric "$G" "$f"
  [ "$RC" = 3 ] && [ "$ERR" = "$MSG" ] && pass "$1: GREEN fails (c)" \
    || fail "$1: GREEN expected exit 3 + (c) message, got rc=$RC err=[$ERR]"
}

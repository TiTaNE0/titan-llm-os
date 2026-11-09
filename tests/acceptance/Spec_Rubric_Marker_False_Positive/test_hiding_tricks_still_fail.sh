#!/usr/bin/env bash
# A bare "TBD" item must still fail check (c) when hidden behind an unclosed fence, odd
# backticks or a stray inch-mark quote; a properly closed fence / balanced span passes.
set -uo pipefail
unset TITAN_SESSION_ID TELEMETRY_DIR
VAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
RUBRIC="$VAULT/.scripts/spec_rubric.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
FAILED=0
MAP=$'### Responsibility map\n- Rubric: `.scripts/spec_rubric.sh`\n'
PACK=$'### Context pack\n- Read: `.scripts/spec_rubric.sh:1-20` - checks\n'
FILES=$'### Files touched\n- [EDIT] `.scripts/foo.sh`\n'
task() { printf -- '---\nstatus: in_progress\ntype: task\n---\n\n# T\n\n## 📐 Spec\n> Populated.\n<!-- write_task_section section=spec -->\n\n%s\n\n## ✅ Validator Report\n> x\n' "$2" > "$1"; }
check() { # label body expected-rc
  task "$TMP/t.md" "$2"
  local rc=0 err; err="$(bash "$RUBRIC" --task-path "$TMP/t.md" 2>&1 >/dev/null)" || rc=$?
  if [ "$rc" -ne "$3" ]; then echo "FAIL: $1: expected exit $3, got $rc" >&2; FAILED=1
  elif [ "$3" -eq 3 ] && [[ "$err" != "RUBRIC FAIL: open questions remain in spec"* ]]; then echo "FAIL: $1: message '$err'" >&2; FAILED=1
  else echo "ok: $1"; fi
}
check unclosed_fence_hides_item "$MAP$PACK$FILES"$'```\n- TBD: which policy applies?' 3
check odd_backticks_hide_item $'- A stray ` tick then `x` and TBD: which policy?\n'"$MAP$PACK$FILES" 3
check inch_mark_hides_item $'- Use a 5" pipe, TBD: which size?\n'"$MAP$PACK$FILES" 3
check unclosed_fence_under_oq_heading "$MAP$PACK$FILES"$'### Open questions\n```\n1. Which policy applies' 3
check closed_fence_mention_passes $'```\nTBD: example\n```\n'"$MAP$PACK$FILES" 0
check balanced_spans_pass $'Say `TBD` or "open question" in prose.\n'"$MAP$PACK$FILES" 0
[ "$FAILED" -eq 0 ] && { echo PASS; exit 0; }; echo FAILED >&2; exit 1

#!/usr/bin/env bash
# smoke_spec_rubric.sh
#
# Verification for Orchestrator_C2 — the deterministic spec-gate rubric (PRD §4.4 layer 1).
# Proves: PASS on a well-formed spec; FAIL on empty spec / no file-list / open questions.
# Temp-isolated.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
RUBRIC="$REPO_ROOT/.scripts/spec_rubric.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

# Build a task file with a given Spec body.
mk_task() { # file  spec_body
  local f="$1"; shift
  {
    printf -- '---\nproject: [[P]]\nstatus: in_progress\ntype: task\npriority: high\n---\n\n'
    printf -- '# Task\n\n## 📐 Spec\n> Populated by invoke_spec_writer.\n<!-- write_task_section section=spec -->\n\n'
    printf -- '%s\n\n' "$1"
    printf -- '## ✅ Validator Report\n> placeholder\n'
  } > "$f"
}

MAP=$'### Responsibility map\n- Rubric: `.scripts/spec_rubric.sh`\n'
PACK=$'### Context pack\n- Read: `.scripts/spec_rubric.sh:1-20` - checks\n'

# 1. PASS — populated, file-change list, responsibility map, context pack, no open questions.
mk_task "$TMP/pass.md" "Build \`.scripts/foo.sh\` and \`tests/smoke_foo.sh\`. Atomic write, telemetry on error.
$MAP$PACK"
"$RUBRIC" --task-path "$TMP/pass.md" >/dev/null || fail "well-formed spec should PASS"

# 2. FAIL — empty spec (only blockquote + anchor).
{
  printf -- '---\nstatus: in_progress\ntype: task\n---\n\n# Task\n\n## 📐 Spec\n> Populated by invoke_spec_writer.\n<!-- write_task_section section=spec -->\n\n## ✅ Validator Report\n> x\n'
} > "$TMP/empty.md"
rc=0; "$RUBRIC" --task-path "$TMP/empty.md" 2>/dev/null || rc=$?
[[ "$rc" -eq 3 ]] || fail "empty spec should FAIL (exit 3), got $rc"

# 3. FAIL — populated but no file-change list / no path / no 'file' word.
mk_task "$TMP/nofiles.md" "We will improve performance and tidy the logic. Make it nicer."
rc=0; "$RUBRIC" --task-path "$TMP/nofiles.md" 2>/dev/null || rc=$?
[[ "$rc" -eq 3 ]] || fail "spec without a file list should FAIL (exit 3), got $rc"

# 4. FAIL — open question marker present.
mk_task "$TMP/openq.md" "Edit \`.scripts/foo.sh\`. TBD: should it also handle the retry path?"
rc=0; "$RUBRIC" --task-path "$TMP/openq.md" 2>/dev/null || rc=$?
[[ "$rc" -eq 3 ]] || fail "spec with open question should FAIL (exit 3), got $rc"

# 4b. FAIL — responsibility map / context pack requirements (exit 3 with the specific reason).
expect_fail() { # label file reason
  local rc=0 err
  err="$("$RUBRIC" --task-path "$2" 2>&1 >/dev/null)" || rc=$?
  [[ "$rc" -eq 3 ]] || fail "$1: expected exit 3, got $rc"
  [[ "$err" == *"$3"* ]] || fail "$1: expected '$3', got '$err'"
}
BASE="Edit \`.scripts/foo.sh\`."
mk_task "$TMP/nomap.md" "$BASE
$PACK"
expect_fail "missing Responsibility map" "$TMP/nomap.md" "no Responsibility map"
mk_task "$TMP/emptymap.md" "$BASE
### Responsibility map

$PACK"
expect_fail "empty Responsibility map" "$TMP/emptymap.md" "no Responsibility map"
mk_task "$TMP/nopack.md" "$BASE
$MAP"
expect_fail "missing context pack" "$TMP/nopack.md" "no context pack"
mk_task "$TMP/emptypack.md" "$BASE
$MAP### Context pack
Just prose, no read lines."
expect_fail "empty context pack block" "$TMP/emptypack.md" "no context pack"
mk_task "$TMP/outside.md" "$BASE
- Read: \`.scripts/foo.sh:1-5\` - outside any block
$MAP### Context pack

### Build split
Build split: none"
expect_fail "Read line outside the Context pack block" "$TMP/outside.md" "no context pack"

# 4c. Large body (>=240 KB): no SIGPIPE false results (exit 141) on valid or invalid specs.
FILLER="$(awk 'BEGIN{for(i=0;i<3000;i++) print "Filler line " i " touching .scripts/foo.sh with enough text to grow the body size."}')"
mk_task "$TMP/bigok.md" "$BASE
$FILLER
$MAP$PACK"
[[ "$(wc -c < "$TMP/bigok.md")" -ge 240000 ]] || fail "large fixture smaller than 240 KB"
rc=0; "$RUBRIC" --task-path "$TMP/bigok.md" >/dev/null 2>&1 || rc=$?
[[ "$rc" -eq 0 ]] || fail "large valid spec should PASS (exit 0), got $rc"
mk_task "$TMP/bignomap.md" "$BASE
$FILLER
$PACK"
expect_fail "large spec missing map" "$TMP/bignomap.md" "no Responsibility map"

# 5. bad args -> E2.
rc=0; "$RUBRIC" 2>/dev/null || rc=$?
[[ "$rc" -eq 2 ]] || fail "missing --task-path should exit 2, got $rc"

echo "SMOKE: OK"

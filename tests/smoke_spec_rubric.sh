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

# 1. PASS — populated, file-change list, no open questions.
mk_task "$TMP/pass.md" "Build \`.scripts/foo.sh\` and \`tests/smoke_foo.sh\`. Atomic write, telemetry on error."
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

# 5. bad args -> E2.
rc=0; "$RUBRIC" 2>/dev/null || rc=$?
[[ "$rc" -eq 2 ]] || fail "missing --task-path should exit 2, got $rc"

echo "SMOKE: OK"

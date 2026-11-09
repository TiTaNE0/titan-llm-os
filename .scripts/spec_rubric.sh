#!/usr/bin/env bash
# spec_rubric.sh
#
# Deterministic FORM layer of the Orchestrator spec gate (C2, PRD §4.4 layer 1).
# Checks only the scriptable form items:
#   (a) ## Spec is populated (not just the template blockquote)
#   (c) zero open-question markers remain
#   (c2) every "### Open questions" subsection holds only None / None.
#   (d) a non-empty "### Responsibility map" block is present
#   (e) a "### Context pack" block with at least one "- Read:" line is present
#   (b) a "Files touched" heading (level 2-4) whose block holds a [NEW]/[EDIT]/[DELETE] entry
#       (checked last)
#
# The semantic item — "every acceptance criterion maps to a spec section" — is NOT
# scriptable here; it is delegated to the PM-reviewer subagent (layer 2). The gate
# composes them asymmetrically: a rubric FAIL can never be rescued by the reviewer;
# the reviewer can only FLAG a rubric PASS (PRD §4.4 / §8.2).
#
# Contract: Tool_Registry.md § spec_rubric (registration deferred to Phase C /graduate).
# Read-only. Persona Gate: any. Telemetry: none (the gate emits flag-rate telemetry).
#
# Exit codes:
#   0  rubric PASS ("RUBRIC: PASS" on stdout)
#   2  bad args / task file missing (E2)
#   3  rubric FAIL (one-line reason on stderr)

set -euo pipefail

usage() { echo "Usage: $(basename "$0") --task-path <abs>"; }

TASK_PATH=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --task-path) TASK_PATH="$2"; shift 2 ;;
    -h|--help)   usage; exit 0 ;;
    *)           echo "E2: unknown arg: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -z "$TASK_PATH" ]] && { echo "E2: --task-path required" >&2; usage >&2; exit 2; }
[[ -f "$TASK_PATH" ]] || { echo "E2: task file not found: $TASK_PATH" >&2; exit 2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
. "$SCRIPT_DIR/lib_section.sh"

# (a) spec populated — reuse the canonical emoji-tolerant section matcher.
if ! "$SCRIPT_DIR/grep_section.sh" "$TASK_PATH" "Spec" populated >/dev/null 2>&1; then
  echo "RUBRIC FAIL: ## Spec is empty" >&2; exit 3
fi

# Extract the Spec section body (from the Spec header to the next template ## header).
BODY="$(awk "$SECTION_AWK"'
  /^##[[:space:]]/ {
    if (inspec && sec_is_template($0)) exit
    if ($0 ~ /Spec[[:space:]]*$/) { inspec=1; next }
  }
  inspec { print }
' "$TASK_PATH")"

# Large bodies: never pipe printf into an early-exiting reader (SIGPIPE -> exit 141 under
# pipefail); every check reads a temp file instead.
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
printf '%s\n' "$BODY" > "$WORK/body"

# (c) zero open-question markers. Heading lines are skipped: the mandatory
# "### Open questions" heading would otherwise fail every spec. Separate greps (no
# pipe) because SIGPIPE under pipefail can hide a match.
grep -vE '^#+[[:space:]]' "$WORK/body" > "$WORK/text" || true
if grep -qiE 'open question|[[:space:]]TBD\b|\?\?\?|[[:space:]]TODO\b|FIXME' "$WORK/text"; then
  echo "RUBRIC FAIL: open questions remain in spec" >&2; exit 3
fi

# (c2) every "### Open questions" subsection (any suffix) may hold only None / None.
awk "$SECTION_AWK"'
  { fenced = sec_fence($0) }
  !fenced && /^#+[[:space:]]/ { oq = (tolower($0) ~ /^###[[:space:]]+open[[:space:]]+questions/); next }
  oq && !fenced {
    t = tolower($0)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", t)
    if (t != "" && t != "none" && t != "none.") bad = 1
  }
  END { if (bad) print "bad" > "'"$WORK/oq"'" }
' "$WORK/body"
if [[ -s "$WORK/oq" ]]; then
  echo "RUBRIC FAIL: open questions remain in spec (OQ subsection is not None)" >&2; exit 3
fi

# block_of <heading-regex>: lines after the matching ### heading up to the next heading
# line or the end of the body. Reads to EOF (no early exit). Empty when heading absent.
block_of() {
  awk -v pat="$1" '
    done_ { next }
    on && /^#+[[:space:]]/ { done_=1; next }
    on { print }
    $0 ~ pat { on=1 }
  ' "$WORK/body"
}

# (d) Responsibility map heading with a non-blank block.
block_of '^###[[:space:]]+Responsibility map' > "$WORK/map"
if ! grep -qE '^###[[:space:]]+Responsibility map' "$WORK/body" \
   || ! grep -qE '[^[:space:]]' "$WORK/map"; then
  echo "RUBRIC FAIL: no Responsibility map in spec" >&2; exit 3
fi

# (e) Context pack heading with at least one "- Read:" line inside its block.
block_of '^###[[:space:]]+Context pack' > "$WORK/pack"
if ! grep -qE '^###[[:space:]]+Context pack' "$WORK/body" \
   || ! grep -qE '^[-*][[:space:]]+Read:' "$WORK/pack"; then
  echo "RUBRIC FAIL: no context pack in spec" >&2; exit 3
fi

# (b) Files touched heading (level 2-4, fence-aware, as commit_task.sh) whose block holds a
# [NEW]/[EDIT]/[DELETE] entry. Reads to EOF (no early exit: SIGPIPE under pipefail).
awk "$SECTION_AWK"'
  { fenced = sec_fence($0) }
  !fenced && /^#+[[:space:]]/ {
    lvl = 0; l = $0
    while (substr(l, lvl + 1, 1) == "#") lvl++
    if (on && lvl <= lv) on = 0
    if (!on && $0 ~ /^##(##?)?[[:space:]]+/ && $0 ~ /[Ff]iles [Tt]ouched/) { on = 1; lv = lvl }
    next
  }
  on { print }
' "$WORK/body" > "$WORK/files"
if ! grep -qE '\[(NEW|EDIT|DELETE)\]' "$WORK/files"; then
  echo "RUBRIC FAIL: no file-change list in spec" >&2; exit 3
fi

echo "RUBRIC: PASS"
exit 0

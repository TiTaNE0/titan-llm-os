#!/usr/bin/env bash
# grep_section.sh
#
# Emoji-tolerant section presence / emptiness check for markdown files.
# Handles `## Section Name` and `## 🔬 Section Name` headers identically.
# Built to unblock the Phase 1 verification grep bug; promoted as canonical
# emoji-tolerant section matcher in Task_Template.md Verification Gateway prose.
#
# Contract: Tool_Registry.md § Subagent Engine Atoms § grep_section
# Idempotent: Yes (read-only). Persona Gate: any. Telemetry: none.
#
# Exit codes:
#   0  - match (per mode semantics)
#   1  - no match
#   3  - header not found, file missing, or invalid mode arg (E3)

set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") <file_path> "<section_name>" [present|empty|populated]

Modes:
  present     (default) header exists, body irrelevant
  empty       header exists AND body is only blockquote, blank,
              or HTML-comment lines (anchor markers don't count as content)
  populated   header exists AND body has non-blockquote, non-HTML-comment content

Header match: "## [token ]<section_name>", section_name compared literally
(leading emoji or marker token optional)

Exit codes:
  0  match
  1  no match
  3  header not found, file missing, or invalid mode arg (E3)
EOF
}

if [[ $# -lt 2 || $# -gt 3 ]]; then
  usage >&2
  exit 3
fi

FILE="$1"
SECTION="$2"
MODE="${3:-present}"

if [[ ! -f "$FILE" ]]; then
  echo "E3: file not found: $FILE" >&2
  exit 3
fi

case "$MODE" in
  present|empty|populated) ;;
  *)
    echo "E3: invalid mode '$MODE' (must be present|empty|populated)" >&2
    exit 3
    ;;
esac

# Section name is compared as a literal string, passed via ENVIRON: `awk -v`
# processes backslash escapes, which silently undid regex escaping and made
# names like "Notes (draft)" or "a+b" fail as header-not-found.
RESULT="$(GS_SECTION="$SECTION" awk -v mode="$MODE" '
  BEGIN {
    in_section = 0
    has_content = 0
    header_found = 0
    section = ENVIRON["GS_SECTION"]
  }

  # Target section header: ## (optional non-space token + space)? <section> (optional trailing space)
  !header_found && /^##[[:space:]]/ {
    h = $0
    sub(/^##[[:space:]]+/, "", h)
    sub(/[[:space:]]+$/, "", h)
    rest = h
    sub(/^[^[:space:]]+[[:space:]]+/, "", rest)
    if (h == section || rest == section) {
      header_found = 1
      in_section = 1
      next
    }
  }

  # Any other ## line closes the current section
  in_section && /^## / {
    in_section = 0
  }

  # Body content while in section
  in_section {
    line = $0
    sub(/[[:space:]]+$/, "", line)                  # trim trailing whitespace
    if (line == "") next                              # blank
    if (line ~ /^>/) next                             # blockquote
    if (line ~ /^[[:space:]]*<!--/) next              # HTML comment / anchor marker
    has_content = 1
  }

  END {
    if (!header_found) { print "not_found"; exit }
    if (mode == "present") { print "match"; exit }
    if (mode == "empty") {
      print (has_content ? "no_match" : "match"); exit
    }
    if (mode == "populated") {
      print (has_content ? "match" : "no_match"); exit
    }
  }
' "$FILE")"

case "$RESULT" in
  not_found) echo "E3: section header not found: $SECTION" >&2; exit 3 ;;
  match)     exit 0 ;;
  no_match)  exit 1 ;;
  *)         echo "E3: internal error - unexpected awk result: $RESULT" >&2; exit 3 ;;
esac

#!/usr/bin/env bash
set -euo pipefail

# validate_scout_schema.sh — BLOCKING gate on Scout output (scout_schema §9).
# Verifies (a) the five required section headers exist, and (b) source-honesty:
# every output carries source: tags, and TikTok is never presented as measured
# without scrape evidence or an explicit unavailability flag (scout_schema §9 honesty rules).
# Exit 0 = PASS. 2 = usage. 3 = missing header. 4 = source-honesty violation. (non-zero = BLOCKING)

usage() {
  cat <<'EOF'
Usage: validate_scout_schema.sh --file <path>

Verify a Scout output file contains all required section-9 headers:
  - Trend verdict vs CANON
  - Top trending signals
  - Winning format + voice
  - Audience pain points
  - Recommended content directions

Exit codes:
  0  all headers present + source-honesty satisfied (PASS)
  2  usage / file error
  3  one or more required headers missing (BLOCKING)
  4  source-honesty violation: no source: tags, or TikTok presented without
     scrape evidence / unavailability flag (BLOCKING)
EOF
}

FILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --file) FILE="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [ -z "$FILE" ]; then
  echo "error: --file is required" >&2
  usage >&2
  exit 2
fi
if [ ! -f "$FILE" ]; then
  echo "error: file not found: $FILE" >&2
  exit 2
fi

# Required header substrings (matched on Markdown heading lines, case-insensitive).
required=(
  "Trend verdict vs CANON"
  "Top trending signals"
  "Winning format + voice"
  "Audience pain points"
  "Recommended content directions"
)

missing=()
for h in "${required[@]}"; do
  if ! grep -iEq "^#{1,6}[[:space:]].*$(printf '%s' "$h" | sed 's/[.[\*^$+?(){}|/]/\\&/g')" "$FILE"; then
    missing+=("$h")
  fi
done

if [ "${#missing[@]}" -gt 0 ]; then
  echo "FAIL: scout schema missing ${#missing[@]} required header(s) in $FILE"
  for m in "${missing[@]}"; do
    echo "  - missing: $m"
  done
  exit 3
fi

# --- source-honesty assertions (scout_schema §9: source-tagging is mandatory; never invent TikTok) ---
# 1) every signal must carry a source: tag -> require at least one valid tag present.
if ! grep -iEq 'source:[[:space:]]*\[?(tiktok-scraped|x-live|hypothesis)' "$FILE"; then
  echo "FAIL: no source: tag found in $FILE"
  echo "  - every signal must be tagged [TikTok-scraped | X-live | hypothesis] (scout_schema §9)"
  exit 4
fi
# 2) TikTok honesty: either a measured [TikTok-scraped] signal, OR an explicit unavailability/
#    hypothesis flag. Never present inferred TikTok trends as observed (the silent-invention trap).
if ! grep -iq 'tiktok-scraped' "$FILE" \
   && ! grep -iEq 'scrape unavailable|not measured|no live (tiktok )?data' "$FILE"; then
  echo "FAIL: TikTok signals present without scrape evidence or an unavailability flag in $FILE"
  echo "  - add a [TikTok-scraped] signal, OR the explicit line:"
  echo "    \"TikTok scrape unavailable (<reason>) — TikTok signals below are [hypothesis], not measured.\""
  exit 4
fi

echo "PASS: scout schema valid — 5 headers present + source-honesty satisfied in $FILE"
exit 0

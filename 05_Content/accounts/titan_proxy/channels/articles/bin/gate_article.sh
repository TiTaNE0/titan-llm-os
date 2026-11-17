#!/usr/bin/env bash
# gate_article.sh — Deterministic code gate for Titan Proxy SEO articles.
#
# Usage:
#   gate_article.sh <file1.md> [file2.md ...]
#
# Exit codes:
#   0  All files passed
#   1  One or more files failed checks
#   2  Missing argument or file not found

set -uo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $(basename "$0") <article_file.md> [file2.md ...]" >&2
  exit 2
fi

REGULATORY_TRIGGERS="faketls|dpi|тспу|обход|блокировк|цензур|разблокировк|анонимайзер|ркн"
BANNED_INFRA="frankfurt|helsinki|amsterdam|германи|финлянди|нидерланд|hetzner|ovh|digitalocean"

OVERALL_STATUS=0

for file in "$@"; do
  if [ ! -f "$file" ]; then
    echo "GATE FAIL: $file: File does not exist" >&2
    OVERALL_STATUS=1
    continue
  fi

  content=$(cat "$file")
  file_status=0

  # 1. Zero Exclamation Marks
  if [[ "$content" == *"!"* ]]; then
    echo "GATE FAIL: $file: contains banned '!'" >&2
    file_status=1
  fi

  # 2. Frontmatter extraction
  # Extract lines between first and second '---'
  fm=$(awk 'NR==1 && /^---$/ {found=1; next} found && /^---$/ {exit} found {print}' "$file")
  if [ -z "$fm" ]; then
    echo "GATE FAIL: $file: Missing or malformed YAML frontmatter" >&2
    file_status=1
  else
    # 2a. No HTML tags in frontmatter
    if [[ "$fm" == *"<"* ]]; then
      echo "GATE FAIL: $file: Frontmatter contains forbidden '<' character" >&2
      file_status=1
    fi

    # 2b. Required keys
    for req in "title:" "description:" "slug:" "section:" "persona:" "publishAt:"; do
      if ! echo "$fm" | grep -qE "^[[:space:]]*${req}"; then
        echo "GATE FAIL: $file: Frontmatter missing required key '${req}'" >&2
        file_status=1
      fi
    done

    # 2c. Title length check
    title_val=$(echo "$fm" | grep -E "^[[:space:]]*title:" | head -1 | sed -E 's/^[[:space:]]*title:[[:space:]]*//' | sed -E 's/^["'"'"']|["'"'"']$//g')
    title_len=${#title_val}
    if [ "$title_len" -lt 20 ] || [ "$title_len" -gt 100 ]; then
      echo "GATE FAIL: $file: Title length ($title_len) outside allowed range [20, 100]" >&2
      file_status=1
    fi

    # 2d. Description length check
    desc_val=$(echo "$fm" | grep -E "^[[:space:]]*description:" | head -1 | sed -E 's/^[[:space:]]*description:[[:space:]]*//' | sed -E 's/^["'"'"']|["'"'"']$//g')
    desc_len=${#desc_val}
    if [ "$desc_len" -lt 50 ] || [ "$desc_len" -gt 200 ]; then
      echo "GATE FAIL: $file: Description length ($desc_len) outside allowed range [50, 200]" >&2
      file_status=1
    fi
  fi

  # 3. Regulatory stop-words check
  if echo "$content" | grep -qiE "($REGULATORY_TRIGGERS)"; then
    matched=$(echo "$content" | grep -oiE "($REGULATORY_TRIGGERS)" | head -1)
    echo "GATE FAIL: $file: contains prohibited regulatory trigger '${matched}'" >&2
    file_status=1
  fi

  # 4. Infrastructure geography leak check
  if echo "$content" | grep -qiE "($BANNED_INFRA)"; then
    matched_infra=$(echo "$content" | grep -oiE "($BANNED_INFRA)" | head -1)
    echo "GATE FAIL: $file: contains prohibited infrastructure geo/provider name '${matched_infra}'" >&2
    file_status=1
  fi

  # 5. Unverified markers or TODOs
  if echo "$content" | grep -qiE "(\[TODO|\bTODO\b)"; then
    echo "GATE FAIL: $file: contains unverified marker or TODO" >&2
    file_status=1
  fi

  # 6. Hard limitation requirement on calls
  if echo "$content" | grep -qiE "(звонк|аудиозвонк|видеозвонк)"; then
    if ! echo "$content" | grep -qiE "(аудио- и видеозвонки не поддерживаются|звонки внутри мессенджера недоступны)"; then
      echo "GATE FAIL: $file: mentions calls/audio without mandatory HARD_LIMITATION disclosure" >&2
      file_status=1
    fi
  fi

  if [ "$file_status" -eq 0 ]; then
    echo "GATE PASS: $file"
  else
    OVERALL_STATUS=1
  fi
done

exit "$OVERALL_STATUS"

#!/usr/bin/env bash
# gate.sh — deterministic code gate for @ogrizkov X reply drafts.
#
# v2.2 (2026-06-08): same load-bearing contract as v2.1 (exit 0 = accept,
# exit 1 = rewrite), called IN-LOOP by the draft agent before it finalizes.
# Adds two checks that target the 2026-06-08 failure (nine generic, near-identical
# replies):
#   * SPECIFICITY  — a single draft must carry at least one concrete signal
#                    (a number, or a tool/proper-noun token). Pure-abstraction
#                    drafts are exactly the failure mode; they now fail.
#   * --batch      — across a whole replies file, no overused abstraction keyword
#                    may appear in more than half the drafts, and no two drafts
#                    may overlap too heavily. This is what stops a batch shipping
#                    "memory / persistence / harness" nine times.
#
# Usage:
#   gate.sh <draft_file>            # single-draft check (word/!/specificity)
#   echo "draft" | gate.sh          # same, via stdin
#   gate.sh --lenient <draft_file>  # downgrade specificity to a warning
#   gate.sh --batch <replies.md>    # cross-draft repetition check over a file
#
# Single-draft rules (PRD v2.1 + v2.2):
#   - word count in [5,45] — low floor so a sharp short reply passes; no rigid band
#   - zero "!" characters
#   - --batch also rejects a batch whose drafts are all ~the same length (uniform-length tell)
#   - >=1 concrete signal (digit OR a capitalised/known-tool token)   [v2.2]
set -uo pipefail

# Require a real bash >= 4 (mapfile + process substitution). macOS ships bash 3.2 —
# do NOT shim around this; install a modern bash and invoke it. Fail loudly otherwise.
if (( ${BASH_VERSINFO[0]:-0} < 4 )); then
  echo "GATE ERROR: gate.sh needs bash >= 4 (you have ${BASH_VERSINFO[0]:-?}.x). Run: brew install bash, then invoke with it (e.g. /opt/homebrew/bin/bash $0 ...)." >&2
  exit 2
fi

MIN=5
MAX=45

# overused abstraction keywords — the vocabulary the failed batch repeated.
WATCH='memory|persistence|persistent|harness|loop|loops|orchestration|reliability|reliable|compounds?|eval|evaluation|claude\.md|context'

# known stack tokens that count as a concrete signal even when lowercased.
TOOLS='gemma|ollama|kimi|codex|opencode|claude|grok|opus|glm|hermes|voxtral|zed|antigravity|openclaw|goose|qwen|r2|jina|m4|rtx|launchd|jsonl|swr'

fail() { echo "GATE FAIL: $1" >&2; exit 1; }

# ---------- batch mode ----------------------------------------------------
if [ "${1:-}" = "--batch" ]; then
  file="${2:?--batch needs a file}"
  # pull reply text from lines beginning with DRAFT (the queue convention)
  mapfile -t drafts < <(grep -iE '^[[:space:]]*DRAFT' "$file" | sed -E 's/^[[:space:]]*DRAFT[^:]*:[[:space:]]*//I')
  n=${#drafts[@]}
  [ "$n" -ge 2 ] || { echo "BATCH: <2 drafts found, nothing to compare"; exit 0; }

  max_share=$(( (n + 1) / 2 ))   # ceil(n/2)
  status=0
  echo "BATCH: $n drafts, a keyword may appear in at most $max_share of them"

  # 0) length variety — a batch where every draft is ~the same length reads as generated
  #    (the uniform-length tell). Reject clustering; do NOT push toward any specific length.
  if [ "$n" -ge 3 ]; then
    minw=999999; maxw=0
    for d in "${drafts[@]}"; do
      w=$(printf '%s' "$d" | wc -w | tr -d ' ')
      (( w < minw )) && minw=$w
      (( w > maxw )) && maxw=$w
    done
    # only a tell when the cluster is medium/long (nothing short); a mostly-short batch is fine
    # even with a small spread, and the short-floor below handles that case.
    if (( minw > 12 && maxw - minw < 8 )); then
      echo "  x draft lengths too uniform and none short (word range ${minw}-${maxw}) — vary them, make some one short sentence" >&2
      status=1
    fi
  fi

  # 0b/0c/0e) length skew + texture uniformity. Most replies short: long (>18 words) is the rare
  #     exception, and at least ~half the batch must be genuinely short (<=12 words) so the median is
  #     one short sentence. Also a lowercase opener must not be the default move.
  if [ "$n" -ge 3 ]; then
    longn=0; shortn=0; lcop=0
    for d in "${drafts[@]}"; do
      w=$(printf '%s' "$d" | wc -w | tr -d ' ')
      (( w > 18 )) && longn=$((longn+1))
      (( w <= 12 )) && shortn=$((shortn+1))
      first=$(printf '%s' "$d" | sed -E 's/^[[:space:]]*//' | cut -c1)
      case "$first" in [a-z]) lcop=$((lcop+1));; esac
    done
    maxlong=$(( (n + 2) / 3 ))      # ceil(n/3)
    needshort=$(( (n + 1) / 2 ))    # ceil(n/2)
    if (( longn > maxlong )); then
      echo "  x too many long replies ($longn of $n over 18 words; cap $maxlong) — most should be one short sentence" >&2
      status=1
    fi
    if (( shortn < needshort )); then
      echo "  x only $shortn of $n drafts are short (<=12 words); need >= $needshort — most should be one short sentence" >&2
      status=1
    fi
    if (( lcop * 2 > n )); then
      echo "  x $lcop of $n drafts open lowercase — lowercase opener is not the default move; vary the texture (; / - / dropped period / clean)" >&2
      status=1
    fi
  fi

  # 0d) duplicate openers — no two drafts may lead with the same phrase (first 4 words, normalized)
  if [ "$n" -ge 2 ]; then
    openers=""
    for d in "${drafts[@]}"; do
      op=$(printf '%s' "$d" | tr 'A-Z' 'a-z' | tr -cs 'a-z0-9' ' ' | awk '{print $1,$2,$3,$4}')
      case "$openers" in
        *"<<$op>>"*) echo "  x two drafts share the same opening phrase (\"$op …\") — vary the opener even on same-topic targets" >&2; status=1;;
      esac
      openers="$openers<<$op>>"
    done
  fi

  # 1) over-repeated abstraction keywords
  IFS='|' read -ra KWS <<<"$WATCH"
  for kw in "${KWS[@]}"; do
    c=0
    for d in "${drafts[@]}"; do
      printf '%s' "$d" | grep -qiE "$kw" && c=$((c+1))
    done
    if [ "$c" -gt "$max_share" ]; then
      echo "  x '$kw' appears in $c/$n drafts (cap $max_share) — too uniform" >&2
      status=1
    fi
  done

  # 2) pairwise content overlap (shared words >4 chars, crude jaccard-ish)
  for ((i=0;i<n;i++)); do
    for ((j=i+1;j<n;j++)); do
      shared=$(comm -12 \
        <(printf '%s\n' "${drafts[i]}" | tr 'A-Z ' 'a-z\n' | grep -E '.{5,}' | sort -u) \
        <(printf '%s\n' "${drafts[j]}" | tr 'A-Z ' 'a-z\n' | grep -E '.{5,}' | sort -u) \
        | grep -vE "^($WATCH)$" | wc -l | tr -d ' ')
      if [ "${shared:-0}" -ge 7 ]; then
        echo "  x drafts #$((i+1)) and #$((j+1)) share $shared content words — near-duplicate" >&2
        status=1
      fi
    done
  done

  [ "$status" -eq 0 ] && echo "BATCH PASS: variety OK" || echo "BATCH FAIL: rewrite the flagged drafts" >&2
  exit "$status"
fi

# ---------- single-draft mode --------------------------------------------
lenient=0
if [ "${1:-}" = "--lenient" ]; then lenient=1; shift; fi

file="${1:-/dev/stdin}"
draft="$(cat "$file")"
words=$(printf '%s' "$draft" | wc -w | tr -d ' ')

[ "$words" -ge "$MIN" ] || fail "word count below $MIN (words=$words)"
[ "$words" -le "$MAX" ] || fail "word count above $MAX (words=$words)"
case "$draft" in
  *"!"*) fail "contains banned '!'";;
esac

# specificity: at least one digit, OR a known tool, OR a mid-sentence capitalised token
has_signal=0
printf '%s' "$draft" | grep -qE '[0-9]' && has_signal=1
printf '%s' "$draft" | grep -qiE "($TOOLS)" && has_signal=1
printf '%s' "$draft" | grep -qE '[a-z),] +[A-Z][A-Za-z.]+' && has_signal=1

if [ "$has_signal" -eq 0 ]; then
  if [ "$lenient" -eq 1 ]; then
    echo "GATE WARN: no concrete signal (number/tool/proper-noun) — abstract draft (words=$words)" >&2
  else
    fail "no concrete signal — number, tool, or proper noun required (words=$words)"
  fi
fi

echo "GATE PASS: $words words, no '!', concrete signal present"
exit 0

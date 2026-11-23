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
# v2.3 (2026-06-10): additive, --batch mode only. Targets the 2026-06-10 failure
# (the vocabulary varied but the STRUCTURE did not — 5 of 13 drafts used the same
# "[concede] — the real X is [reframe]" skeleton, and an em-dash splice had become
# the default move). Single-draft mode + existing batch checks + thresholds UNCHANGED:
#   * STRUCTURAL-TEMPLATE — too many drafts using the "the real X is" reframe skeleton.
#   * EM-DASH-SPLICE-RATE — the spaced em-dash splice may not be the default move.
#
# v2.4 (2026-06-20): additive, --batch only. SKELETON-SHAPE — too many drafts open concede or
#   close on a narrow aphorism (the 2026-06-20 all-same-skeleton failure, invisible to 0a-0g).
#
# v2.5 (2026-11-23, reply pipeline v3.2): starters are rewritten by the operator on his phone.
#   Single: --type, --max-words (default 40), --anchor, --history, --thread; new checks for a link
#   or hashtag, an internal label, an agreement-only draft, implied experience in a Clean draft,
#   a 4-word run pasted from the anchor and a 5-word run reused from the last 14 days.
#   Batch: the length-cluster, skew-short/long-cap and lowercase-share checks are gone (E8, E12);
#   added "same word count" (more than 2 drafts with one exact count) and the tic cap (each tic
#   on at most 1 draft). There is no check on how many drafts are questions.
#   Fix (2026-11-23): a bare domain with a path (x.com/..., github.com/...) counts as a link;
#   agreement phrases after the opener ("so true", stacked openers, a lone "100%") are not a turn;
#   "100%" opens as agreement only when it stands alone ("100% of the runs ..." is a number).
#   Fix (2026-11-24): the Clean experience check also catches I've/I'm/I'd, "I <adverb> <verb>",
#   "me too" and a sentence that opens on a past-tense experience verb (Tried, Ran, Hit, Saw ...);
#   a question to "you" is not taken for experience on the weaker forms.
#
# Usage:
#   gate.sh [--type deep|clean] [--max-words N] [--anchor FILE] [--history FILE] [--thread FILE]
#           [--lenient] [DRAFT_FILE]     # single-draft check; stdin when no file
#   gate.sh --batch <replies.md>         # cross-draft check over the DRAFT: lines of a file
#
# Single-draft checks, in order (first failure exits 1 with "GATE FAIL: reason"):
#   word count in [5,N]; no "!"; no link or hashtag; no internal label (unless the thread uses
#   the term); not agreement only; --type clean: no implied experience; --anchor: no 4-word run
#   of the anchor; --history: no 5-word run of a history line. "no concrete signal" is a warning.
# Exit: 0 pass, 1 fail, 2 config error.
set -uo pipefail

# Require a real bash >= 4 (mapfile + process substitution). macOS ships bash 3.2 —
# do NOT shim around this; install a modern bash and invoke it. Fail loudly otherwise.
if (( ${BASH_VERSINFO[0]:-0} < 4 )); then
  echo "GATE ERROR: gate.sh needs bash >= 4 (you have ${BASH_VERSINFO[0]:-?}.x). Run: brew install bash, then invoke with it (e.g. /opt/homebrew/bin/bash $0 ...)." >&2
  exit 2
fi

MIN=5
MAX=40

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

  # 0a) same word count: more than 2 drafts with one exact word count (E12).
  declare -A wcount=()
  for d in "${drafts[@]}"; do
    w=$(printf '%s' "$d" | wc -w | tr -d ' ')
    wcount[$w]=$(( ${wcount[$w]:-0} + 1 ))
  done
  for w in "${!wcount[@]}"; do
    if (( wcount[$w] > 2 )); then
      echo "  x same word count: ${wcount[$w]} drafts have exactly $w words (cap 2)" >&2
      status=1
    fi
  done

  # 0b) tic cap: each planted tic on at most 1 draft (reply_register.md; E12, the stricter option).
  semi=0; hyph=0; lcop=0; nofinal=0
  for d in "${drafts[@]}"; do
    printf '%s' "$d" | grep -qE "[A-Za-z];[a-z]" && semi=$((semi+1))
    printf '%s' "$d" | grep -qE ' - ' && hyph=$((hyph+1))
    first=$(printf '%s' "$d" | sed -E 's/^[[:space:]]*//' | cut -c1)
    case "$first" in [a-z]) lcop=$((lcop+1));; esac
    trimmed=$(printf '%s' "$d" | sed -E 's/[[:space:]]+$//')
    if printf '%s' "$trimmed" | grep -qE '[.!?]["'"'"')]?[[:space:]]+[^[:space:]]' \
       && ! printf '%s' "$trimmed" | grep -qE '[.!?]["'"'"')]?$'; then
      nofinal=$((nofinal+1))
    fi
  done
  for pair in "semicolon contraction:$semi" "spaced hyphen:$hyph" "lowercase opener:$lcop" "missing final mark:$nofinal"; do
    name="${pair%:*}"; c="${pair##*:}"
    if (( c > 1 )); then
      echo "  x tic '$name' on $c of $n drafts (cap 1) — plain is the default" >&2
      status=1
    fi
  done

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

  # 0f) structural-template — vocabulary can vary while the skeleton repeats. The 2026-06-10
  #     batch used "[concede] — the real X is [reframe]" five times under distinct words.
  STRUCT='the real (test|lesson|metric|question|problem|unlock) is'
  structn=0
  for d in "${drafts[@]}"; do
    printf '%s' "$d" | grep -qiE "$STRUCT" && structn=$((structn+1))
  done
  maxstruct=$(( (n + 2) / 3 ))   # ceil(n/3)
  if (( structn > maxstruct )); then
    echo "  x $structn of $n drafts use the '[concede] — the real X is [reframe]' skeleton (cap $maxstruct) — vary the structure, not just the vocabulary" >&2
    status=1
  fi

  # 0g) em-dash-splice-rate — the spaced em-dash splice may not be the default move.
  splicen=0
  for d in "${drafts[@]}"; do
    printf '%s' "$d" | grep -qE ' (—|–) ' && splicen=$((splicen+1))
  done
  maxsplice=$(( (n + 1) / 2 ))   # ceil(n/2)
  if (( splicen > maxsplice )); then
    echo "  x em-dash splice in $splicen of $n drafts — it has become the default move; rotate register per reply_register.md" >&2
    status=1
  fi

  # 0h) skeleton-shape — 2026-06-20: vocabulary varied but every draft used concede→specific→aphorism.
  CONCEDE_OPEN='^[[:space:]]*(exactly|same here|same diagnosis|same reason|right,|you.?re right|that.?s real|fair,|agreed,|same )'
  APHORISM='(is just|just means|just whatever|costs more than|stops mattering|disappears|, not )'
  skeln=0
  for d in "${drafts[@]}"; do
    is_skel=0
    printf '%s' "$d" | grep -qiE "$CONCEDE_OPEN" && is_skel=1
    last=$(printf '%s' "$d" | grep -oE '[^.!?]+[.!?]?[[:space:]]*$')
    clause=$(printf '%s' "$last" | sed -E 's/^.+( — | – |: |, )//')
    if printf '%s' "$clause" | grep -qiE "$APHORISM" \
       && ! printf '%s' "$clause" | grep -qE '[0-9]' \
       && ! printf '%s' "$clause" | grep -qE '[a-z),] +[A-Z][A-Za-z.]+'; then
      is_skel=1
    fi
    (( is_skel )) && skeln=$((skeln+1))
  done
  maxskel=$(( (n + 2) / 3 ))   # ceil(n/3)
  if (( skeln > maxskel )); then
    echo "  x $skeln of $n drafts use the concede-opener or generalizing-aphorism-closer skeleton (cap $maxskel) — rotate form: lead with a question, pure data with no closer, disagree, or one blunt sentence" >&2
    status=1
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
lenient=0; type=""; maxw=$MAX; anchor=""; history=""; thread=""; file=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --lenient)   lenient=1; shift ;;
    --type)      type="${2:-}"; shift 2 ;;
    --max-words) maxw="${2:-}"; shift 2 ;;
    --anchor)    anchor="${2:-}"; shift 2 ;;
    --history)   history="${2:-}"; shift 2 ;;
    --thread)    thread="${2:-}"; shift 2 ;;
    -*)          echo "GATE ERROR: unknown option $1" >&2; exit 2 ;;
    *)           file="$1"; shift ;;
  esac
done
case "$type" in ""|deep|clean) ;; *) echo "GATE ERROR: --type must be deep or clean" >&2; exit 2;; esac
[[ "$maxw" =~ ^[0-9]+$ ]] || { echo "GATE ERROR: --max-words needs a number" >&2; exit 2; }
for f in "$anchor" "$history" "$thread"; do
  [ -z "$f" ] || [ -r "$f" ] || { echo "GATE ERROR: cannot read $f" >&2; exit 2; }
done

draft="$(cat "${file:-/dev/stdin}")"
words=$(printf '%s' "$draft" | wc -w | tr -d ' ')

# normalisation for runs: lowercase, every character outside a-z0-9 becomes a space, spaces collapsed
norm() { tr 'A-Z' 'a-z' | tr -c 'a-z0-9' ' ' | tr -s ' ' | sed -E 's/^ //; s/ $//'; }

[ "$words" -ge "$MIN" ] || fail "word count below $MIN (words=$words)"
[ "$words" -le "$maxw" ] || fail "word count above $maxw (words=$words)"
case "$draft" in
  *"!"*) fail "contains banned '!'";;
esac
# a bare domain counts too: a .com or .org name always (docs.anthropic.com), any other name only with
# a path (x.com/user/status/1, github.com/org/repo); a file or app name (libcudart.so, Mail.app) is not
BARE_DOMAIN='(^|[^a-z0-9@.-])([a-z0-9-]+\.)+(com|org)([^a-z0-9-]|$)|(^|[^a-z0-9@.-])([a-z0-9-]+\.)+(com|org|net|io|ai|dev|co|app|ly|gg|xyz|me|tv|so|be|gl|uk|de|sh|gov|edu)/[^[:space:]]'
printf '%s' "$draft" | grep -qiE "https?://|www\.|$BARE_DOMAIN" && fail "contains a link (he types the reply on a phone)"
printf '%s' "$draft" | grep -qE '#[A-Za-z]' && fail "contains a hashtag"

# internal labels a stranger cannot decode, unless the thread itself uses the term
LABELS='E[0-9]-E[0-9]|vault|macro|persona|kernel|injection|loader directive|boot sequence'
while IFS= read -r term; do
  [ -n "$term" ] || continue
  if [ -n "$thread" ] && grep -qiwF -- "$term" "$thread"; then continue; fi
  fail "internal label '$term' (write what the thing is)"
done < <(printf '%s' "$draft" | grep -oiwE "$LABELS" || true)

# agreement only: an agreement opener with nothing that turns, counts or asks
OPENERS="exactly|agreed|agree|so true|well said|spot on|great point|good point|same here|same,|yes,|yep,|right,|true,|totally|100%|couldn['’]t agree more|you['’]re right|that['’]s right"
# "so true", "so much" and stacked openers are more agreement, not a turn: drop them before the turn check.
# "100%" is agreement only when it stands alone ("100%, ...", "100% agree."); "100% of the runs" is a number.
LONE100='100%( agreed?| true| right| this)?[[:space:]]*'
strip_agreement() {
  local s re re100
  s=" $(printf '%s' "$1" | tr 'A-Z' 'a-z') "
  re="([^a-z0-9])(${OPENERS//|100%/}|so (much|real|right))([^a-z0-9])"
  re100="([^a-z0-9])($LONE100)([,.;:]|$)"
  while [[ $s =~ $re100 ]] || [[ $s =~ $re ]]; do
    s="${s/"${BASH_REMATCH[0]}"/${BASH_REMATCH[1]} ${BASH_REMATCH[4]}}"
  done
  printf '%s' "$s"
}
lead=$(printf '%s' "$draft" | sed -E 's/^[[:space:]]*//')
op=$(printf '%s' "$lead" | grep -oiE "^(${OPENERS//|100%/})([^a-z0-9]|$)|^$LONE100([,.;:]|$)" | head -1 || true)
if [ -n "$op" ]; then
  rest=$(strip_agreement "${lead:${#op}}")
  if ! printf '%s' "$rest" | grep -qE '[0-9?]' \
     && ! printf '%s' "$rest" | grep -qiwE 'but|except|until|unless|though|however|because|so|when|if|only|fails?|breaks?|missed|instead'; then
    fail "agreement only (opener '${op%[^a-zA-Z0-9%]}' with nothing added)"
  fi
fi

# Clean: no project fact and no implied experience. Always: my/our/mine, "me too", I/we + verb,
# I/we + adverb + verb, I've/we've. In a sentence that is not a question to "you": I'm/I'd/we're and
# a sentence that opens on a past-tense experience verb ("Tried this...", "Ran into...").
# bin/measure.py implied_experience() applies the same rule for added_experience: keep the two in step.
if [ "$type" = "clean" ]; then
  EXP_VERBS='ran|run|running|built|build|use|used|using|tried|tested|shipped|saw|seen|hit|had|have|keep|kept|wrote|write|measured|found|learned|switched|moved|got'
  ADVERB='also|just|already|once|never|often|always|still|even|first|then|too|[a-z]+ly'
  STRONG="\b(my|our|mine)\b|\bme too\b|\b(i|we)[[:space:]]+(($ADVERB)[[:space:]]+)?($EXP_VERBS)\b|\b(i|we)['’]ve\b"
  WEAK="\b(i['’](m|d)|we['’](re|d))\b|^[[:space:][:punct:]]*(tried|ran|hit|saw|tested|built|shipped|switched|measured|wrote)\b"
  hit=$(printf '%s' "$draft" | grep -oiE "$STRONG" | head -1 || true)
  if [ -z "$hit" ]; then
    while IFS= read -r sent; do
      [ -n "$sent" ] || continue
      case "$sent" in *"?") printf '%s' "$sent" | grep -qiw "you" && continue;; esac
      # "Hit rate ..." is a noun, not an experience verb
      hit=$(printf '%s' "$sent" | sed -E 's/^([[:space:][:punct:]]*)[Hh]it[[:space:]]+rates?/\1rate/' | grep -oiE "$WEAK" | head -1 || true)
      [ -n "$hit" ] && break
    done < <(printf '%s' "$draft" | grep -oE '[^.!?;]+[.!?;]?' || true)
  fi
  [ -z "$hit" ] || fail "implied experience in a Clean draft ('$(printf '%s' "$hit" | sed -E 's/^[[:space:][:punct:]]+//')')"
fi

# word runs shared with the anchor (4) or with a recent reply (5)
read -ra W <<<"$(printf '%s' "$draft" | norm)"
run_in() {  # run_in N HAYSTACK -> prints the first N-word run of the draft found in HAYSTACK
  local k="$1" hay=" $2 " i
  for ((i=0; i+k<=${#W[@]}; i++)); do
    local r="${W[*]:i:k}"
    case "$hay" in *" $r "*) printf '%s' "$r"; return 0;; esac
  done
  return 1
}
if [ -n "$anchor" ]; then
  r=$(run_in 4 "$(norm < "$anchor")") && fail "anchor paste: 4-word run '$r' is in the anchor (say it in new words)"
fi
if [ -n "$history" ]; then
  while IFS= read -r hl; do
    [ -n "$hl" ] || continue
    r=$(run_in 5 "$(printf '%s' "$hl" | norm)") && fail "reused wording: 5-word run '$r' is in a reply of the last 14 days"
  done < "$history"
fi

# specificity: at least one digit, OR a known tool, OR a mid-sentence capitalised token
has_signal=0
printf '%s' "$draft" | grep -qE '[0-9]' && has_signal=1
printf '%s' "$draft" | grep -qiE "($TOOLS)" && has_signal=1
printf '%s' "$draft" | grep -qE '[a-z),] +[A-Z][A-Za-z.]+' && has_signal=1

if [ "$has_signal" -eq 0 ]; then
  echo "GATE WARN: no concrete signal (number/tool/proper-noun) — abstract draft (words=$words)" >&2
fi

if [ "$has_signal" -eq 1 ]; then
  echo "GATE PASS: $words words, no '!', concrete signal present"
else
  echo "GATE PASS: $words words, no '!'"
fi
exit 0

#!/usr/bin/env bash
# debate_loop.sh — REAL cross-family critic<->writer debate, max N rounds (closes GAP-1, PRD §8.1).
#
# Each round: the Critic (cross-family model) attacks the concept ONLY on grounds tied to a
# rubric item or a named gold-standard gap; the Writer (generation model) revises to address it.
# Early-exit when the Critic emits CONSENSUS. The two roles run on DIFFERENT models per turn —
# that cross-family alternation is the adversarial mechanism the single-pass version lacked.
# Writes the full transcript to --out and prints the path.
#
# Usage:
#   debate_loop.sh --concept-file <f> --canon <f> --rubric <f> [--gold <dir>] --out <f> \
#     [--max-rounds 2] [--profile marketing] \
#     --critic-model <id> --critic-provider <p> \
#     --writer-model <id> --writer-provider <p>
#
# Models are passed in (product- and tier-agnostic): use cheap models for a dry run,
# frontier (gpt-5.5 critic / claude-sonnet writer) for the real run. Exit 0 always (debate is
# advisory input to the Judge; a model hiccup logs but never hard-fails the run).
set -uo pipefail

CONCEPT_FILE=""; CANON=""; RUBRIC=""; GOLD=""; OUT=""; MAX=2; PROFILE="marketing"
CM=""; CP=""; WM=""; WP=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --concept-file) CONCEPT_FILE="$2"; shift 2 ;;
    --canon)        CANON="$2"; shift 2 ;;
    --rubric)       RUBRIC="$2"; shift 2 ;;
    --gold)         GOLD="$2"; shift 2 ;;
    --out)          OUT="$2"; shift 2 ;;
    --max-rounds)   MAX="$2"; shift 2 ;;
    --profile)      PROFILE="$2"; shift 2 ;;
    --critic-model) CM="$2"; shift 2 ;;
    --critic-provider) CP="$2"; shift 2 ;;
    --writer-model) WM="$2"; shift 2 ;;
    --writer-provider) WP="$2"; shift 2 ;;
    -h|--help)      sed -n '2,16p' "$0"; exit 0 ;;
    *)              echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done
[[ -n "$CONCEPT_FILE" && -n "$OUT" && -n "$CM" && -n "$CP" && -n "$WM" && -n "$WP" ]] || {
  echo "E2: missing required arg (--concept-file --out --critic-model/provider --writer-model/provider)" >&2; exit 2; }

concept="$(cat "$CONCEPT_FILE" 2>/dev/null)"
canon="$(head -50 "$CANON" 2>/dev/null)"
rubric="$(cat "$RUBRIC" 2>/dev/null)"
[[ -n "$GOLD" && -d "$GOLD" ]] && gold="$(cat "$GOLD"/*.md 2>/dev/null | head -60)" || gold="(none — gold standards HELD)"

call(){ # $1=model $2=provider $3=prompt  -> stdout (best-effort)
  "$PROFILE" -z "$3" -m "$1" --provider "$2" 2>/dev/null || echo "(model call failed — $1)"
}

{ echo "# Debate transcript — $(date +%F)"
  echo "Cross-family loop, max $MAX rounds. Critic=$CM ($CP) ; Writer=$WM ($WP). (PRD §8.1)"; } > "$OUT"

round=1
while [[ "$round" -le "$MAX" ]]; do
  cprompt=$(printf 'You are the cross-family CRITIC of a video_short concept. Attack it ONLY on grounds tied to a specific RUBRIC item or a named GOLD-STANDARD gap — no free-floating opinions. Be concrete and brief. If no material weakness remains, reply with exactly the single word: CONSENSUS\n\n=== RUBRIC ===\n%s\n\n=== CANON (excerpt) ===\n%s\n\n=== GOLD STANDARDS ===\n%s\n\n=== CONCEPT ===\n%s' "$rubric" "$canon" "$gold" "$concept")
  attack=$(call "$CM" "$CP" "$cprompt")
  printf '\n## Round %s — Critic (%s)\n%s\n' "$round" "$CM" "$attack" >> "$OUT"
  if printf '%s' "$attack" | grep -qiw 'CONSENSUS'; then
    printf '\n_Consensus reached at round %s — loop ends early._\n' "$round" >> "$OUT"; break
  fi
  wprompt=$(printf 'You are the WRITER. Revise the video_short concept to ADDRESS the Critic attack below, staying strictly on-brand to CANON (no operator voice; voice = channel x audience x trend). Output ONLY the revised concept.\n\n=== CANON (excerpt) ===\n%s\n\n=== CRITIC ATTACK ===\n%s\n\n=== CURRENT CONCEPT ===\n%s' "$canon" "$attack" "$concept")
  revision=$(call "$WM" "$WP" "$wprompt")
  printf '\n## Round %s — Writer (%s)\n%s\n' "$round" "$WM" "$revision" >> "$OUT"
  concept="$revision"
  round=$((round + 1))
done

printf '\n## Final concept (post-debate, for the Judge)\n%s\n' "$concept" >> "$OUT"
echo "debate complete -> $OUT"
exit 0

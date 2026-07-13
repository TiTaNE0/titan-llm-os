#!/usr/bin/env bash
# audit_authority.sh — citation-existence audit of project_authority.md.
# For each `### <ID>` entry: resolve cited evidence (first backtick vault path,
# else passport 01_Projects/<project>.md) and test it exists. OK/NEEDS-ATTENTION
# per entry + summary; exit 0 iff all resolve.
# SCOPE: citation EXISTENCE only — does NOT verify substance/numbers appear in the
# cited file (that deep match is the periodic manual/LLM layer, see PRD Vault_Scout).
# Usage: audit_authority.sh [project_authority.md]  · Exit: 0 all ok · 1 some · 2 cannot run
set -uo pipefail
FILE="${1:-project_authority.md}"
[ -f "$FILE" ] || { echo "audit_authority: cannot read $FILE" >&2; exit 2; }
start="$(cd "$(dirname "$FILE")" && pwd -P)"
VAULT=""; d="$start"
while [ "$d" != "/" ]; do [ -d "$d/01_Projects" ] && { VAULT="$d"; break; }; d="$(dirname "$d")"; done
[ -n "$VAULT" ] || VAULT="$(git -C "$start" rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$VAULT" ] || { echo "audit_authority: cannot locate vault root (no 01_Projects/ ancestor)" >&2; exit 2; }
resolve_exists() {
  local t="$1"
  [ -f "$VAULT/$t" ]    && { echo "$t"; return 0; }
  [ -f "$VAULT/$t.md" ] && { echo "$t.md"; return 0; }
  [ -d "$VAULT/$t" ]    && { echo "$t/"; return 0; }
  ( set -- "$VAULT/$t"*; [ -e "$1" ] ) && { echo "$t* (glob)"; return 0; }
  return 1
}
N=0; M=0; K=0; ID=""; PROJECT=""; EVIDENCE=""; HAS_EV=0
flush() {
  [ -n "$ID" ] || return 0
  case "$ID" in *"<"*|*">"*) ID=""; return 0;; esac
  N=$((N+1))
  if [ "$HAS_EV" -eq 0 ]; then echo "NEEDS-ATTENTION $ID no-evidence-line"; K=$((K+1)); return 0; fi
  local target=""
  case "$EVIDENCE" in *'`'*) target="${EVIDENCE#*\`}"; target="${target%%\`*}";; esac
  case "$target" in
    */*|01_Projects*|04_Logs*|05_Marketing_System*|06_Research*|03_Brain*) ;;
    *) target="";;
  esac
  if [ -z "$target" ]; then
    if [ -n "$PROJECT" ]; then target="01_Projects/$PROJECT.md"
    else echo "NEEDS-ATTENTION $ID no-evidence-path-and-no-project"; K=$((K+1)); return 0; fi
  fi
  local resolved
  if resolved="$(resolve_exists "$target")"; then echo "OK $ID $resolved"; M=$((M+1))
  else echo "NEEDS-ATTENTION $ID missing: $target"; K=$((K+1)); fi
}
while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in
    "### "*) flush; ID="${line#"### "}"; ID="${ID%% —*}"; ID="${ID%% -*}"; ID="${ID%% *}"; PROJECT=""; EVIDENCE=""; HAS_EV=0 ;;
    *"- project:"*)  PROJECT="${line#*- project:}";  PROJECT="$(printf '%s' "$PROJECT" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')" ;;
    *"- evidence:"*) EVIDENCE="${line#*- evidence:}"; HAS_EV=1 ;;
  esac
done < "$FILE"
flush
echo "$N entries, $M ok, $K need-attention"
[ "$K" -eq 0 ] && exit 0 || exit 1

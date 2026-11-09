#!/usr/bin/env bash
# telemetry_start.sh — persist a phase start (epoch-ms) so a later
# `emit_telemetry.sh <macro> <status> auto ... <task>` can compute the duration.
# Shell variables do not survive between an agent's Bash calls; a file does.
#
# Usage: telemetry_start.sh <macro> [task]
# Writes ${TELEMETRY_DIR:-<vault>/04_Logs/Telemetry}/.timers/<macro_key>__<task_key>.tmp
# Exit always 0, prints nothing — telemetry must never block a macro.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TELEMETRY_DIR="${TELEMETRY_DIR:-$VAULT_DIR/04_Logs/Telemetry}"
TIMER_DIR="$TELEMETRY_DIR/.timers"
TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

refuse() {
  mkdir -p "$TELEMETRY_DIR" 2>/dev/null || true
  printf '%s\tnote\ttimer-reject:%s\n' "$TS" "$1" \
    >> "$TELEMETRY_DIR/.write_failures.log" 2>/dev/null || true
  exit 0
}

[ "$#" -ge 1 ] && [ "$#" -le 2 ] || refuse "bad-arg-count:$#"
for a in "$@"; do case "$a" in --*) refuse "flag-style-arg:$a";; esac; done

MACRO="$1"
TASK="${2:-}"
case "$TASK" in '[['*']]') TASK="${TASK#\[\[}"; TASK="${TASK%\]\]}";; esac
[ "$TASK" = "null" ] && TASK=""

# Must stay identical to key() in emit_telemetry.sh.
key() {
  local k
  k="$(printf '%s' "$1" | LC_ALL=C tr -c 'A-Za-z0-9_.-' '_')"
  [ -n "$k" ] || k="_"
  printf '%s' "$k"
}

mkdir -p "$TIMER_DIR" 2>/dev/null || exit 0
TARGET="$TIMER_DIR/$(key "$MACRO")__$(key "$TASK").tmp"
TMPF="$(mktemp "$TIMER_DIR/.start.XXXXXX" 2>/dev/null)" || exit 0
if printf '%s\n' "$(( $(date +%s) * 1000 ))" > "$TMPF" 2>/dev/null; then
  mv -f "$TMPF" "$TARGET" 2>/dev/null || rm -f "$TMPF"
else
  rm -f "$TMPF"
fi
exit 0

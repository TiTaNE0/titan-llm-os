#!/usr/bin/env bash
set -euo pipefail

# safe_append.sh — APPEND-ONLY writer for LEDGER / DECISIONS / ANALYTICS.
# Inserts --entry immediately AFTER the "append below this line" HTML comment
# marker, or at EOF if no marker exists. Never edits or reorders existing lines.
# Atomic via temp file + mv. Exit 0 = appended; non-zero = failure.

usage() {
  cat <<'EOF'
Usage: safe_append.sh --file <abs path> --entry <text>

Append-only insert of <text> into an append-only campaign file.
The line is placed just after the marker:
  <!-- ... append below this line ... -->
or at EOF if the file has no such marker. Existing lines are never changed.

Exit codes:
  0  entry appended
  2  usage / file error
  1  write failure
EOF
}

FILE=""
ENTRY=""
ENTRY_SET=0
while [ $# -gt 0 ]; do
  case "$1" in
    --file)  FILE="${2:-}"; shift 2 ;;
    --entry) ENTRY="${2:-}"; ENTRY_SET=1; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [ -z "$FILE" ] || [ "$ENTRY_SET" -ne 1 ]; then
  echo "error: --file and --entry are required" >&2
  usage >&2
  exit 2
fi
if [ ! -f "$FILE" ]; then
  echo "error: file not found: $FILE" >&2
  exit 2
fi
if [ ! -w "$FILE" ]; then
  echo "error: file not writable: $FILE" >&2
  exit 2
fi

tmp="$(mktemp "${TMPDIR:-/tmp}/safe_append.XXXXXX")" || {
  echo "error: could not create temp file" >&2
  exit 1
}
trap 'rm -f "$tmp"' EXIT

# Marker line number (first match), if any.
marker_ln="$(grep -niE 'append below this line' "$FILE" | head -n1 | cut -d: -f1 || true)"

if [ -n "$marker_ln" ]; then
  # Copy lines 1..marker, then the entry, then the remainder. No reordering.
  awk -v ln="$marker_ln" -v entry="$ENTRY" '
    { print }
    NR == ln { print entry }
  ' "$FILE" > "$tmp" || { echo "error: awk insert failed" >&2; exit 1; }
else
  # No marker: append at EOF. Ensure a trailing newline first.
  cp "$FILE" "$tmp" || { echo "error: copy failed" >&2; exit 1; }
  if [ -s "$tmp" ] && [ "$(tail -c1 "$tmp" | wc -l)" -eq 0 ]; then
    printf '\n' >> "$tmp"
  fi
  printf '%s\n' "$ENTRY" >> "$tmp" || { echo "error: append failed" >&2; exit 1; }
fi

mv "$tmp" "$FILE" || { echo "error: atomic mv failed" >&2; exit 1; }
trap - EXIT

echo "OK: appended 1 entry to $FILE"
exit 0

#!/usr/bin/env bash
# migrate_tasks_to_subfolders.sh
# Reorganizes task files from flat 02_Tasks/ and 99_Archive/Tasks/2026/
# into per-project subfolders matching 01_Projects/<Project>.md basenames.
#
# Usage:
#   bash migrate_tasks_to_subfolders.sh           # DRY-RUN (default)
#   bash migrate_tasks_to_subfolders.sh --apply   # execute moves

set -euo pipefail

APPLY="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ACTIVE="$ROOT/02_Tasks"
ARCHIVE="$ROOT/99_Archive/Tasks/2026"
PROJECTS_DIR="$ROOT/01_Projects"

if [[ ! -d "$PROJECTS_DIR" ]]; then
  echo "ERROR: $PROJECTS_DIR not found" >&2
  exit 1
fi

# Canonical project allowlist (basename of 01_Projects/*.md, sans .md).
# Portable to bash 3.2 (macOS) — no `mapfile`.
PROJECTS=()
while IFS= read -r -d '' f; do
  PROJECTS+=("$(basename "$f" .md)")
done < <(find "$PROJECTS_DIR" -maxdepth 1 -name '*.md' -print0)

is_canonical() {
  local needle="$1"
  for p in "${PROJECTS[@]}"; do
    [[ "$p" == "$needle" ]] && return 0
  done
  return 1
}

# Reads project name from a task file. Returns project basename or empty.
# Lenient — scans the YAML-like region at the top of the file (first 30 lines
# OR until the first `# ` markdown heading, whichever comes first), regardless
# of whether the file has proper `---` frontmatter delimiters. Many older task
# files in the vault have YAML-like keys at the top WITHOUT `---` markers.
#
# Handles all observed YAML shapes:
#   project: [[X]]
#   project: X
#   project:
#     - - X        (nested list — present in 3+ files)
#   project:
#     - X          (flat list)
extract_project() {
  awk '
    BEGIN { in_proj = 0; lines = 0 }
    {
      lines++
      if (lines > 30) exit
      if (match($0, /^#[[:space:]]/)) exit  # body started, no project found
      if ($0 == "---") next                 # tolerate frontmatter delimiters

      # Inline form: project: [[X]]
      if (match($0, /^project:[[:space:]]*\[\[/)) {
        s = substr($0, RSTART + RLENGTH)
        sub(/\]\].*/, "", s)
        gsub(/[[:space:]]/, "", s)
        if (s != "") { print s; exit }
        in_proj = 1
        next
      }
      # Inline form: project: X (no brackets)
      if (match($0, /^project:[[:space:]]+[^[:space:]]/)) {
        s = $0
        sub(/^project:[[:space:]]+/, "", s)
        gsub(/[\[\]"'\'']/, "", s)
        gsub(/[[:space:]]/, "", s)
        if (s != "") { print s; exit }
      }
      # Multi-line form: bare "project:"
      if (match($0, /^project:[[:space:]]*$/)) { in_proj = 1; next }
      if (in_proj) {
        # Nested list:    - - X
        if (match($0, /^[[:space:]]*-[[:space:]]+-[[:space:]]+/)) {
          s = $0
          sub(/^[[:space:]]*-[[:space:]]+-[[:space:]]+/, "", s)
          gsub(/[\[\]"'\'']/, "", s)
          gsub(/[[:space:]]/, "", s)
          if (s != "") { print s; exit }
        }
        # Flat list:      - X
        if (match($0, /^[[:space:]]*-[[:space:]]+/)) {
          s = $0
          sub(/^[[:space:]]*-[[:space:]]+/, "", s)
          gsub(/[\[\]"'\'']/, "", s)
          gsub(/[[:space:]]/, "", s)
          if (s != "") { print s; exit }
        }
        # Another top-level YAML key encountered: stop searching project block
        if (match($0, /^[a-zA-Z_]/)) { in_proj = 0 }
      }
    }
  ' "$1"
}

normalize() {
  case "$1" in
    intuiscale_project) echo "Intuiscale" ;;
    *) echo "$1" ;;
  esac
}

migrate_dir() {
  local SRC="$1"
  local label="$2"
  local count_total=0
  local count_routed=0
  local count_unassigned=0

  if [[ ! -d "$SRC" ]]; then
    echo "SKIP: $SRC does not exist"
    return 0
  fi

  echo ""
  echo "=== $label ($SRC) ==="

  while IFS= read -r -d '' f; do
    count_total=$((count_total + 1))
    local raw target dest
    raw=$(extract_project "$f" | head -n 1)
    target=$(normalize "$raw")
    if [[ -z "$target" ]] || ! is_canonical "$target"; then
      target="_Unassigned"
      count_unassigned=$((count_unassigned + 1))
      printf 'UNASSIGNED: %s (raw=%q)\n' "$(basename "$f")" "$raw"
    else
      count_routed=$((count_routed + 1))
    fi
    dest="$SRC/$target/$(basename "$f")"

    if [[ "$APPLY" == "--apply" ]]; then
      mkdir -p "$SRC/$target"
      mv -n "$f" "$dest"
    else
      printf 'PLAN: %s -> %s/%s\n' "$(basename "$f")" "$target" "$(basename "$f")"
    fi
  done < <(find "$SRC" -maxdepth 1 -name '*.md' -print0)

  echo "--- $label summary: total=$count_total routed=$count_routed unassigned=$count_unassigned"
}

echo "Migration mode: ${APPLY:-DRY-RUN}"
echo "Canonical projects: ${PROJECTS[*]}"

migrate_dir "$ACTIVE" "ACTIVE"
migrate_dir "$ARCHIVE" "ARCHIVE"

echo ""
if [[ "$APPLY" == "--apply" ]]; then
  echo "Done. Run verification suite next."
else
  echo "Dry-run complete. Re-run with --apply to execute."
fi

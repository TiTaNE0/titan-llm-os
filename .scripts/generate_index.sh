#!/bin/bash

# Internal Index Generator for TiTan LLM OS
# Generates Internal_Index.md with one-line summaries for LLM-optimized navigation
# Ignores: .obsidian, .git, .agent, 99_Archive directories

VAULT_ROOT="$(dirname "$(dirname "$(realpath "$0")")")"
OUTPUT_FILE="$VAULT_ROOT/Internal_Index.md"
TEMP_FILE="/tmp/internal_index_$$"

# Header
echo "# TiTan LLM OS - Internal Index (LLM Optimized)" > "$TEMP_FILE"
echo "# Last Updated: $(date)" >> "$TEMP_FILE"
echo "" >> "$TEMP_FILE"

# Find all markdown files, excluding specified directories
find "$VAULT_ROOT" -name "*.md" \
  -not -path "*/.obsidian/*" \
  -not -path "*/.git/*" \
  -not -path "*/.agent/*" \
  -not -path "*/99_Archive/*" \
  -not -path "*/00_Inbox copy/*" \
  -not -path "*/02_Tasks/*" | sort | while read -r file; do
  
  # Get relative path from vault root
  rel_path="${file#$VAULT_ROOT/}"
  
  # Extract summary using hierarchy
  summary=""
  
  # 1. Try YAML frontmatter title
  if [[ "$(head -10 "$file")" =~ ^[[:space:]]*title:[[:space:]]*(.+)$ ]]; then
    summary="${BASH_REMATCH[1]}"
  fi
  
  # 2. Try first H1 heading
  if [[ -z "$summary" ]]; then
    summary=$(grep -m 1 '^# ' "$file" | sed 's/^# //')
  fi
  
  # 3. Try first meaningful sentence (after YAML/headings)
  if [[ -z "$summary" ]]; then
    # Skip YAML frontmatter if present
    content=$(awk '/^---$/ {skip=1; next} !skip && /^---$/ {skip=0; next} !skip' "$file" 2>/dev/null || echo "$(cat "$file")")
    # Get first non-empty line that looks like a sentence (has letters and ends with punctuation or is reasonable length)
    summary=$(echo "$content" | grep -m 1 -v '^$' | grep -v '^#' | head -1 | sed -E 's/^[[:space:]]+//' | sed -E 's/[[:space:]]+$//' | sed -E 's/[[:space:]]+/ /g')
    
    # If we got something reasonable, use it
    if [[ -n "$summary" && ${#summary} -gt 5 ]]; then
      # Truncate to first sentence if it's too long
      summary=$(echo "$summary" | sed -E 's/([.!?]).*$/\1/')
    else
      summary=""
    fi
  fi
  
  # 4. Fallback to filename
  if [[ -z "$summary" ]]; then
    filename=$(basename "$file" .md)
    # Convert snake_case/kebab-case to readable format and title case
    summary=$(echo "$filename" | sed -E 's/[-_]/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)} 1')
  fi
  
  # Clean up summary: limit length, remove extra whitespace
  summary=$(echo "$summary" | sed -E 's/[[:space:]]+/ /g' | sed -E 's/^[[:space:]]+//' | sed -E 's/[[:space:]]+$//')
  
  # Truncate if too long (keep it dense for LLM)
  if [[ ${#summary} -gt 100 ]]; then
    summary=$(echo "$summary" | cut -c1-97)"..."
  fi
  
  # Output in required format
  echo "[[$rel_path]] - $summary" >> "$TEMP_FILE"
done

# Move temp file to final location
mv "$TEMP_FILE" "$OUTPUT_FILE"

echo "Internal Index generated: $OUTPUT_FILE"
echo "Total files indexed: $(wc -l < "$OUTPUT_FILE" | tr -d ' ') entries"
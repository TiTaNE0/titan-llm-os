# Index Generator Implementation Plan

## Approach
Implement as bash script using standard CLI tools (find, awk, sed) with zero dependencies.

## Directories to Ignore
- .obsidian (application data)
- .git (version control)  
- .agent (agent-specific data)
- 99_Archive (cold storage/archive)
- 00_Inbox copy (duplicate inbox)
- 02_Tasks (task files - though this might be debatable, but following the original script)

## Summary Extraction Hierarchy
1. YAML frontmatter `title:` field
2. First H1 heading (`# Heading`)
3. First meaningful sentence after headings/YAML
4. Filename without extension (converted from snake_case/kebab-case)

## Output Format
`[[Relative/Path/To/File.md]] - One sentence summary.`

## Verification
- Script generates Internal_Index.md at vault root
- Correctly formatted output
- Excluded directories don't appear
- Clean, accurate summaries
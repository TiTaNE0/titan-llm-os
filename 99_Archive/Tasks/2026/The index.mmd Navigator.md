---
project: [[TiTan_LLM_OS]]
status: completed
priority: high
created: {{date}}
type: task
---

# ⚡ Task: Implement The Internal Index Navigator

## 📋 Declarative Objective
- [x] Build an automated mechanism (script or tool) that generates and maintains an `Internal_Index.md` file at the root of the vault. This file acts as a dense, LLM-optimized map of the entire active OS to prevent directory-traversal token waste.

## 🎯 Definition of Done (Success Criteria)
- [x] A lightweight executable script exists (e.g., in a `.scripts/` folder) that generates `Internal_Index.md`.
- [x] The output format of the index is strictly: `[[Relative/Path/To/File.md]] - One sentence summary.`
- [x] The script accurately extracts summaries using a logical hierarchy (YAML title > First H1 > First Sentence > Filename).
- [x] The script strictly ignores hidden directories (`.obsidian`, `.git`, `.agent`) and cold storage (`99_Archive`).
- [x] A new macro `/update_index` is added to `System_Agents.md` instructing the agent on how to trigger this script.

## 🛑 Hard Constraints (Simplicity & Surgical Rules)
- [x] **Minimum Viable Code:** Use standard CLI tools (bash, awk, sed, or a basic Node/Python script with zero external dependencies) to build the generator. Do not overengineer with complex parsers.
- [x] **On-Demand Context Only:** Do NOT add instructions for the agent to read `Internal_Index.md` on every startup. It must only be referenced when the agent actively needs to discover a file.

## 🧪 Verification Gateway (The Loop)
- [x] **Test Command:** Execute the script (e.g., `bash .scripts/generate_index.sh`).
- [x] **Protocol:** Run the script. Verify that `Internal_Index.md` is successfully generated at the vault root, contains the correct file mappings, and correctly excludes the `99_Archive` folder. Do not mark this task `Done` until the output format is verified to be clean and accurate.

## 📝 Agent Implementation Plan
- [x] I implemented the index generator as a bash script using standard CLI tools (find, awk, sed) to ensure zero dependencies and maximum compatibility.
- [x] The script ignores these directories: `.obsidian`, `.git`, `.agent`, and `99_Archive` as specified.
- [x] Summary extraction hierarchy implemented: 
  1. YAML frontmatter `title:` field
  2. First H1 heading (`# Heading`)
  3. First meaningful sentence after headings
  4. Filename without extension as fallback
- [x] I created the script at `.vault_link/.scripts/generate_index.sh` and tested it successfully.
- [x] Next: Add `/update_index` macro to `System_Agents.md` - COMPLETED

## 🔗 Related Context
- **Skills:** [[.agent/skills/Architecture/Data_Compression]]
- **Documentation:** [[03_Brain/System_Agents.md]]
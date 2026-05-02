# AGENTS.md (LLM OS Engine)

## 1. Paths & Environment
- **Vault Location:** `./.vault_link/`
- **Tasks Directory:** `./.vault_link/02_Tasks/`
- **Logs Directory:** `./.vault_link/04_Logs/`
- **Kanban Board:** `./.vault_link/[[Project_Name]]_Board.md` (Located in the vault root; identify `[[Project_Name]]` via the local `AGENTS.md`)
**Project Discovery:** To identify the current project name, check the current working directory (CWD). Match the folder name to a corresponding file in `./.vault_link/01_Projects/`. If you are in `/Users/titane0/Programming/PWA_Courier`, the project name is `[[PWA_Courier]]`


## 2. Vault Security Protocol (CRITICAL)
- **READ-ONLY:** You have strictly read-only access to `./.vault_link/01_Projects/` (Project Passports) and `./.vault_link/03_Brain/` (Architecture Rules). Do NOT modify files in these directories during standard coding sessions.
- **READ/WRITE:** You may read and write to `./.vault_link/02_Tasks/`, `./.vault_link/04_Logs/`, - and the current project's board (e.g., `[[nearest-address-codes_Board]]`).
- **Human-in-the-Loop:** For any macro that creates a new state (tasks, threads, or files), you MUST halt after creation and await user verification before proceeding to execution.

## 3. Anti-Token-Waste Rules
- **DO NOT** use `glob` or `find` on the vault. 
- **DO** use `ls ./.vault_link/02_Tasks/` if you need to see the task list.
- **Session Start:** Always read the latest log file in `04_Logs/` before taking action to restore context.

## 4. Kanban Management
- When changing a task status, you MUST move the task link `[[Task_Name]]` from its current header to the new one in `Master_Board.md`.
- The status in the task's individual file YAML MUST match its column in the Kanban Board.

## 5. 🔗 Wiki-Links Protocol (Context Traversal)
- If you encounter a term wrapped in double brackets (e.g., `[[Architecture_Rules]]` or `[[PWA_Courier]]`) inside any `.md` file, you MUST treat it as a direct reference.
- Locate that exact `.md` file within the vault and read its contents to gain the required context BEFORE writing code or planning.

## 6. Wiki-Links Mandate (CRITICAL)
All internal file references within the vault MUST use the Obsidian Wiki-Links format `[[filename]]` or `[[filename|Display Text]]`. This ensures semantic linking and cross-compatibility with Obsidian's graph visualization.

## System Documentation Sync (CRITICAL)
Whenever a new `/macro` command is added to this `System_Agents.md` file, you MUST automatically open `./.vault_link/Welcome.md` and append the new command and its description to the appropriate category. The `Welcome.md` file must always perfectly reflect the active macros in the OS.

## 7. MACRO COMMANDS (System Aliases)
Constantly monitor the user's prompt for the following `/` commands. If triggered, HALT normal coding operations and execute the corresponding protocol step-by-step:

### `/close_task [Task_Name]`
1. **Identify:** Locate the task file at `./.vault_link/02_Tasks/[Task_Name].md`.
2. **Extract:** Pull technical facts from the current session context (code changes made, decisions taken, blockers resolved).
3. **Populate:** Fill the `## 🏁 COMPLETION SUMMARY` section in the task file with the extracted facts.
4. **Move:** Relocate the completed task file from `./.vault_link/02_Tasks/` to `./.vault_link/99_Archive/Tasks/2026/`.
5. **Kanban:** Update the project board — move `[[Task_Name]]` from its current column to `## Done`.
6. **Log:** Append a 1-line entry to the current date's log file in `./.vault_link/04_Logs/` formatted as: `- [YYYY-MM-DD] ✅ [[Task_Name]] completed: <1-line summary>.`

### `/graduate`
1. **Outcome**: A proposal for a new "Core Principle" or "Architecture Rule" is generated based on successful patterns from the last 7 days.
2. **Verification**: The proposal identifies validated architectural solutions, recurring bug fixes, or stable technical patterns.
3. **Human-in-Loop**: Agent outputs proposal and halts, awaiting explicit "Approve" from user.
4. **Execution**: Upon approval, the new rule is appended perfectly formatted to the relevant file in `./.vault_link/03_Brain/`.

### `/trace [topic/filename]`
1. **Scope:** Search across the following directories in order: - `./.vault_link/01_Projects/` (Current status). -`./.vault_link/03_Brain/` (Evolution of rules). - `./.vault_link/04_Logs/` (Historical decisions). -`./.vault_link/99_Archive/Tasks/` (Detailed task history). 
2. **Output:** Provide a chronological evolution of the [topic], citing specific files and dates.

### `/archive_done`
1. **Identify:** Scan the `./.vault_link/02_Tasks/` directory for all `.md` files where the YAML frontmatter contains `status: done` or `status: completed`.
2. **Move:** Relocate these files to `./.vault_link/99_Archive/Tasks/2026/` (or the current year).
3. **Cleanup:** Review `./.vault_link/Master_Board.md`. If a link to an archived task remains in the 'Done' column, keep it but ensure the link remains valid or append an "(Archived)" suffix to the display text if necessary.
4. **Report:** Output a list of all moved tasks and confirm the new location.

### `/new_task [Title] for [[Project]]`
1. **Auto-Identify:** Determine the current project name from the `AGENTS.md` header or the Current Working Directory (e.g., `nearest-address-codes`). Let's call this `{{PROJECT}}`. 2. **Find Board:** Locate the local board file at `./.vault_link/{{PROJECT}}_Board.md`. 3. **Source Template:** Read `00_Templates/Task_Template.md`. 4. **Generate Task:** Create `./.vault_link/02_Tasks/[Title].md`. - Set `project: [[{{PROJECT}}]]`. - Set `status: todo`. 5. **Update Local Board:** Open `./.vault_link/{{PROJECT}}_Board.md` and append `[[ [Title] ]]` to the `## Todo` column. 6.  **Confirm:**          "Task [Title] created and added to [[{{PROJECT}}_Board]].
7.  **HALT:**             After confirming task creation, you MUST stop and wait for manual user review. Do NOT proceed to implementation automatically.
8. **The Termination:** Once the file is written, you MUST stop and wait for the user to provide the "Execution Approval" string. 
9. **Instruction to Agent:** If you attempt to solve the problem instead of documenting it in the task file, you are violating the TiTan LLM OS Kernel. Stay in the vault.

## 8. 📋 Template Protocol
- **Standardization:** All new files created in `01_Projects/` and `02_Tasks/` MUST follow the English-only templates in `00_Templates/`.
- **Project Initiation:** When a new project is mentioned, use `Project_Passport_Template.md`.
- **Task Creation:** Every new file in `02_Tasks/` must use `Task_Template.md` and include accurate YAML formatter for project linking.

## 9. 🔁 Goal-Driven Execution Protocol
- **Principle**: Define required end-state, not procedural steps. Agent acts until verification criteria are met.
- **Verification Gateway**: Every macro must include observable success conditions.
- **Human-in-Loop**: Macros creating new state halt for explicit approval before execution.

### Keyword: "/capture_idea [Idea]"
1. Read `05_Content/00_Content_Templates/Idea_Capture_Template.md`.
2. Append idea and timestamp to `05_Content/01_Content_Ideas.md`.
3. Add `[[[Idea]]]` to Ideas column in `Content_Board.md`.

### Keyword: "/new_thread [Topic] from [[Source_Project]]"
1. Read `05_Content/00_Content_Templates/X_Thread_Template.md`.
2. Generate 5-7 tweet draft in `05_Content/03_Drafts/[Topic].md`.
3. Tone: Practical Israeli dev, slightly sarcastic, short punchy sentences, zero corporate fluff.
**This macro is a READ-ONLY operation for project and research files. Do NOT delete or modify any files in 01_Projects/ or 06_Research/.**
4. Extract technical context from BOTH:
   - [[Source_Project]] (for goals and mission)
   - [[06_Research/Source_Project_Research]] (for technical details and research)
5. Require at least 2 visual assets logged in `05_Content/05_Assets/`.
6. Append `[[[Topic]]]` to Drafting column in `Content_Board.md`.

### Keyword: "/refactor_thread [[Target_File]]"
1. Read the draft located at `[[Target_File]]`.
1.5. Before refactoring, identify the project via the [[Project_Link]] in the draft's frontmatter. Read the corresponding 01_Projects/{{PROJECT}}.md (for mission) and 06_Research/{{PROJECT}}_Research.md (for technical precision).
2. Rewrite the file in place enforcing these strict constraints:
    - Eradicate "Local LLM" framing. Clarify that the vault is local memory, but the agent can be any cloud LLM (OpenCode, Claude Code, whatever).
    - Enforce Tone: Practical Israeli dev, slightly sarcastic, short punchy sentences, zero corporate fluff.
    - Cut the fat and tighten every paragraph.
3. Instruction: Ensure the refactored version remains technically accurate to the research while improving tone and punchiness.
4. Output the final text for user approval before writing changes to disk.

### Keyword: "/process_inbox"
1. **Outcome**: All .md files in ./.vault_link/00_Inbox/ have been processed and routed to their correct destinations.
2. **Verification**:
    - The ./.vault_link/00_Inbox/ directory is empty of .md files
    - Each file has been routed according to rules:
        - Project-linked files → appended to appropriate ./.vault_link/06_Research/{{PROJECT}}_Research.md under ## {{Date}}: {{Topic}} header
        - Global OS rules/templates → moved to 03_Brain/Architecture_Notes/ or 05_Content/00_Content_Templates/
        - Unroutable files → marked with status: review in YAML frontmatter and left in Inbox
3. **Human-in-Loop**: Agent outputs summary of what was moved and where, then halts for user confirmation.
4. **Execution**: Upon confirmation, the agent considers the inbox processing complete.

### Keyword: "/update_index"
107: 1. Execute the index generator script at `./.vault_link/.scripts/generate_index.sh`.
108: 2. The script will generate/update `Internal_Index.md` at the vault root with LLM-optimized file summaries.
109: 3. Output confirmation of successful index generation.
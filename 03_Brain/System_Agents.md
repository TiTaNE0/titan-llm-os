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

### `/close_day`
1. Analyze the uncommitted `git diff` in the current repository.
2. Review the Kanban board at `./.vault_link/{{PROJECT}}_Board.md`. Move any completed tasks to 'Done'.
3. Write a concise, bulleted summary of today's actual code changes, decisions, and resolved blockers to the current date's log file in `./.vault_link/04_Logs/`.

### `/graduate`
1. Scan the log files in `./.vault_link/04_Logs/` for the last 7 days.
2. Identify any successful architectural solutions, recurring bug fixes, or new technical patterns that have proven stable.
3. Output a proposal for a new "Core Principle" or "Architecture Rule" based on these findings.
4. WAIT for the user to reply "Approve". 
5. If approved, append the new rule perfectly formatted to the relevant file in `./.vault_link/03_Brain/`.

### `/trace [topic/filename]`
1. **Scope:** Search across the following directories in order: - `./.vault_link/01_Projects/` (Current status). -`./.vault_link/03_Brain/` (Evolution of rules). - `./.vault_link/04_Logs/` (Historical decisions). -`./.vault_link/99_Archive/Tasks/` (Detailed task history). 
2. **Output:** Provide a chronological evolution of the [topic], citing specific files and dates.

### `/archive_done`
1. **Identify:** Scan the `./.vault_link/02_Tasks/` directory for all `.md` files where the YAML frontmatter contains `status: done`.
2. **Move:** Relocate these files to `./.vault_link/99_Archive/Tasks/2026/` (or the current year).
3. **Cleanup:** Review `./.vault_link/Master_Board.md`. If a link to an archived task remains in the 'Done' column, keep it but ensure the link remains valid or append an "(Archived)" suffix to the display text if necessary.
4. **Report:** Output a list of all moved tasks and confirm the new location.

### `/new_task [Title] for [[Project]]`
1. **Auto-Identify:** Determine the current project name from the `AGENTS.md` header or the Current Working Directory (e.g., `nearest-address-codes`). Let's call this `{{PROJECT}}`. 2. **Find Board:** Locate the local board file at `./.vault_link/{{PROJECT}}_Board.md`. 3. **Source Template:** Read `00_Templates/Task_Template.md`. 4. **Generate Task:** Create `./.vault_link/02_Tasks/[Title].md`. - Set `project: [[{{PROJECT}}]]`. - Set `status: todo`. 5. **Update Local Board:** Open `./.vault_link/{{PROJECT}}_Board.md` and append `[[ [Title] ]]` to the `## Todo` column. 6.  **Confirm:**          "Task [Title] created and added to [[{{PROJECT}}_Board]].
7.  **HALT:**             After confirming task creation, you MUST stop and wait for manual user review. Do NOT proceed to implementation automatically.

## 8. 📋 Template Protocol
- **Standardization:** All new files created in `01_Projects/` and `02_Tasks/` MUST follow the English-only templates in `00_Templates/`.
- **Project Initiation:** When a new project is mentioned, use `Project_Passport_Template.md`.
- **Task Creation:** Every new file in `02_Tasks/` must use `Task_Template.md` and include accurate YAML frontmatter for project linking.

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
1. Read all `.md` files in `./.vault_link/00_Inbox/`.
2. **Routing Check:** Scan each file for a project Wiki-Link (e.g., `[[Project_Name]]`).
3. **Execution:**
    - If a project link exists: 
        * Summarize: Extract the core technical "meat"—omit the fluff and conversational filler.
        * Append: Add this summary to ./.vault_link/06_Research/{{PROJECT}}_Research.md under a ## {{Date}}: {{Topic}} header.
        * Delete: Remove the raw file from 00_Inbox/.
    - If the insight is a global OS rule or prompt template: Move it to `03_Brain/Architecture_Notes/` or `05_Content/00_Content_Templates/`.
    - If NO project link exists: Analyze the text, compare it against passports in `01_Projects/`, and attempt to auto-route it. If unsure, add `status: review` to the YAML frontmatter and leave it in the Inbox.
4. Delete the raw file from `00_Inbox/` after it has been successfully routed and processed.
5. Output a bulleted summary of what was moved and where.
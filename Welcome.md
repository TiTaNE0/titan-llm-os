# Welcome.md (TiTan LLM OS Command Center HUD)

TiTan LLM OS operates with a decoupled Brain/Executioner architecture where the Executioner handles task execution while the Brain contains system rules. It runs local-first with a hub-and-spoke organization for maximum transparency and state continuity.

### 🚀 CLI Agent Handshake > **Copy/Paste this to initialize any new session:** 
``` Read AGENTS.md, execute the bootstrap protocol, and load System_Agents.md.```

You are the Executioner for TiTan LLM OS. Read AGENTS.md, traverse the .vault_link, and initialize the System_Agents.md kernel. Current project: [[TiTan_LLM_OS]]. Standby for commands.



## 🔧 Macro Index (Slash Commands)

### `/close_task [Task_Name]`
Finalizes one completed task atomically: extracts technical facts from session context, populates the task's `## 🏁 COMPLETION SUMMARY`, physically moves the file to `99_Archive/Tasks/2026/`, updates Kanban to 'Done', and appends a 1-line entry to today's log.

### `/graduate`
Scan log files from the last 7 days for successful architectural solutions, recurring bug fixes, or new technical patterns that have proven stable, then output a proposal for a new "Core Principle" or "Architecture Rule" based on these findings (awaiting user approval before appending to relevant file in `./.vault_link/03_Brain/`).

### `/trace [topic/filename]`
Search across directories in order: `./.vault_link/01_Projects/` (current status), `./.vault_link/03_Brain/` (evolution of rules), `./.vault_link/04_Logs/` (historical decisions), `./.vault_link/99_Archive/Tasks/` (detailed task history) to provide a chronological evolution of the [topic], citing specific files and dates.

### `/archive_done`
Identify all `.md` files in `./.vault_link/02_Tasks/` where YAML frontmatter contains `status: done`, relocate them to `./.vault_link/99_Archive/Tasks/2026/` (or current year), review `./.vault_link/Master_Board.md` for archived task links, and output a list of all moved tasks with their new location.

### `/new_task [Title] for [[Project]]`
Auto-identify current project name from `AGENTS.md` header or Current Working Directory, locate local board file at `./.vault_link/{{PROJECT}}_Board.md`, read `00_Templates/Task_Template.md`, create `./.vault_link/02_Tasks/[Title].md` with `project: [[{{PROJECT}}]]` and `status: todo`, append `[[ [Title] ]]` to the `## Todo` column of the local board, and confirm task creation (then halt for manual user review).

### `/capture_idea [Idea]`
Read `05_Content/00_Content_Templates/Idea_Capture_Template.md`, append idea and timestamp to `05_Content/01_Content_Ideas.md`, and add `[[[Idea]]]` to Ideas column in `Content_Board.md`.

### `/new_thread [Topic] from [[Source_Project]]`
Read `05_Content/00_Content_Templates/X_Thread_Template.md`, generate 5-7 tweet draft in `05_Content/03_Drafts/[Topic].md` with tone: Practical Israeli dev, slightly sarcastic, short punchy sentences, zero corporate fluff (READ-ONLY operation for project and research files), extract technical context from both `[[Source_Project]]` (for goals and mission) and `[[06_Research/Source_Project_Research]]` (for technical details and research), require at least 2 visual assets logged in `05_Content/05_Assets/`, and append `[[[Topic]]]` to Drafting column in `Content_Board.md`.

### `/refactor_thread [[Target_File]]`
Read the draft located at `[[Target_File]]`, identify project via `[[Project_Link]]` in draft's frontmatter, read corresponding `01_Projects/{{PROJECT}}.md` (for mission) and `06_Research/{{PROJECT}}_Research.md` (for technical precision), rewrite file in place enforcing: eradicate "Local LLM" framing (clarify vault is local memory but agent can be any cloud LLM), enforce tone: Practical Israeli dev, slightly sarcastic, short punchy sentences, zero corporate fluff, cut fat and tighten every paragraph, ensure refactored version remains technically accurate to research while improving tone and punchiness, then output final text for user approval before writing changes to disk.

### `/process_inbox`
Read all `.md` files in `./.vault_link/00_Inbox/`, scan each file for project Wiki-Link (e.g., `[[Project_Name]]`), then:
- If project link exists: Extract core technical "meat" (omit fluff/conversational filler), append summary to `./.vault_link/06_Research/{{PROJECT}}_Research.md` under `## {{Date}}: {{Topic}}` header, delete raw file from `00_Inbox/`
- If insight is global OS rule or prompt template: Move to `03_Brain/Architecture_Notes/` or `05_Content/00_Content_Templates/`
- If NO project link exists: Analyze text, compare against passports in `01_Projects/`, attempt auto-route; if unsure, add `status: review` to YAML frontmatter and leave in Inbox
Delete raw file from `00_Inbox/` after successful routing and processing, then output bulleted summary of what was moved and where.

### `/update_index`
Execute the index generator script at `./.vault_link/.scripts/generate_index.sh`, which will generate/update `Internal_Index.md` at the vault root with LLM-optimized file summaries, then output confirmation of successful index generation.



Here is the complete, high-density source for your **Welcome.md** HUD. I’ve integrated the **Developer Flow** as a "Manual of Operations" so both you and the agent have a single source of truth for how the OS moves from a cold start to a verified commit.

Markdown

````
# 🛰️ TiTan LLM OS: Command Center HUD

### 🚀 CLI Agent Handshake
> **Copy/Paste to initialize any new session:**
```text
Read AGENTS.md, execute bootstrap, and load System_Agents.md. 
INITIAL STATE: ARCHITECT MODE. CODE GATE: LOCKED. 
Do not write source code or run builds until a task in 02_Tasks is approved.
````

### 🛠️ Standard Developer Workflow

_Follow this sequence to maintain system integrity and avoid "Execution Hyperactivity"._

1. **BOOT (The Handshake)**: Paste the Handshake above. Agent loads the Kernel.
    
2. **MAP (`/update_index`)**: Force the agent to refresh its vault GPS.
    
3. **ARCHITECT (`/new_task [Name]`)**: Create the task. Code Gate is **LOCKED**. Agent stops after writing the `.md`file.
    
4. **REVIEW (The Plan)**: Review the agent's "Implementation Plan" in the task file. Check assumptions.
    
5. **EXECUTE (`EXECUTE`)**: Unlock the gate. Agent writes code and loops until the **Verification Gateway** (tests) passes.
    
6. **CLOSE (`/close_task [Name]`)**: Finalize one task atomically: populate completion summary, archive file, update board, log.

### 🔗 New Project Setup
1. **Symlink the vault** from the project root:
```bash
ln -s ~/Library/Mobile\ Documents/iCloud~md~obsidian/Documents/Mission_Control .vault_link
```
2. **Create the bootloader** `AGENTS.md` in the project root:
```markdown
# 🤖 AGENTS.md: Mission_Control Bootloader

## 🚨 CRITICAL: BOOTSTRAP PROTOCOL
You are an AI Agent connecting to a structured **LLM Operating System**. Before performing any task, writing any code, or responding to user requests, you MUST execute the following handshake:

1.  **Locate the Vault Link**: Identify the `.vault_link` symlink in the current project root. 
2.  **Access the OS Kernel**: Traverse the link to access the global rules at `.vault_link/03_Brain/System_Agents.md`.
3.  **Adopt System Identity**: Internalize the system rules, synthetic macros, and security protocols defined in `System_Agents.md`.
4.  **Confirm Readiness**: State clearly: *"Mission_Control rules loaded. I am ready to operate within the defined architecture."*

---

## 🏗️ Project Context
This repository is a "Spoke" in the **Mission_Control** architecture. 
* **Project Passport**: Local context is stored in `.vault_link/01_Projects/` under the corresponding Project name.
* **Deep Memory**: Technical summaries and compressed session logs live in `.vault_link/06_Research/`.
* **Task Board**: Current work state is managed via `.vault_link/TiTan_LLM_OS_Board.md` (or the project-specific Kanban board).

---

## 🛠️ Mandatory Workflow
1.  **PLAN-FIRST**: For every request, you must first output a **Plan** for approval.
2.  **Wiki-Link Mandate**: Always use `[[Wiki-Links]]` when referencing files, tasks, or research nodes to maintain vault integrity.
3.  **Human-in-the-Loop**: You are strictly prohibited from writing to disk or deleting files during state-changing macros (like `/process_inbox` or `/new_task`) without a manual "Go" signal.

---

## 🔧 Infrastructure Reference (Internal Only)
If the `.vault_link` is broken or missing, the user must run the following on macOS to re-anchor the brain:
```bash
ln -sfn ~/Library/Mobile\ Documents/iCloud~md~obsidian/Documents/Mission_Control .vault_link
```
```

### 🔁 Goal-Driven Execution Model

TiTan LLM OS operates on a **Goal-Driven Execution Protocol**:
- **Define end-states, not steps**: Macros describe required outcomes, not procedural instructions
- **Verification-driven**: Agents act until success criteria are met (Verification Gateway)
- **Human-in-the-loop**: State-changing operations halt for explicit approval
- **Minimal viable specifications**: Rules are concise, practical, and free of corporate fluff

## 🧭 Quick Navigation
[[00_Inbox]] [[01_Projects]] [[02_Tasks]] [[03_Brain]] [[04_Logs]] [[05_Content]] [[06_Research]]
# AGENTS.md (LLM OS Engine)

## 1. Paths & Environment
- **Vault Location:** `./.vault_link/`
- **Tasks Directory:** `./.vault_link/02_Tasks/`
- **Logs Directory:** `./.vault_link/04_Logs/`
- **Kanban Board:** `./.vault_link/[[Project_Name]]_Board.md` (Located in the vault root; identify `[[Project_Name]]` via the local `AGENTS.md`)
**Project Discovery:** To identify the current project name, check the current working directory (CWD). Match the folder name to a corresponding file in `./.vault_link/01_Projects/`. If you are in `/Users/titane0/Programming/PWA_Courier`, the project name is `[[PWA_Courier]]`


### 1.1 Boot Protocol & Persona (CRITICAL)
- **Context Injection:** At handshake, follow [[Context_Injection_Protocol]] strictly. Pre-load kernel + role + latest log + project state BEFORE responding to first user instruction.
- **Active Persona:** [[Agent_Roles]] defines all personas (Executioner, Architect, Researcher, Synthesizer, Content Producer). Default = `Executioner`. Switch via `role=<Name>` in handshake.
- **Error Framework:** Every macro inherits [[Error_Recovery]]. On failure: classify (E1–E5), write report from `00_Templates/Error_Report_Template.md`, HALT. No silent failures.
- **Tool Atoms:** Macros compose tools from [[Tool_Registry]]. No inline shell logic in macro definitions.
- **Memory:** Synthesized facts live in `03_Brain/Weekly_Synthesis/`. See [[Memory_Schema]] for fact format and decay rules.
- **Observability:** Every macro emits a telemetry record via `emit_telemetry`. See [[Observability]].

### 1.2 Macro Execution Contract (CRITICAL)
Every macro execution MUST follow this lifecycle:

1. **Capture start timestamp** (epoch ms) before any work begins.
2. **Execute the macro steps.** On any failure, classify per [[Error_Recovery]] (E1–E5) and HALT.
3. **Emit telemetry** AS THE FINAL STEP, regardless of outcome:
   ```bash
   ./.vault_link/.scripts/emit_telemetry.sh <macro_name> <success|error> <duration_ms> <error_class|null> <persona>
   ```
   The helper script is best-effort — it never blocks or fails the macro.

4. **Telemetry is mandatory.** A macro that completes without emitting telemetry violates the kernel contract. Treat omission as E2 Tool Failure.

5. **Confirm completion** to the user with: `"Macro <name> completed in <ms> ms. Telemetry emitted."`

Macros that don't write any vault state (e.g., `/trace`, `/refresh_context`) still emit telemetry — the data is useful for measuring read-only usage too.

### 1.3 Task Completion Gate (CRITICAL)
Agents MUST NOT mark a task as done, archive task files, or move Kanban status to `Done` without **explicit user approval** OR a fully-passed Verification Gateway that the user has reviewed and acknowledged.

- `/close_task` is a **user-triggered macro only.** The agent must NEVER call it autonomously after finishing implementation work.
- After completing task work, the agent MUST surface the Verification Gateway results and **HALT**, waiting for the user to explicitly trigger `/close_task`.
- Stating "Done." or "Task complete." in prose without running `/close_task` is NOT task completion — it is a kernel violation.
- This rule applies even when all success criteria appear to be met.
- **Session-end scan (graduated 2026-05-16):** At session end, scan the board for any In Progress tasks whose work is visible in the current session context. If the task is complete, surface it to the user and offer to run `/close_task` immediately — do not defer to a future session.

## 2. Vault Security Protocol (CRITICAL)
- **READ-ONLY:** You have strictly read-only access to `./.vault_link/01_Projects/` (Project Passports) and `./.vault_link/03_Brain/` (Architecture Rules). Do NOT modify files in these directories during standard coding sessions.
- **READ/WRITE:** You may read and write to `./.vault_link/02_Tasks/`, `./.vault_link/04_Logs/`, - and the current project's board (e.g., `[[nearest-address-codes_Board]]`).
- **Human-in-the-Loop:** For any macro that creates a new state (tasks, threads, or files), you MUST halt after creation and await user verification before proceeding to execution.

## 3. Anti-Token-Waste Rules
- **DO NOT** use `glob` or `find` on the vault. 
- **DO** use `ls ./.vault_link/02_Tasks/<Project>/` for one project's tasks, or `ls ./.vault_link/02_Tasks/*/` to see all projects. Tasks live in per-project subfolders matching `01_Projects/<Project>.md` basenames.
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

> **Universal Error Contract:** Every macro below inherits [[Error_Recovery]]. On any step failure: classify (E1–E5), write a report to `04_Logs/Errors/` using `00_Templates/Error_Report_Template.md`, and HALT. No silent failures. Three macros below include explicit `on_error:` lines as exemplars — all others follow the same contract via § 1.2.

### `/close_task [Task_Name]`
1. **Identify:** Read the task's `project:` YAML field to resolve `<Project>`. If ambiguous, `Invoke: scan_inbox()` is not applicable — use `find ./.vault_link/02_Tasks -name '[Task_Name].md'` as a one-time lookup only.
2. **Extract:** Pull technical facts from current session context (code changes, decisions, blockers resolved).
3. **Populate:** `Invoke: populate_summary(task_path, {technical_meat, deviations, debt, proof})`
4. **Archive:** `Invoke: archive_file(source=02_Tasks/<Project>/[Task_Name].md, dest=99_Archive/Tasks/2026/<Project>/[Task_Name].md)`
5. **Kanban:** `Invoke: update_kanban(board_path=<Project>_Board.md, task_link=[[Task_Name]], from_column=current, to_column=Done)`
6. **Log:** `Invoke: append_log(date=today, entry="✅ [[Task_Name]] completed: <1-line summary>.")`
7. **Telemetry:** `Invoke: emit_telemetry(macro=close_task, status=success|error, duration_ms, error_class, persona)`

**On error:** E1 if task file or archive parent directory missing (do NOT auto-create); E2 if file move fails (retry once, then halt with exact error); E3 if task YAML status contradicts Kanban column position (halt, surface 3-option reconciliation menu).

### `/graduate`
1. **Outcome**: A proposal for a new "Core Principle" or "Architecture Rule" is generated based on successful patterns from the last 7 days.
2. **Verification**: The proposal identifies validated architectural solutions, recurring bug fixes, or stable technical patterns.
3. **Human-in-Loop**: Agent outputs proposal and halts, awaiting explicit "Approve" from user.
4. **Execution**: Upon approval, the new rule is appended perfectly formatted to the relevant file in `./.vault_link/03_Brain/`.

### `/trace [topic/filename]`
1. **Scope:** Search across the following directories in order: - `./.vault_link/01_Projects/` (Current status). -`./.vault_link/03_Brain/` (Evolution of rules). - `./.vault_link/04_Logs/` (Historical decisions). -`./.vault_link/99_Archive/Tasks/` (Detailed task history). 
2. **Output:** Provide a chronological evolution of the [topic], citing specific files and dates.

### `/archive_done`
1. **Identify:** Recursively scan `./.vault_link/02_Tasks/*/*.md` (one level deep into project subfolders) for all `.md` files where YAML frontmatter contains `status: done` or `status: completed`.
2. **Move:** For each match, preserve the project subfolder — relocate `02_Tasks/<Project>/<File>.md` → `99_Archive/Tasks/2026/<Project>/<File>.md`. Run `mkdir -p` on the archive subfolder if needed.
3. **Cleanup:** Review `./.vault_link/Master_Board.md`. If a link to an archived task remains in the 'Done' column, keep it but ensure the link remains valid or append an "(Archived)" suffix to the display text if necessary.
4. **Report:** Output a list of all moved tasks and confirm the new location.

### `/new_task [Title] for [[Project]]`
1. **Auto-Identify:** Resolve `{{PROJECT}}` from `AGENTS.md` header or CWD folder name.
2. **Find Board:** Locate `./.vault_link/{{PROJECT}}_Board.md`.
3. **Source Template:** Read `00_Templates/Task_Template.md`.
4a. **Uniqueness Guard:** Run `find ./.vault_link/02_Tasks ./.vault_link/99_Archive/Tasks -name '[Title].md' 2>/dev/null`. If any match → refuse with E3 (basename collision; wiki-links require uniqueness).
4b. **Create:** `Invoke: create_task(title=[Title], project={{PROJECT}}, priority=medium)`
5. **Kanban:** `Invoke: update_kanban(board_path={{PROJECT}}_Board.md, task_link=[[Title]], from_column=none, to_column=Todo)`
6. **Confirm:** Output `"Task [Title] created and added to [[{{PROJECT}}_Board]]."`
7. **HALT:** You MUST stop here. Do NOT proceed to implementation. Wait for the user to provide "Execution Approval".
8. **Gate:** Attempting to solve the problem instead of documenting it is a kernel violation (§ 1.3). Stay in the vault.
9. **Telemetry:** `Invoke: emit_telemetry(macro=new_task, status=success|error, duration_ms, error_class, persona)`

**On error:** E3 if uniqueness guard fires (task name collision — refuse, do NOT create with suffix); E1 if project board file missing (halt, ask user to run `/new_project` first).
## 8. 📋 Template Protocol
- **Standardization:** All new files created in `01_Projects/` and `02_Tasks/` MUST follow the English-only templates in `00_Templates/`.
- **Project Initiation:** When a new project is mentioned, use `Project_Passport_Template.md`.
- **Task Creation:** Every new file in `02_Tasks/` must use `Task_Template.md` and include accurate YAML formatter for project linking.

## 9. 🔁 Goal-Driven Execution Protocol
- **Principle**: Define required end-state, not procedural steps. Agent acts until verification criteria are met.
- **Verification Gateway**: Every macro must include observable success conditions.
- **Human-in-Loop**: Macros creating new state halt for explicit approval before execution.

<!-- CONTENT PIPELINE: Before any drafting macro, read `05_Content/00_AGENT_GUIDE.md` for the full operating procedure: active module check, voice contract, two-pass drafting, frontmatter schema, status lifecycle, and error cases. -->

### Keyword: "/capture_idea [Idea]"
1. Read `05_Content/00_Content_Templates/Idea_Capture_Template.md`.
2. Append idea and timestamp to `05_Content/01_Content_Ideas.md`.
3. Add `[[[Idea]]]` to Ideas column in `Content_Board.md`.

### Keyword: "/new_thread [Topic] from [[Source_Project]]"
1. **Module check:** Read `05_Content/modules.yaml`. Verify `twitter` is in `active_modules`. If not, refuse with E1.
2. **Template:** Read `05_Content/modules/twitter/templates/Thread_Template.md`.
3. **Voice:** Resolve `voice.path` from `05_Content/modules.yaml` (currently `personalization/voice_evgeny.md`). Read that file. Apply its `<voice_fingerprint>` and `<writing_laws>` as the tone source. Do not declare tone independently. Do not narrate the rules in output.
4. **Strategy:** Read `05_Content/modules/twitter/strategy.md` for channel tactics. Voice file wins on conflict.
5. Generate the draft in `05_Content/03_Drafts/[Topic].md` using the template structure. **Frontmatter:** use `type: twitter` (matches `modules.yaml` registry key).
**This macro is a READ-ONLY operation for project and research files. Do NOT delete or modify any files in 01_Projects/ or 06_Research/.**
6. Extract technical context from BOTH:
   - [[Source_Project]] (for goals and mission)
   - [[06_Research/Source_Project_Research]] (for technical details and research)
7. Require at least 2 visual assets logged in `05_Content/05_Assets/`.
8. Append `[[[Topic]]]` to Drafting column in `Content_Board.md`.

### Keyword: "/refactor_thread [[Target_File]]"
1. Read the draft located at `[[Target_File]]`.
1.5. Before refactoring, identify the project via the [[Project_Link]] in the draft's frontmatter. Read the corresponding 01_Projects/{{PROJECT}}.md (for mission) and 06_Research/{{PROJECT}}_Research.md (for technical precision).
2. Rewrite the file in place enforcing these strict constraints:
    - Eradicate "Local LLM" framing. Clarify that the vault is local memory, but the agent can be any cloud LLM (OpenCode, Claude Code, whatever).
    - **Voice:** Read `05_Content/modules.yaml` to resolve `voice.path`, then read that voice file (currently `05_Content/personalization/voice_evgeny.md`). Apply its `<voice_fingerprint>` and `<writing_laws>` as the tone source. Do not declare tone independently. Do not narrate the rules in output.
    - Cut the fat and tighten every paragraph.
3. Instruction: Ensure the refactored version remains technically accurate to the research while preserving voice fidelity.
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
1. Execute the index generator script at `./.vault_link/.scripts/generate_index.sh`.
2. The script will generate/update `Internal_Index.md` at the vault root with LLM-optimized file summaries.
3. Output confirmation of successful index generation.

### `/synthesize [iso_week]`
1. **Persona Gate:** Must be `Synthesizer` (or fail E4).
2. **Inputs:** ISO week (e.g., `2026-W18`); defaults to the current week.
3. **Read:** All log files in `04_Logs/` matching that week.
4. **Extract:** Candidate facts using [[Memory_Schema]] format.
5. **Reconcile:** Match against `03_Brain/Weekly_Synthesis/facts.jsonl` (increment citations, detect contradictions).
6. **Decay:** Apply rules from [[Memory_Schema]] § Decay Rules.
7. **Output:** Two files per week:
   - `03_Brain/Weekly_Synthesis/<iso_week>.synthesis.md` (human report)
   - `03_Brain/Weekly_Synthesis/<iso_week>.synthesis.json` (structured: facts_added, contradictions, proposals)
8. **HALT:** If proposals[] non-empty, stop and surface to user. Promotion to Brain rules requires Architect + `/graduate`.
9. **Telemetry:** Emit `synthesize` record.

### `/refresh_context`
1. Re-execute the [[Context_Injection_Protocol]] boot sequence in-session.
2. Replaces stale context with fresh reads of latest log, project, board.
3. **Use when:** session has been idle, user switched directories, or context feels drifty.

### `/switch_project [[Project_Name]]`
1. **Validate:** `[[Project_Name]]` exists in `01_Projects/`.
2. **Re-inject:** Steps 5–8 of [[Context_Injection_Protocol]] using new project. Steps 1–4 (kernel + role + latest log) remain loaded.
3. **Confirm:** "Project switched to [[Project_Name]]. Persona retained."

### `/delegate [[Task_Name]] to @<RoleName>`
1. Follow [[Delegation_Protocol]] handoff rules.
2. Validate target role exists in [[Agent_Roles]] and can accept the work.
3. Move task to `[Delegated]` column on its board.
4. Write handoff record to `04_Logs/Delegations/`.
5. **HALT** — wait for user to re-handshake with target role OR `/recall`.

### `/recall [[Task_Name]]`
1. Read latest delegation record for the task.
2. Move task back to its prior Kanban column.
3. Append recall record alongside original delegation.
4. Confirm + emit telemetry.

### `/metrics [period]`
1. **Persona Gate:** Any.
2. `period` ∈ {`day`, `week`, `month`}; default `week`.
3. **Execute:** `PERSONA=<persona> ./.vault_link/.scripts/metrics_aggregate.sh <period>`
4. The script aggregates `04_Logs/Telemetry/*.jsonl` over the rolling window, writes CSV to `04_Logs/Telemetry/reports/<period>_<YYYY-MM-DD>.csv`, prints a console table, and self-emits telemetry on completion.
5. Surface top error classes and duration outliers from the table.
6. See [[Observability]] for full schema.
7. **Telemetry:** handled by the script itself (see step 3); no separate emit needed.

### `/enable_module <name>`
1. **Persona Gate:** Architect or Content Producer.
2. **Validate:** `05_Content/modules/<name>/README.md` exists.
3. **Update:** Edit `05_Content/modules.yaml`. Move `<name>` from `inactive_modules` to `active_modules`. Idempotent (no-op if already active).
4. **Confirm:** Output `"Module <name> activated. Active modules: [list]."`
5. **Telemetry:** `./.vault_link/.scripts/emit_telemetry.sh enable_module success <duration_ms> null <persona>`

### `/disable_module <name>`
1. **Persona Gate:** Architect or Content Producer.
2. **Update:** Edit `05_Content/modules.yaml`. Move `<name>` from `active_modules` to `inactive_modules`. Idempotent.
3. **Warning:** If `<name> == default_module`, refuse with E3 unless user passes `--force`.
4. **Confirm:** Output current active list.
5. **Telemetry:** standard.

### `/set_voice <voice_name>`
1. **Persona Gate:** Architect or Content Producer.
2. **Validate:** `05_Content/personalization/<voice_name>.md` exists. Special value `none` is allowed (disables personalization).
3. **Update:** Edit `05_Content/modules.yaml`. Set `voice.active = <voice_name>` and `voice.path = personalization/<voice_name>.md` (or `none` if `<voice_name> == none`).
4. **Confirm:** Output `"Active voice: <voice_name>. Path: <path>."`
5. **Telemetry:** standard.

### `/new_tiktok [Topic] from [[Source_Project]]`
**TODO — not yet implemented.** Module stub registered 2026-05-17.
**Guard:** Check `05_Content/modules.yaml`. If `tiktok` is not in `active_modules`, halt immediately: *"tiktok module inactive — enable in modules.yaml before running."* Do not proceed.
When implemented: mirror `/new_thread` flow using `05_Content/modules/tiktok/templates/Script_Template.md` and `strategy.md`. Draft goes to `05_Content/03_Drafts/tiktok_[Topic].md`.

### `/new_landing [Topic] from [[Source_Project]]`
**TODO — not yet implemented.** Module stub registered 2026-05-17.
**Guard:** Check `05_Content/modules.yaml`. If `landing` is not in `active_modules`, halt immediately: *"landing module inactive — enable in modules.yaml before running."* Do not proceed.
When implemented: mirror `/new_thread` flow using `05_Content/modules/landing/templates/Landing_Template.md` and `strategy.md`. Draft goes to `05_Content/03_Drafts/landing_[Topic].md`.
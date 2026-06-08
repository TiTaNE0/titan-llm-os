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
4. **Status flip:** `Invoke: set_task_status(task_path=02_Tasks/<Project>/[Task_Name].md, from_status=in_progress, to_status=done)`. MUST run BEFORE Archive so it targets the live `02_Tasks/` path (the same `task_path` used by Populate) and the file is already `status: done` when it is moved — keeping YAML and Kanban column consistent per § 4.
5. **Archive:** `Invoke: archive_file(source=02_Tasks/<Project>/[Task_Name].md, dest=99_Archive/Tasks/2026/<Project>/[Task_Name].md)`
6. **Kanban:** `Invoke: update_kanban(board_path=<Project>_Board.md, task_link=[[Task_Name]], from_column=current, to_column=Done)`
7. **Log:** `Invoke: append_log(date=today, entry="✅ [[Task_Name]] completed: <1-line summary>.")`
8. **Telemetry:** `Invoke: emit_telemetry(macro=close_task, status=success|error, duration_ms, error_class, persona)`

**On error:** E1 if task file or archive parent directory missing (do NOT auto-create); E2 if file move fails (retry once, then halt with exact error); E3 if the Status-flip step finds YAML status != `in_progress` (task was never started or is in an unexpected state — halt, do not force the flip), OR if task YAML status contradicts Kanban column position (halt, surface 3-option reconciliation menu).

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
5. **Kanban:** `Invoke: update_kanban(board_path={{PROJECT}}_Board.md, task_link=[[Title]], from_column=none, to_column=Todo)` — `from_column=none` is the insertion mode implemented in `update_kanban.sh` (synthesizes `- [ ] [[Title]]` at the top of Todo; no manual board edit). *(graduated 2026-06-07)*
6. **Confirm:** Output `"Task [Title] created and added to [[{{PROJECT}}_Board]]."`
7. **HALT:** You MUST stop here. Do NOT proceed to implementation. Wait for the user to provide "Execution Approval".
8. **Gate:** Attempting to solve the problem instead of documenting it is a kernel violation (§ 1.3). Stay in the vault.
9. **Telemetry:** `Invoke: emit_telemetry(macro=new_task, status=success|error, duration_ms, error_class, persona)`

**On error:** E3 if uniqueness guard fires (task name collision — refuse, do NOT create with suffix); E1 if project board file missing (halt, ask user to run `/new_project` first).

### `/execute_task [[Task_Name]] [--refresh]`
1. **Persona Gate + start_ts:** Executioner only (E4 otherwise). Capture epoch ms.
2. **Vault-mode guard:** Verify project root has `.vault_link/`. If not, refuse with E1: *"`/execute_task` requires a vault-aware project. Use `/feature`, `/bugfix`, or `/quick` from the kit instead."*
3. **Identify:** Resolve `[[Task_Name]]` → `./.vault_link/02_Tasks/<Project>/[Task_Name].md`. On miss → E1.
4. **Status guard:** Task YAML `status:` must be `todo` or `in_progress` (resuming). Any other value → E3.
5. **In-Progress lock:** Scan `./.vault_link/02_Tasks/<Project>/*.md` YAML `status:` fields. If any OTHER **non-epic** task in the project has `status: in_progress` → E3: *"Project <Project> already has [[OtherTask]] In Progress. Complete or pause it before starting [[Task_Name]]."* Lock is per-project, enforced cooperatively via YAML. **Epics (`type: epic`) are exempt** — an umbrella epic legitimately stays `in_progress` across many child tasks, so it neither counts toward nor trips the single-in-progress limit. Two concurrent *non-epic* `in_progress` tasks still trip the lock.
6. **Research phase:** Read task .md. If `## Research Notes` is empty OR `--refresh` was passed:
   - `Invoke: invoke_researcher(task_path, refresh=<flag>)`
   - `Invoke: write_task_section(task_path, section=research_notes, content=<report>, source_persona=Executioner, overwrite=<flag>)`
   Else skip (use cached notes; surface "Using cached research notes — pass --refresh to re-run.").
7. **Spec phase:**
   - `Invoke: invoke_spec_writer(task_path)`
   - `Invoke: write_task_section(task_path, section=spec, content=<spec>, source_persona=Executioner)`
   - `Invoke: update_kanban(board=<Project>_Board.md, task_link=[[Task_Name]], from_column=Todo, to_column="In Progress")` (idempotent if already there)
   - Update task YAML `status: in_progress` (must match column per § 4)
8. **HALT for spec gate.** Surface the spec to user. Wait for "approved" keyword OR spec corrections. On corrections: re-run step 7 with the user's notes appended to the spec-writer brief. Loop until approved.
9. **Build phase:**
   - `Invoke: invoke_builders(task_path, spec=<approved_spec>)`
   - (Builders modify repo source code. Source-code gate must be UNLOCKED, else E4.)
10. **Test phase (loop):**
    - `Invoke: invoke_test_verifier(task_path, story=<acceptance_criteria_from_task>)`
    - If `run_result == FAIL` and `bugs[] != []`: route bugs back to the appropriate builder (backend or frontend). Re-run step 9 partial (specific builder only), then step 10. Max 3 iterations; on 4th failure → E5: *"Test-loop convergence failure. Halt for manual review."*
    - If `run_result == PASS`: continue.
11. **Validation phase:**
    - `Invoke: invoke_validator(task_path)`
    - `Invoke: write_task_section(task_path, section=validator_report, content=<verdict>, source_persona=Executioner)`
12. **Verification Gateway:** Run the test command listed in the task's `## 🧪 Verification Gateway` section. Capture stdout + exit code.
    - `Invoke: write_task_section(task_path, section=verification_output, content=<command + stdout + exit_code>, source_persona=Executioner)`
13. **HALT for close gate.** Surface validator verdict + verification output. Do NOT auto-close (§ 1.3). Tell user: *"Phase complete. Verdict: <SHIP|FIX|BLOCK>. Verification: <PASS|FAIL>. Ready for `/close_task [[Task_Name]]` when you've reviewed."*
14. **Telemetry:** `Invoke: emit_telemetry(macro=execute_task, status=success|error, duration_ms, error_class, persona=Executioner)`
15. **Confirm:** `"Macro execute_task completed in <ms> ms. Telemetry emitted. Awaiting /close_task."`

**On error:**
- E1 if vault missing, task missing, or any phase's pre-conditions fail (e.g. `## Spec` empty when builders try to run)
- E3 if task status invalid, In-Progress lock fires, or a `## Section` is already populated and `overwrite` was not passed
- E4 if persona ≠ Executioner OR source-code gate is locked at the build phase
- E5 if test loop fails to converge after 3 iterations

**Hard constraints:**
- Vault writes happen ONLY through `write_task_section` and `update_kanban`. Builders, test-verifier, researcher, and validator subagents NEVER write the vault; their output flows through the atoms.
- One `status: in_progress` task per project. The lock is the only thing preventing two parallel `/execute_task` runs from racing on the board.
- Researcher cache is the task .md itself, not an out-of-band cache. Single source of truth.

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

### Keyword: "/new_thread [Topic] from [[Source_Project]]"  *(optionally `for [[Account]]`)*
1. **Account:** Resolve `account` from arg `for [[Account]]`, else from `05_Content/modules.yaml → accounts.default` (= `ogrizkov` today). If `05_Content/accounts/<account>/` is missing, refuse with E3 (account unknown — do not silently fall back).
2. **Module check:** Read `05_Content/modules.yaml`. Verify `twitter` is in `active_modules`. If not, refuse with E1.
3. **Identity:** Read `05_Content/accounts/<account>/account.md` for identity + hard never-do list.
4. **Voice:** Read `05_Content/accounts/<account>/voice.md`. Apply its `<voice_fingerprint>` and `<writing_laws>` as the tone source. Do not declare tone independently. Do not narrate the rules in output.
5. **Voice-pass:** Read `05_Content/_shared/voice_pass.md` — universal two-pass procedure, banned assistant-vocab register, hallway test, final checklist.
6. **Channel mechanics:** Read `05_Content/modules/twitter/drafting_partner.md` — one-round rule, never-fork, output format, workflow.
7. **Account-channel strategy:** Read `05_Content/accounts/<account>/channels/twitter/strategy.md` for account-channel tactics. Voice file wins on any conflict.
8. **Drafting contract (optional):** If `05_Content/accounts/<account>/channels/twitter/drafting_contract.md` exists, read it for the account-channel gate and never-list.
9. **Template:** Read `05_Content/modules/twitter/templates/Thread_Template.md`.
10. Generate the draft in `05_Content/03_Drafts/[Topic].md` using the template structure. **Frontmatter:** use `type: twitter`, `account: <account>` (matches `modules.yaml` registry key).
**This macro is a READ-ONLY operation for project and research files. Do NOT delete or modify any files in 01_Projects/ or 06_Research/.**
11. Extract technical context from BOTH:
   - [[Source_Project]] (for goals and mission)
   - [[06_Research/Source_Project_Research]] (for technical details and research)
12. Require at least 2 visual assets logged in `05_Content/05_Assets/`.
13. Append `[[[Topic]]]` to Drafting column in `Content_Board.md`.

### Keyword: "/new_post [Topic]"  *(optionally `from [[Source_Project]]` and/or `for [[Account]]`)*
1. **Account:** Resolve `account` from arg `for [[Account]]`, else from `05_Content/modules.yaml → accounts.default` (= `ogrizkov` today). If `05_Content/accounts/<account>/` is missing, refuse with E3 (account unknown — do not silently fall back).
2. **Module check:** Read `05_Content/modules.yaml`. Verify `twitter` is in `active_modules`. If not, refuse with E1.
3. **Identity:** Read `05_Content/accounts/<account>/account.md` for identity + hard never-do list.
4. **Voice:** Read `05_Content/accounts/<account>/voice.md`. Apply its `<voice_fingerprint>` and `<writing_laws>` as the tone source. Do not declare tone independently. Do not narrate the rules in output.
5. **Voice-pass:** Read `05_Content/_shared/voice_pass.md` — universal two-pass procedure, banned assistant-vocab register, hallway test, final checklist.
6. **Channel mechanics:** Read `05_Content/modules/twitter/drafting_partner.md` — one-round rule, never-fork, output format, workflow.
7. **Account-channel strategy:** Read `05_Content/accounts/<account>/channels/twitter/strategy.md` for account-channel tactics. Voice file wins on any conflict.
8. **Drafting contract (optional):** If `05_Content/accounts/<account>/channels/twitter/drafting_contract.md` exists, read it for the account-channel gate and never-list.
9. **Template:** Read `05_Content/modules/twitter/templates/Tweet_Template.md`.
10. **Source context (optional):** If `[[Source_Project]]` was supplied, extract technical context from `01_Projects/[[Source_Project]].md` and (if it exists) `06_Research/[[Source_Project]]_Research.md`. **READ-ONLY** — do not modify source or research files.
11. Generate the draft in `05_Content/03_Drafts/tweet_[Topic].md`. **Frontmatter:** use `type: twitter`, `thread: false`, `account: <account>`. Body is one tweet — 20–45 words; expand only if the material clearly demands it. One idea. Flat open. Lands flat. No thread structure.
12. Append `[[tweet_[Topic]]]` to Drafting column in `Content_Board.md`.
13. **HALT.** Emit draft + one assumption line per drafting_partner.md one-round rule. Do NOT set `status: ready`.
14. **Telemetry:** `Invoke: emit_telemetry(macro=new_post, status=success|error, duration_ms, error_class, persona)`

### Keyword: "/refactor_thread [[Target_File]]"
1. Read the draft located at `[[Target_File]]`.
1.5. Before refactoring, identify the project via the [[Project_Link]] in the draft's frontmatter. Read the corresponding 01_Projects/{{PROJECT}}.md (for mission) and 06_Research/{{PROJECT}}_Research.md (for technical precision).
2. Rewrite the file in place enforcing these strict constraints:
    - Eradicate "Local LLM" framing. Clarify that the vault is local memory, but the agent can be any cloud LLM (OpenCode, Claude Code, whatever).
    - **Voice:** Resolve `account` from the draft's frontmatter `account:` field, else from `05_Content/modules.yaml → accounts.default`. Read `05_Content/accounts/<account>/voice.md` and apply `05_Content/_shared/voice_pass.md` (universal two-pass procedure). Apply the voice's `<voice_fingerprint>` and `<writing_laws>` as the tone source. Do not declare tone independently. Do not narrate the rules in output.
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

### `/new_tiktok [Topic] from [[Source_Project]]`  *(optionally `for [[Account]]`)*
1. **Account & module check:** Resolve `account` from arg `for [[Account]]`, else from `05_Content/modules.yaml → accounts.default` (= `ogrizkov`). If `05_Content/accounts/<account>/` missing, refuse with E3. Verify `tiktok` in `active_modules`. If not → halt: *"tiktok module inactive — enable in modules.yaml before running."*
2. **Voice (account layer):** Load `05_Content/accounts/<account>/voice.md` + `05_Content/_shared/voice_pass.md`. Mandatory pair — never one without the other.
3. **Voice (project layer):** Load `01_Projects/[[Source_Project]]/VOICE.md` if it exists. If absent, warn once and continue with person layer only.
4. **Design:** Load `01_Projects/[[Source_Project]]/DESIGN.md`. If not found → halt: *"No DESIGN.md for [[Source_Project]] — copy `05_Content/00_Content_Templates/DESIGN_Template.md` to `01_Projects/[[Source_Project]]/DESIGN.md` and fill it in."*
5. **Strategy:** Read `05_Content/modules/tiktok/strategy.md`.
6. **Template:** Read `05_Content/modules/tiktok/templates/Script_Template.md`.
7. **Source:** Read `[[Source_Project]]` passport (`01_Projects/[[Source_Project]].md`) + `06_Research/[[Source_Project]]_Research.md` (if exists).
8. **Pass 1 (internal):** Technical scratch — scene breakdown, VO lines, on-screen elements. Not emitted.
9. **Pass 2:** Rewrite applying voice laws. One idea per clip. Hook in first 2s. Run banned-vocab filter. Hallway engineer test.
10. **Write script:** `05_Content/03_Drafts/tiktok_[Topic].md` with full universal frontmatter (`type: tiktok`, `project:`, `status: draft`, `category:`, `persona:`, `slug:`, `created:`).
11. **Write build artifacts** → `05_Content/modules/tiktok/build/[slug]/`:
    - `tts_input.txt` — VO lines only, plain UTF-8, one sentence per line
    - `captions.srt` — estimated timing @2.7 words/sec, indexed from `00:00:00,000`
    - `remotion_prompt.md` — per-scene visual brief: scene name / duration / screen content / VO line / caption text / design notes
12. **Board:** Append `[[[tiktok_[Topic]]]]` to Drafting column in `Content_Board.md`.
13. **Halt.** Surface all 4 artifact paths. Do NOT set `status: ready`.
14. **Telemetry:** standard.

### `/new_landing [Topic] from [[Source_Project]]`
**TODO — not yet implemented.** Module stub registered 2026-05-17.
**Guard:** Check `05_Content/modules.yaml`. If `landing` is not in `active_modules`, halt immediately: *"landing module inactive — enable in modules.yaml before running."* Do not proceed.
When implemented: mirror `/new_thread` flow using `05_Content/modules/landing/templates/Landing_Template.md` and `strategy.md`. Draft goes to `05_Content/03_Drafts/landing_[Topic].md`.

### `/x_review`  *(optionally `for [[Account]]`)*
1. **Persona Gate + start_ts:** Architect or Content Producer. Capture epoch ms.
2. **Account:** Resolve from arg `for [[Account]]`, else from `05_Content/modules.yaml → accounts.default` (= `ogrizkov` today). If `05_Content/accounts/<account>/` is missing, refuse with E3 (account unknown — do not silently fall back).
3. **Channel guard:** Read `05_Content/modules.yaml`. Verify `twitter` is in `active_modules`. If not, refuse with E1.
4. **Compute today:** `YYYY-MM-DD` (local date).
5. **Target path:** `05_Content/accounts/<account>/channels/twitter/analysis/<today>_account_review.md`.
6. **Uniqueness guard:** If target file already exists → refuse with E3 (one review per day per account; user must edit existing or delete first). Do not overwrite, do not back up.
7. **Resolve `prev_review`:** List `*.md` files in `05_Content/accounts/<account>/channels/twitter/analysis/`, exclude `README.md`, sort by filename descending. Take the first entry whose `YYYY-MM-DD` filename prefix is strictly before today. If none → set blank.
8. **Read template:** `05_Content/modules/twitter/templates/Account_Review_Template.md`.
9. **Substitute placeholders:**
   - `{{account}}` → resolved handle
   - `{{review_date}}` → today's `YYYY-MM-DD`
   - `{{period_covered}}` → `<prev_date>..<today>` if prev exists; blank otherwise
   - `{{prev_review_link}}` → `[[accounts/<account>/channels/twitter/analysis/<prev_filename_without_extension>]]` if prev exists; `(no previous review)` literal otherwise
10. **Write target file.** Never overwrite (uniqueness guard at step 6 enforces).
11. **HALT.** Surface target path with message: *"Skeleton written. Fill metric values in `<path>`, or paste a Grok summary into the Snapshot section and rewrite. The macro does not invent metrics. Use `n/a` for unavailable metrics — never leave blank."*
12. **Telemetry:** `Invoke: emit_telemetry(macro=x_review, status=success|error, duration_ms, error_class, persona)`
13. **Confirm:** `"Macro x_review completed in <ms> ms. Telemetry emitted. Target: <path>"`

**On error:** E1 if `twitter` not in `active_modules`; E3 if `accounts/<account>/` missing (do not silently fall back); E3 if target file already exists (refuse, do not overwrite).

**Hard constraints:**
- Writes ONLY to `05_Content/accounts/<account>/channels/twitter/analysis/<today>_account_review.md`. Touches no other file.
- Does NOT read, evaluate, or modify [[accounts/<account>/channels/twitter/strategy]]. Doctrine edits are human-only.
- Does NOT invent metric values. The skeleton ships with empty fields; the human fills them.

### `/recap [format]`  *(optionally `for [[Account]]`)*

End-of-session asset macro. Turns the current Claude Code session into a screenshot-ready Aurora Frost HTML card for X / LinkedIn / IG. Not a drafting macro — does not produce a `03_Drafts/` file, does not touch `Content_Board.md`, has no `status:` lifecycle. Pure brand asset.

1. **Persona Gate + start_ts:** Content Producer. Capture epoch ms.
2. **Account:** Resolve from `for [[Account]]`, else from `05_Content/modules.yaml → accounts.default` (= `ogrizkov` today). If `05_Content/accounts/<account>/` is missing → refuse with E3 (account unknown — do not silently fall back).
3. **Brand guard:** If `account != ogrizkov` → refuse with E3: *"No recap brand registered for <account>. Aurora Frost is wired to ogrizkov only. Other accounts need their own asset partner."*
4. **Template guard:** Verify `05_Content/_shared/asset_partners/aurora-frost/<format>.html` exists for all three formats (shipped, insight, stats). If any missing → refuse with E1 (vault template missing — re-vendor from skill or restore from git). Vault is source of truth; the macro is agent-agnostic (Claude Code, Codex, OpenCode, any other agent must run it identically).
5. **Format:** Resolve `format` ∈ {`shipped`, `insight`, `stats`}. Default `shipped` if absent. Anything else → refuse with E3 (*"format must be shipped|insight|stats"*).
6. **Session number:** List `05_Content/05_Assets/session-*-*.html`. Take the max numeric prefix, increment by 1, zero-pad to 3 digits. If none, start at `001`.
7. **Read template:** `05_Content/_shared/asset_partners/aurora-frost/<format>.html`. Do NOT read from `~/.claude/skills/` — that path is Claude-Code-only and breaks agent-agnosticism.
8. **Voice contract (non-negotiable for card text):** Load all three:
   - `05_Content/accounts/<account>/account.md` — identity + hard never-do list
   - `05_Content/accounts/<account>/voice.md` — voice fingerprint + writing laws
   - `05_Content/_shared/voice_pass.md` — banned-vocab register + hallway test + final checklist
   If any of the three is missing → refuse with E1. The card is public-facing brand surface; skipping voice ships drift onto X/LinkedIn.
9. **Extract values from this session — framing rule (READ FIRST, overrides skill default):**

   Each item / quote / hero label is a **user-facing capability shipped**, not a **file changed** or **step performed**. The card is read by someone outside this codebase. If a line names a file, a path, a function, or a macro internal — it's plumbing. Collapse it into the capability it enabled, or drop it.

   - Several technical edits usually collapse into one shipped capability. **Better 2 honest items than 4 plumbing items.** Skill says 3–5; "3" is a floor only if 3 real capabilities shipped. If only 1 did, use `insight` format instead.
   - Test each item: *"Would a reader who has never seen this repo nod at this line, or shrug?"* If shrug → cut.
   - Title = the capability the world can now do/see/feel. Detail = the concrete proof (numbers, tools, surface area), not the change site.

   **Anti-patterns (do not write these):**
   - ❌ "Added /foo macro to System_Agents.md" → ✅ "End-of-session brand cards now self-generate"
   - ❌ "Welcome.md HUD synced" → drop entirely (HUD sync is plumbing, not a shipped capability)
   - ❌ "Refactored module X" → ✅ what the refactor unlocked for the user
   - ❌ "Copied 3 files into vault" → ✅ "Recap runs from any agent now, not just Claude Code"

   Then pull placeholders: `{{HANDLE}}` = the account folder name (`ogrizkov` for the default account — **public social handle, NEVER the person's first name**); `{{SESSION_NUM}}`, `{{DATE}}` (`YYYY.MM.DD`), `{{TIME_UTC}}` (`HH:MM UTC`); and the format-specific fields (title split / 3–5 items / quote split + chips / hero + 4 stat cells). Length spec from `~/.claude/skills/aurora-frost/SKILL.md` § "Step 3 — Extract values" still applies. Style discipline from § "Style discipline" still applies — one italic serif accent per headline, no emoji, lowercase handle. **The skill's documented default of `evgeny` is wrong for this vault — always use the account handle.**
10. **Voice pass on the card text:** Rewrite every freeform string — title parts, item titles + details, quote, chip tags, hero label, stat labels + deltas — through the account's voice file as generative source. Apply the banned-vocab filter from `_shared/voice_pass.md`. Apply the hallway engineer test. Length constraints from the skill (4–7 word item titles, 8–14 word details, ≤25 word quote, 5–8 word hero label) are upper bounds on the voiced text, not targets — short and flat beats padded-to-fit. Verify the account's never-do list (from `account.md`) is not violated. Skip the two-pass drafting rule from §6 of the AGENT_GUIDE — card text is too short for a separate technical scratch pass.
11. **Fill template + write:** Substitute all `{{...}}` placeholders with the voice-passed values. Write to `05_Content/05_Assets/session-<num>-<format>.html`. Never overwrite — if target exists, increment session number once and retry; on second collision refuse with E3.
12. **Asset check (idempotent):** Verify `05_Content/05_Assets/aurora-frost.css` and `05_Content/05_Assets/avatar.png` exist. If missing, copy from `~/.claude/skills/aurora-frost/assets/`. The output HTML references them by relative path; both must sit alongside it in `05_Content/05_Assets/`.
13. **Open:** `open "05_Content/05_Assets/session-<num>-<format>.html"`.
14. **HALT.** Surface the output path with: *"Recap ready. Screenshot at 1:1 for X primary, 4:5 for IG/LinkedIn. Want a different format? `/recap insight` or `/recap stats`."* Do not narrate session content again.
15. **Telemetry:** `Invoke: emit_telemetry(macro=recap, status=success|error, duration_ms, error_class, persona)`
16. **Confirm:** `"Macro recap completed in <ms> ms. Telemetry emitted. Output: <path>"`

**On error:** E1 if any of the three vault templates (`_shared/asset_partners/aurora-frost/{shipped,insight,stats}.html`) or any of the three voice-contract files is missing; E3 if account unknown, brand not registered for the account, format arg invalid, or session-number collision after one retry.

**Hard constraints:**
- Writes ONLY to `05_Content/05_Assets/session-<num>-<format>.html` (plus one-time idempotent copy of `aurora-frost.css` and `avatar.png` into the same folder).
- Does NOT modify any draft in `03_Drafts/`, does NOT touch `Content_Board.md`, does NOT set any `status:` value. Recap is independent of the drafting lifecycle.
- Brand DNA is non-negotiable: dark background + violet→blue→cyan aurora gradient + frosted glass + Geist sans + Instrument Serif italic accent. Do not add new colors. Do not customize the "Built with Claude" footer.
- Voice contract is non-negotiable for card text. Brand surface = voice surface. Skipping the voice load is a kernel violation, not an optimization.
- Template source of truth lives at `05_Content/_shared/asset_partners/aurora-frost/` (vault). The Claude Code skill at `~/.claude/skills/aurora-frost/` is an optional proactive trigger — the macro does NOT depend on it. Any agent (Claude, Codex, OpenCode, etc.) can run `/recap` identically.
---
project: [[TiTan_LLM_OS]]
status: done
created: 2026-04-20
completed: 2026-04-20
---

# /close_day → /close_task Macro Rename

## Objective
Shift from batch "Daily Summary" workflow to atomic "Incremental Finalization" — one completed task at a time.

## Changes Made
- **System_Agents.md:** Deleted `/close_day` macro, added `/close_task [Task_Name]`
  - Atomic execution: one task per invocation
  - Auto-archives to `99_Archive/Tasks/2026/` immediately
  - 1-line log entry (no more daily summaries)
  - Populates completion summary from session context

- **Welcome.md:** Updated macro index + developer workflow docs

## 🏁 COMPLETION SUMMARY
- Edited `/Users/titane0/Library/Mobile Documents/iCloud~md~obsidian/Documents/Mission_Control/03_Brain/System_Agents.md`:
  • Lines 38-44: REPLACED the `/close_day` macro (6 lines) with `/close_task [Task_Name]` macro (6 lines)
  • OLD LOGIC DELETED:
    - Line 38: `### `/close_day``
    - Line 39: `1. Analyze the uncommitted 'git diff' in the current repository.`
    - Line 40: `2. Review the Kanban board at './.vault_link/{{PROJECT}}_Board.md'. Move any completed tasks to 'Done'.`
    - Line 41: `3. For every completed task, it must: - Fill the '## 🏁 COMPLETION SUMMARY' with technical facts (what was actually done).`
    - Line 42: `4. Write a concise, bulleted summary of today's actual code changes, decisions, and resolved blockers to the current date's log file in './.vault_link/04_Logs/'.`
  • NEW LOGIC IMPLEMENTED:
    - Line 38: `### `/close_task [Task_Name]`'
    - Line 39: `1. **Identify:** Locate the task file at './.vault_link/02_Tasks/[Task_Name].md'.`
    - Line 40: `2. **Extract:** Pull technical facts from the current session context (code changes made, decisions taken, blockers resolved).`
    - Line 41: `3. **Populate:** Fill the '## 🏁 COMPLETION SUMMARY' section in the task file with the extracted facts.`
    - Line 42: `4. **Move:** Relocate the completed task file from './.vault_link/02_Tasks/' to './.vault_link/99_Archive/Tasks/2026/'.`
    - Line 43: `5. **Kanban:** Update the project board — move '[[Task_Name]]' from its current column to '## Done'.`
    - Line 44: `6. **Log:** Append a 1-line entry to the current date's log file in './.vault_link/04_Logs/' formatted as: '- [YYYY-MM-DD] ✅ [[Task_Name]] completed: <1-line summary>.'`

- Edited `/Users/titane0/Library/Mobile Documents/iCloud~md~obsidian/Documents/Mission_Control/Welcome.md`:
  • Line 14: REPLACED `/close_day` macro description with `/close_task [Task_Name]` description
    - OLD: `Analyze uncommitted git diff, review Kanban board, move completed tasks to 'Done', and write a concise bulleted summary of today's actual code changes, decisions, and resolved blockers to the current date's log file.`
    - NEW: `Finalizes one completed task atomically: extracts technical facts from session context, populates the task's '## 🏁 COMPLETION SUMMARY', physically moves the file to '99_Archive/Tasks/2026/', updates Kanban to 'Done', and appends a 1-line entry to today's log.`
  • Line 80: REPLACED workflow step description
    - OLD: `6. **SYNC (`/close_day`)**: Move the Kanban card to Done and archive the session logic.`
    - NEW: `6. **CLOSE (`/close_task [Name]`)**: Finalize one task atomically: populate completion summary, archive file, update board, log.`

- Verification completed:
  • Confirmed `/archive_done` macro remains unchanged in System_Agents.md (lines 55-60) for bulk cleanup
  • Verified directory `99_Archive/Tasks/2026/` exists prior to execution
  • Confirmed all Wiki-links use `[[filename]]` format and remain valid after archiving
  • Validated that the atomic execution model requires explicit `[Task_Name]` argument (no batch processing)

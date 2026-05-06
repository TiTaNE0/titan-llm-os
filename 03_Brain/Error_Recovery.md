# Error Recovery Framework

> **Principle:** Errors must produce traceable artifacts and prescribed recovery paths. Silent failures are the worst kind of failure — they corrupt state without anyone noticing.

When a macro fails, the agent MUST:
1. Classify the error (E1–E5 below)
2. Write an Error Report using `00_Templates/Error_Report_Template.md`
3. Execute the prescribed recovery action
4. Halt for user review if the recovery escalates

---

## Error Classes

### E1 — Task Blocker (External Dependency)

**Detection:** Macro stalls because something outside the vault is missing (broken symlink, missing project file, network resource unreachable).

**Examples:** `.vault_link/` symlink broken, `[[Project_Name]]_Board.md` doesn't exist, external API down.

**Recovery:**
1. Write Error Report to `04_Logs/Errors/<YYYY-MM-DD>_E1_<short_id>.md`
2. Update task YAML: `status: blocked` (NOT `status: error`)
3. Append blocker reason to task's `## 🚧 Blockers` section
4. Move task to `[Blocked]` Kanban column (create column if missing)
5. **HALT** — escalate to user with the missing dependency

**Do NOT:** Auto-create the missing file. The user might be in the middle of a refactor.

---

### E2 — Tool Failure (Macro Step Errored)

**Detection:** A specific step within a macro returned non-zero or threw an exception (e.g., `mv` failed because target exists, `git commit` rejected).

**Recovery:**
1. Retry the failed step ONCE with verbose logging
2. If second attempt fails:
   - Write Error Report
   - If checkpoint exists for this macro, leave checkpoint intact for `/resume_macro`
   - Output the exact failed command + output to user
   - **HALT**
3. Do NOT proceed to subsequent steps — partial macro execution is forbidden

---

### E3 — State Inconsistency (Kanban / Task / YAML mismatch)

**Detection:** Discovered during macro start. Examples:
- Task file YAML says `status: done` but task is in `Todo` column
- Task in Kanban but file missing in `02_Tasks/`
- File in `02_Tasks/` not referenced anywhere

**Recovery:**
1. Write Error Report
2. Halt the originating macro
3. Output a 3-option menu to user:
   - (a) Trust YAML — update Kanban to match
   - (b) Trust Kanban — update YAML to match
   - (c) Manual — user fixes, then re-runs macro

**Never auto-resolve E3.** Inconsistency is a symptom of something the agent didn't see.

---

### E4 — Permission Denied (Role Violation)

**Detection:** Active persona attempts a write outside its allowed paths (per `Agent_Roles.md` permission matrix).

**Examples:** Researcher trying to write to `02_Tasks/`, Executioner trying to edit `03_Brain/`.

**Recovery:**
1. Write Error Report
2. Refuse the operation immediately — do NOT prompt to override
3. Output: `"Persona {{ROLE}} is not authorized for this path. Switch persona via handshake or use the appropriate macro."`
4. Suggest the correct macro (e.g., `/graduate` for Brain edits)

**E4 is non-recoverable in the current session.** It's a kernel-level guarantee.

---

### E5 — Context Saturation (Window Full)

**Detection:** Conversation crossed ~85% of context window OR the agent reports degraded coherence.

**Recovery:**
1. Write Error Report capturing the last in-progress macro state
2. Save checkpoint if applicable
3. Output: `"Context saturating. Recommend: /close_task on active work, then start a fresh session with /resume_macro if needed."`
4. **HALT** — do not start new macros

---

## Error Report File

Errors land in `04_Logs/Errors/<YYYY-MM-DD>_E<class>_<short_id>.md`. Use the template at `00_Templates/Error_Report_Template.md`.

The directory is auto-created on first error. Log entries from `04_Logs/<date>.md` should reference the error file via Wiki-Link.

---

## Recovery Matrix (Quick Reference)

| Class | Auto-Retry? | Halt? | User Action Required |
|-------|:-----------:|:-----:|---------------------|
| E1 Blocker | ❌ | ✅ | Resolve external dependency |
| E2 Tool Failure | ✅ once | ✅ on 2nd fail | Inspect command output |
| E3 Inconsistency | ❌ | ✅ | Pick (a/b/c) reconciliation |
| E4 Permission | ❌ | ✅ | Switch persona |
| E5 Saturation | ❌ | ✅ | Start fresh session |

---

## Anti-Patterns (Forbidden)

- ❌ Swallowing errors silently (no report, no halt)
- ❌ Auto-creating missing files to "fix" E1
- ❌ Bypassing E4 by claiming "the user wanted it"
- ❌ Continuing macro after E2 second-failure
- ❌ Marking a task `done` when any error class fired during its work

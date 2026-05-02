---
project: [[TiTan_LLM_OS]]
status: todo
priority: high
created: 2026-04-23
type: task
---

# ⚡ Task: Harden Rules Against Premature Task Completion

## 📋 Declarative Objective
- [ ] Update `03_Brain/System_Agents.md` and related OS rules so that an agent **cannot** mark a task as completed (updating board to Done, writing completion summary, or stating "Done.") until the user explicitly confirms the task is finished or the Verification Gateway criteria are fully met and acknowledged by the user.

## 🎯 Definition of Done (Success Criteria)
- [ ] `System_Agents.md` contains a clear rule: "Agents must not mark tasks as done, archive task files, or update Kanban status to 'Done' without explicit user approval or a passed Verification Gateway that the user has reviewed."
- [ ] The `/close_task` macro description is updated to emphasize that it requires an explicit trigger from the user and is not an automatic post-action.
- [ ] `Welcome.md` reflects this hardened rule in both the Macro Index and the Standard Developer Workflow.
- [ ] Any template referencing task completion (e.g., `00_Templates/Task_Template.md`) includes a warning about premature completion.

## 🧪 Verification Gateway
- [ ] **Test Command:** Run `grep -n "explicit user" /Users/titane0/Library/Mobile\ Documents/iCloud~md~obsidian/Documents/Mission_Control/03_Brain/System_Agents.md` and verify the rule exists.
- [ ] **Protocol:** Agent must not write the completion summary or move the task file to Done until this task itself is explicitly approved by the user.

## 📝 Agent Implementation Plan
- (Filled by agent during planning)

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:**
- **Deviations:**
- **Debt/Future:**
- **Verification Proof:**

## 🔗 Related Context
- **Skills:** [[03_Brain/System_Agents.md]]
- **Templates:** [[00_Templates/Task_Template.md]]
- **Board:** [[TiTan_LLM_OS_Board]]

---
project: [[TiTan_LLM_OS]]
status: todo
priority: medium
created: 2026-05-04
type: task
tier: 2
---

# ⚡ Task: Create Tool/Skill Registry

## 📋 Declarative Objective
- [ ] Decouple tools from macros. Today `/close_task` hardcodes file moves, kanban updates, log appends as one blob. Extract these into a Tool Registry so macros become compositions of declared tools.

## 🎯 Definition of Done (Success Criteria)
- [ ] `03_Brain/Tool_Registry.md` exists, lists all atomic tools with Input/Output/Errors/Idempotent flags
- [ ] All current macros in `System_Agents.md` rewritten to invoke registered tools (no embedded shell logic)
- [ ] At least 6 tools registered: create_task, update_kanban, append_log, archive_file, populate_summary, scan_inbox

## 🧪 Verification Gateway
- [ ] **Test Command:** Diff `System_Agents.md` before/after. Confirm macros are now thin orchestration layers.
- [ ] **Protocol:** No tool logic embedded inline; everything references the registry.

## 📝 Agent Implementation Plan
1. Create `03_Brain/Tool_Registry.md` with tool manifest table
2. Refactor each macro in `System_Agents.md` to use `Invoke: tool_name(args)` syntax
3. Document tool error contracts in registry

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** TBD
- **Deviations:** TBD
- **Debt/Future:** TBD
- **Verification Proof:** TBD

## 🔗 Related Context
- **Best Practice:** LangGraph tool declarations; OpenAI Agents SDK function-tool pattern
- **Plan File:** Section 3.5

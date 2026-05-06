---
project: [[TiTan_LLM_OS]]
status: todo
priority: medium
created: 2026-05-04
type: task
tier: 2
---

# ⚡ Task: Implement Durable Execution & Checkpointing

## 📋 Declarative Objective
- [ ] Make multi-step macros resumable. If `/close_task` fails after step 3 of 5, next invocation should resume from step 4, not restart. Inspired by LangGraph's checkpoint architecture.

## 🎯 Definition of Done (Success Criteria)
- [ ] `04_Logs/Checkpoints/` directory exists
- [ ] All multi-step macros write checkpoint JSON between steps
- [ ] `/resume_macro [macro_name]` macro registered
- [ ] Test: kill a macro mid-step, run `/resume_macro`, finishes correctly

## 🧪 Verification Gateway
- [ ] **Test Command:** Start `/close_task X`, abort after step 2. Run `/resume_macro close_task`. Verify completion.
- [ ] **Protocol:** Final state matches what direct `/close_task X` would produce.

## 📝 Agent Implementation Plan
1. Define checkpoint schema: `{macro, args, completed_steps, last_state, timestamp}`
2. Update each multi-step macro to write checkpoints
3. Implement `/resume_macro` with checkpoint loader
4. Document in `Welcome.md`

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** TBD
- **Deviations:** TBD
- **Debt/Future:** TBD
- **Verification Proof:** TBD

## 🔗 Related Context
- **Best Practice:** LangGraph durable execution
- **Plan File:** Section 3.6

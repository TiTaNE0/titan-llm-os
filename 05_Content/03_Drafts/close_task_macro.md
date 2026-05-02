---
title: close_task_macro
status: Draft
source_project: [[TiTan_LLM_OS]]
tags: #AICoding #Obsidian #LocalLLM #DevWorkflow #TiTanLLMOS
publish_date: 2026-04-20
---

%% AI SYSTEM INSTRUCTIONS FOR DRAFTING:
1. Tone: Practical Israeli dev, slightly sarcastic, short punchy sentences, zero corporate fluff.
2. Conceptual Framing: The vault/memory is local, structured, and persistent. The agent can be ANY cloud LLM (OpenCode, Claude, etc.). We are giving cloud brains a perfect local memory. Never frame this as a "Local LLM-only" setup.
3. Structure: Keep tweets short. Force a "dogfooding" meta-reference where applicable.
%%

**Tweet 1 (Hook + Image)**
We just murdered the "end of day" guilt trip. 🔪
No more frantic daily summaries trying to remember what you did 8 hours ago.
[@asset:close_task_concept.png]

**Tweet 2 (Problem)**
Remember `/close_day`? That bloated macro that made you:
- Git diff like a detective at midnight
- Write bulleted lies about "resolved blockers" 
- Feel guilty for not doing enough
All for what? A log nobody reads.
Spoiler: It was never about tracking. It was about performance theater.

**Tweet 3 (Steps / Architecture)**
We replaced it with `/close_task [[Task_Name]]` - atomic task finalization.
One command. One task. Zero ambiguity.
How it works:
1. Points at a specific task file in 02_Tasks/
2. Extracts technical facts from THIS session (not yesterday's fog)
3. Auto-populates the task's ## 🏁 COMPLETION SUMMARY
4. MOVES the file to 99_Archive/Tasks/2026/ IMMEDIATELY
5. Updates Kanban to Done
6. Logs ONE LINE to today's log: `- [date] ✅ [[Task]] done: <facts>`

**Tweet 4 (Steps / Architecture)**
The magic? It's ATOMIC.
No more batch processing theater where you "close" 3 tasks but only actually did 1.5.
Each `/close_task` is a snapshot of what you JUST finished.
If you did nothing? Don't run it. Simple.
This isn't productivity porn - it's honest accounting.

**Tweet 5 (Demo + Proof)**
[@asset:close_task_execution.png]
Real session just now:
- Ran `/close_task close_task_macro_rename`
- Task file got populated with SPECIFIC edits:
  • System_Agents.md:38-44 (replaced /close_day)
  • Welcome.md:14 (macro index) 
  • Welcome.md:80 (workflow step)
- File MOVED to archive before this tweet finished
- Log got: `- [2026-04-20] ✅ [[close_task_macro_rename]] completed: Migrated from batch /close_day to atomic /close_task macro with immediate archive and 1-line logging.`

**Tweet 6 (Results + CTA)**
Result? Your brain gets credit for actual work, not end-of-day fiction.
Your logs become useful again - greppable, scannable, honest.
Try it: Finish a task. Run `/close_task [[Your_Task_Name]]`. Feel the clarity.
Still using `/close_day`? You're doing it wrong. Fight me.
What's your task completion ritual? Or are you still lying to yourself at 5pm?
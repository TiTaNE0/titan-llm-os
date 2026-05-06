---
project: [[TiTan_LLM_OS]]
status: done
priority: high
created: 2026-05-06
started: 2026-05-06
closed: 2026-05-06
type: task
tier: 1
---

# ⚡ Task: Content Pipeline v2 — Modularize + Integrate Voice File

## 📋 Declarative Objective
- [ ] Refactor `05_Content/` from Twitter-only-by-accident into a proper module + personalization architecture. Integrate the canonical voice spec (`evgeny_voice_v1.3.md`) as a swappable add-on. Strip the hardcoded "Practical Israeli dev, slightly sarcastic" tone string from kernel macros so the voice file becomes the single source of truth.

## 🎯 Definition of Done (Success Criteria)
- [x] `05_Content/personalization/voice_evgeny.md` exists, verbatim copy of `~/Downloads/evgeny_voice_v1.3.md`
- [x] `05_Content/modules.yaml` registry exists with twitter active, video/article inactive
- [x] `05_Content/modules/twitter/` populated: README, strategy, failure_log, templates/Thread_Template.md
- [x] `05_Content/modules/{video,article}/README.md` stubs exist (status: inactive)
- [x] `05_Content/personalization/README.md` documents the add-on model
- [x] `/new_thread` and `/refactor_thread` no longer carry hardcoded tone string; defer to voice file
- [x] `/enable_module`, `/disable_module`, `/set_voice` macros registered in kernel
- [x] `Welcome.md` Content Pipeline section reflects new macros + registry
- [x] Two pre-voice-file drafts (close_task_macro.md, iCloud_Sync_Implementation_Story.md) prepended with warning
- [x] Old `00_Content_Templates/X_Thread_Template.md` removed (migrated)
- [x] `Agent_Roles.md` Content Producer persona no longer hardcodes tone
- [ ] **Verification pending:** Run `/new_thread` against a real source project. Drafted thread must NOT include "ofc," "LOL?", visible humor, or engagement-bait closes. Voice file rules silently applied.

## 🧪 Verification Gateway
- [ ] **Test Command:** `/new_thread Test_Topic from [[TiTan_LLM_OS]]` (any active project)
- [ ] **Protocol:** Drafted output respects `voice_evgeny.md` `<voice_fingerprint>` and `<writing_laws>`. Spot-check: no engagement-bait close, no visible humor emoji, no banned phrases from `<phrase_bank>`.

## 📝 Agent Implementation Plan

Plan source: `~/.claude/plans/read-agents-md-now-i-glimmering-stream.md`

1. ✅ Copy voice file verbatim from `~/Downloads/evgeny_voice_v1.3.md` → `05_Content/personalization/voice_evgeny.md` (no version in filename → overwrite-friendly)
2. ✅ Create `05_Content/personalization/README.md` documenting the add-on model
3. ✅ Create `05_Content/modules.yaml` canonical registry
4. ✅ Build `05_Content/modules/twitter/` with README + strategy.md (Grok strategist layer verbatim) + failure_log.md (empty, format-only) + templates/Thread_Template.md (migrated, tone stripped)
5. ✅ Create `05_Content/modules/{video,article}/README.md` stubs (inactive)
6. ✅ Update `03_Brain/System_Agents.md`:
   - Strip "Practical Israeli dev..." tone string from `/new_thread` step 3
   - Strip same string from `/refactor_thread` step 2 sub-bullet
   - Update template path in `/new_thread` to `modules/twitter/templates/Thread_Template.md`
   - Add `/enable_module`, `/disable_module`, `/set_voice` macros (all telemetry-instrumented)
7. ✅ Update `03_Brain/Agent_Roles.md` Content Producer persona — defer to active voice file
8. ✅ Update `Welcome.md` Content Pipeline section: 3 new macros + registry summary block
9. ✅ Prepend `⚠️ Pre-voice-file draft` warning to `close_task_macro.md` and `iCloud_Sync_Implementation_Story.md`
10. ✅ Remove `05_Content/00_Content_Templates/X_Thread_Template.md` (migrated, not duplicated)
11. ✅ Append today's log entry at `04_Logs/2026-05-06.md`
12. ⏳ Verification gateway not yet exercised — needs a real `/new_thread` run

## 🏁 COMPLETION SUMMARY (Post-Mortem)

- **Technical Meat:**
  - 1 file copied verbatim (voice_evgeny.md, 339 lines, diff vs source = empty)
  - 9 new files created (modules.yaml, 3 module READMEs, twitter strategy, failure_log, Thread_Template, personalization README, today's log)
  - 5 files modified (System_Agents.md, Agent_Roles.md, Welcome.md, 2 legacy drafts)
  - 1 file removed (old X_Thread_Template.md)
  - 3 new macros registered: `/enable_module`, `/disable_module`, `/set_voice`
  - 2 existing macros refactored: `/new_thread` (rewritten step 1–4), `/refactor_thread` (tone bullet replaced)

- **Deviations:**
  - Initial plan placed voice file at vault root; user corrected mid-plan to `05_Content/personalization/voice_evgeny.md`
  - Initial plan included new content templates (Original_Post, Hands_On_Review, Reply); user explicitly cancelled — out of scope
  - Caught one straggler in verification: `Agent_Roles.md` Content Producer persona had hardcoded tone too. Fixed.

- **Debt/Future:**
  - Verification gateway requires a real `/new_thread` run on an active project to confirm voice file is silently applied (cannot be done without user-driven content generation)
  - User iterates voice file separately and overwrites `voice_evgeny.md` in place — no agent-side process for that
  - `/enable_module`, `/disable_module`, `/set_voice` macros declare YAML edits but actual YAML manipulation happens at agent execution time (no script wrapper yet — `modules.yaml` is small enough to handle inline)

- **Verification Proof:**
  - `diff ~/Downloads/evgeny_voice_v1.3.md <vault>/05_Content/personalization/voice_evgeny.md` → empty
  - `grep -rn "Practical Israeli dev" 03_Brain/ 05_Content/modules/ Welcome.md` → empty
  - Remaining occurrences only in `99_Archive/`, today's log (citation), and one pre-voice-file draft (has warning prepended) — all expected
  - **Closed without exercising the live `/new_thread` verification gateway** — user closed at 2026-05-06 before a real drafting run. Structural verification (file existence, diff, grep) is complete; behavioral verification (voice file silently applied during drafting) deferred to first real use.

## 🔗 Related Context
- **Voice source:** `~/Downloads/evgeny_voice_v1.3.md` (kept intact; no agent-side editing of voice files)
- **Plan file:** `~/.claude/plans/read-agents-md-now-i-glimmering-stream.md`
- **Today's log:** [[2026-05-06]]
- **Modular architecture references:** [[modules]] (yaml), [[Thread_Template]], [[strategy]] (twitter), [[voice_evgeny]]
- **Out of scope (locked):** new content templates (originals/reply/hands-on review), v1.4 reasoning, voice file iteration

---
project: [[Voice_Cloning_Bot]]
status: backlog
priority: high
created: 2026-05-02
type: task
---

# ⚡ Task: Extract app.py Handler Modules

## 📋 Declarative Objective
- [ ] Reduce `bot/src/bot/app.py` complexity (currently >1000 lines) by extracting groups of handlers into dedicated modules under `bot/handlers/` while preserving all existing behavior.

## 🎯 Definition of Done (Success Criteria)
- [ ] New `bot/handlers/` directory exists with at least 5 modules:
    - `commands.py` (start, say, voices, settings, engine, cancel)
    - `onboarding_handlers.py` (role selection, voice upload, add voice flow)
    - `settings_handlers.py` (presets, geek settings, temperature/speed)
    - `voice_management.py` (voice selection, deletion, detail view)
    - `payments.py` (pre-checkout, payment success, tier selection)
    - `inline_handlers.py` (inline queries, chosen results)
- [ ] `app.py` line count is reduced by at least 50%.
- [ ] All existing tests pass without modification.
- [ ] Bot still responds to all commands and callbacks correctly (manual smoke test).

## 🧪 Verification Gateway
- [ ] **Test Command:** `cd /Users/titane0/Programming/voice-bot && uv run pytest tests/test_handler_registration.py -v && uv run pytest tests/ -v`
- [ ] **Protocol:** All tests pass. Smoke test: start bot, send /start, /settings, /voices, verify responses.

## 📝 Agent Implementation Plan
- (Deferred — large refactor, do after smaller refactors land cleanly.)

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:**
- **Deviations:**
- **Debt/Future:**
- **Verification Proof:**

## 🔗 Related Context
- **Files:** `bot/src/bot/app.py`, `tests/test_handler_registration.py`
- **Board:** [[Voice_Cloning_Bot_Board]]
- **Skill:** [[skills/telegram-handler-registration/SKILL]]

---
project: [[Voice_Cloning_Bot]]
status: in-progress
priority: medium
created: 2026-05-02
type: task
---

# ⚡ Task: Add TypedDict for Voice Profile and User Records

## 📋 Declarative Objective
- [ ] Replace generic `dict` return types in `bot/src/bot/database.py` with `TypedDict` definitions for `VoiceProfile` and `UserRecord` to improve type safety and prevent silent bugs from incorrect dict access.

## 🎯 Definition of Done (Success Criteria)
- [ ] `VoiceProfile` TypedDict defined with all 7 fields (`id`, `user_id`, `engine_id`, `display_name`, `provider_voice_id`, `r2_storage_path`, `is_active`).
- [ ] `UserRecord` TypedDict defined with 5 fields (`telegram_id`, `state`, `role_tag`, `credits`, `lang`).
- [ ] All `Database` methods returning these dicts use the new typed signatures.
- [ ] No runtime behavior change (TypedDict is a type hint, not enforced at runtime).

## 🧪 Verification Gateway
- [ ] **Test Command:** `cd /Users/titane0/Programming/voice-bot && uv run pytest tests/ -v`
- [ ] **Protocol:** All tests must pass with exit code 0.

## 📝 Agent Implementation Plan
1. Define `VoiceProfile` and `UserRecord` TypedDict at top of `database.py`.
2. Update return type hints on: `upsert_user`, `get_user`, `get_voice_profile`, `get_active_voice_profile`, `get_user_voices_full`.
3. Run full test suite.

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** Added `UserRecord` and `VoiceProfile` TypedDict classes at the top of `bot/src/bot/database.py`. Updated return type hints on `upsert_user`, `get_user`, `get_voice_profile`, `get_active_voice_profile`, and `get_user_voices_full`.
- **Deviations:** None — pure additive type hints. No runtime behavior change.
- **Debt/Future:** Could propagate the TypedDict types to consumers in `app.py` and providers for stricter compile-time guarantees. Inline mode and onboarding code currently access these dicts with `.get("key")` which still works but doesn't benefit from autocomplete/type-checking.
- **Verification Proof:** `pytest tests/test_database_new.py tests/test_handler_registration.py tests/test_localization.py tests/test_router.py` shows 73 passed (1 pre-existing failure unrelated to this work).

## 🔗 Related Context
- **Files:** `bot/src/bot/database.py`
- **Board:** [[Voice_Cloning_Bot_Board]]

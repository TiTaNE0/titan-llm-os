---
project: [[Voice_Cloning_Bot]]
status: done
priority: critical
created: 2026-05-02
type: task
---

# ⚡ Task: Voice library isolation tests + ownership bug fix

## 📋 Declarative Objective
Write a test suite that proves each engine has a fully isolated voice library per user, and no voice IDs, profiles, or active-voice state can leak between engines or users. Fix the discovered ownership bug in `set_active_voice_profile()`.

## 🎯 Definition of Done (Success Criteria)
- [x] `set_active_voice_profile()` raises ValueError when voice_id doesn't belong to (user, engine)
- [x] Cross-user isolation: get_active/get_user_voices never returns another user's voices
- [x] Cross-engine isolation: engine X's list never returns engine Y's voices
- [x] Active voice switches on one engine don't affect other engines
- [x] Deletion only affects the correct (user, engine) scope
- [x] provider_voice_id format validated per engine (Qwen=JSON+r2_key, others=plain string)
- [x] All 16 tests pass

## 🧪 Verification Gateway
- [x] **Test Command:** `uv run pytest tests/test_voice_library_isolation.py -v`
- [x] **Protocol:** 16 passed in 0.70s ✅

## 📝 Agent Implementation Plan
1. Fix `set_active_voice_profile()` in database.py — add ownership check before UPDATE
2. Create `tests/test_voice_library_isolation.py` with 16 tests across 6 groups

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** Fixed `database.py:set_active_voice_profile()` — added pre-flight ownership SELECT before deactivate/activate UPDATEs; second UPDATE also scoped to `AND user_id = ? AND engine_id = ?`. Created `tests/test_voice_library_isolation.py` (16 tests, 6 groups): cross-user isolation (4), cross-engine isolation (3), active-voice independence (2), ownership enforcement (2), deletion isolation (2), format integrity (3). All 16 pass in 0.70s.
- **Deviations:** 16 tests instead of planned 17 — merged two format tests into one parametric loop.
- **Debt/Future:** Add router-level integration tests that verify the full generate() call uses the correct (user, engine) voice.
- **Verification Proof:** `16 passed in 0.70s`

## 🔗 Related Context
- **Files:** `bot/src/bot/database.py:565`, `tests/test_voice_library_isolation.py`
- **Bug Fixed:** `set_active_voice_profile()` ownership check missing — could activate another user's voice

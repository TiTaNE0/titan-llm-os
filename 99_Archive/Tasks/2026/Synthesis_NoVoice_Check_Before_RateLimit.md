---
project: [[Voice_Cloning_Bot]]
status: in-progress
priority: high
created: 2026-05-02
type: task
---

# ⚡ Task: Hoist No-Voice Guard Above Rate-Limit / Length Checks

## 📋 Declarative Objective
- [ ] In `_generate_and_send_voice` and the inline / regenerate / auto-inline paths, the rate-limit and text-length checks fire **before** the "user has no active voice" check. A pre-consent or pre-cloning user typing text consumes a `synthesis_minute` slot for an action that physically cannot synthesize anything. Reorder so we never burn quota on a request that can't produce audio.

## 🎯 Definition of Done (Success Criteria)
- [ ] In `_generate_and_send_voice` (`bot/src/bot/app.py:1686`), the "no active voice" check (currently at ~line 1660 inside the try/except) is hoisted **above** `_check_text_length` and `_enforce_rate_limit` calls.
- [ ] Same reorder in `regenerate_voice` (`app.py:~2538`), `handle_inline_generate` (`app.py:~2785`), and `_process_automatic_generation` (`app.py:~2956`) — wherever the active-voice lookup currently lives below validation/rate-limit.
- [ ] If the user has no active voice, the existing "Set up your voice" deep-link reply still fires (no UX regression).
- [ ] The text-length check (free vs premium cap) is still respected when the user *does* have a voice.
- [ ] Tests: extend `tests/test_rate_limit.py` (or write a new file) — assert that calling `_generate_and_send_voice` for a user with no active voice does NOT consume `synthesis_minute` slot.

## 🧪 Verification Gateway
- [ ] **Test command:** `cd /Users/titane0/Programming/voice-bot && uv run pytest tests/ -v`
- [ ] **Protocol:** New test passes; 237-pass count holds (7 pre-existing failures unchanged).
- [ ] **Manual smoke:**
    1. As a brand-new user (no voice yet) send 12 short text messages quickly. None should be rate-limited (because none consumed a slot). The first should reply with the "Set up your voice" message.
    2. After cloning a voice, send 12 messages quickly — synthesis_minute (10/60s) should kick in on the 11th.

## 📝 Agent Implementation Plan
1. In `_generate_and_send_voice`, move `engine_id = await self.db.get_active_engine(user_id)` and `active_voice = await self.db.get_active_voice_profile(...)` lookups + the no-voice early-return to BEFORE `_check_text_length` and `_enforce_rate_limit` calls.
2. Repeat in `regenerate_voice`, `handle_inline_generate`, `_process_automatic_generation`.
3. Run full suite to ensure no regressions in existing rate-limit / text-length tests.
4. Add the new regression test.

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** Hoisted the `engine_id = await self.db.get_active_engine(...)` + `active_voice = await self.db.get_active_voice_profile(...)` lookups + no-voice early-return ABOVE `_check_text_length` and `_enforce_rate_limit` at all 4 synthesis call sites: `_generate_and_send_voice`, `regenerate_voice`, `handle_inline_generate`, `_process_automatic_generation`. The downstream try/except wrapping the actual synthesis is unchanged. ElevenLabs daily char cap and credit deduction remain after the rate-limit check. Regression test in `tests/test_rate_limit.py::test_generate_and_send_voice_does_not_burn_slot_when_no_active_voice` asserts the synthesis_minute window is empty after a no-voice request.
- **Deviations:** None.
- **Debt/Future:** Same hoist could be applied to inline auto-generation's user-facing message ordering (the "generating..." status currently flashes before the no-voice guard), but it's a tiny UX touch-up not worth its own commit.
- **Verification Proof:** `pytest tests/` → 246 passed, 7 pre-existing failures unchanged. Committed as `bd96833`.

## 🔗 Related Context
- **Files:** `bot/src/bot/app.py` (4 call sites identified above)
- **Found by:** Flow audit on 2026-05-02 (issue H2)
- **Related:** [[Phase1_RateLimiting_Synthesis_And_Cloning]], [[Phase1_Text_Length_Caps_1k_Free_5k_Premium]]
- **Board:** [[Voice_Cloning_Bot_Board]]

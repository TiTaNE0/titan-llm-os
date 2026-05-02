---
project: [[Voice_Cloning_Bot]]
status: in-progress
priority: critical
created: 2026-05-02
type: task
---

# ⚡ Task: Phase 1 — Per-User Rate Limiting (Synthesis & Cloning)

## 📋 Declarative Objective
- [ ] Prevent any single Telegram user from triggering more than N paid TTS-synthesis or voice-clone calls per minute / hour / day, in order to protect the ElevenLabs/RunPod budget from spam or programmatic abuse.

## 🎯 Definition of Done (Success Criteria)
- [ ] New module `bot/src/bot/utils/rate_limit.py` implements an in-memory sliding-window `RateLimiter` keyed by `(user_id, bucket_name)`.
- [ ] Buckets configured: `synthesis_minute` (10/60s), `synthesis_hour` (60/3600s), `clone_day` (5/86400s).
- [ ] `_generate_and_send_voice()` at `bot/src/bot/app.py:1553` (single synthesis chokepoint) consults `synthesis_minute` and `synthesis_hour` before doing any paid work.
- [ ] Voice-cloning entry points consult `clone_day`:
    - `handle_voice_upload()` at `bot/src/bot/app.py:1041`
    - `handle_audio_upload()` at `bot/src/bot/onboarding.py:230`
    - `handle_add_voice_audio()` at `bot/src/bot/onboarding.py:615`
- [ ] When rate-limited, user sees a localized message (`error_rate_limited_md`) showing seconds-until-retry. EN + RU strings present in `bot/src/bot/messages.py`.
- [ ] Existing `_processing` lock at `onboarding.py:278` / `:353` is preserved as the in-flight guard (orthogonal concern).
- [ ] Limits are configurable via env vars with the listed defaults (e.g. `RL_SYNTH_PER_MIN`, `RL_SYNTH_PER_HOUR`, `RL_CLONE_PER_DAY`).

## 🧪 Verification Gateway
- [ ] **Test Command:** `cd /Users/titane0/Programming/voice-bot && uv run pytest tests/test_rate_limit.py -v && uv run pytest tests/ -v`
- [ ] **Protocol:** All existing tests pass + new `tests/test_rate_limit.py` covers: (a) 11th call within 60s rejected, (b) clock advance to 61s allows next call, (c) different user IDs have independent counters, (d) `clone_day` independent from `synthesis_minute`.
- [ ] **Manual smoke:** Send 12 `/say hi` calls in 30 seconds → 11th and 12th return localized rate-limit message. Existing `/say` flow unaffected when under cap.

## 📝 Agent Implementation Plan
1. Create `bot/src/bot/utils/rate_limit.py` with `RateLimiter` class (sliding window via deque of timestamps per `(user_id, bucket)`). Provide `check(user_id, bucket) -> Optional[int]` returning seconds-to-wait if denied, or `None` if allowed and recorded.
2. Define bucket configs as a module-level dict, reading from env with defaults.
3. Instantiate a single `RateLimiter` on `VoiceBot` in `__init__`.
4. Add a tiny helper `_enforce_rate_limit(update, user_id, bucket, TEXTS) -> bool` on `VoiceBot` — returns True if allowed, else replies with the localized message and returns False.
5. Add the helper call at the top of: `_generate_and_send_voice`, `regenerate_voice` (since it bypasses say_command), `handle_inline_generate`, `handle_voice_upload`, `OnboardingManager.handle_audio_upload`, `OnboardingManager.handle_add_voice_audio`.
6. Add EN + RU strings: `error_rate_limited_md` with `{retry_after}` placeholder.
7. Write `tests/test_rate_limit.py` (4 cases above, mocking `time.monotonic()` via `freezegun` or manual injection).

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:**
  - New `bot/src/bot/utils/rate_limit.py` — sliding-window `RateLimiter` keyed by `(user_id, bucket)` with 4 default buckets read from env: `synthesis_minute` (10/60s), `synthesis_hour` (60/3600s), `clone_day` (5/86400s), `elevenlabs_chars_day` (5000/86400s).
  - Two public methods: `check(user_id, bucket, cost=1)` for single-bucket, `check_multi(user_id, [buckets], cost=1)` for atomic multi-bucket (peeks all → records all only if all pass — otherwise no slots consumed).
  - `VoiceBot._enforce_rate_limit(user_id, buckets, update, cost=1)` helper handles single-string or list, replies with localized `error_rate_limited_md` on denial.
  - Wired into 6 entry points: `_generate_and_send_voice` (chokepoint, synthesis_minute+synthesis_hour, skipped on `skip_credit_check=True` to preserve onboarding demo), `regenerate_voice`, `handle_inline_generate` (uses `query.answer(show_alert=True)` since `query.message` may be None), `_process_automatic_generation` (background task — no Update; surfaces via message edit), `handle_voice_upload` (clone_day), `OnboardingManager.handle_audio_upload` and `handle_add_voice_audio` (clone_day, after passing `RateLimiter` via constructor).
  - EN + RU `error_rate_limited_md` strings with `{retry_after}` placeholder.
  - 8 unit tests in `tests/test_rate_limit.py` covering: (a) 11th call denied, (b) clock advance releases quota, (c) per-user isolation, (d) per-bucket isolation, (e) multi-bucket atomicity (no partial consumption), (f) unknown bucket raises, (g) `reset(user_id)` scoping, (h) variable-cost (char-based) bucket.
- **Deviations:**
  - Discovered and fixed a multi-bucket race during implementation: original `check()` would consume a slot in bucket A even if the subsequent bucket-B check denied. Added atomic `check_multi()` that peeks all buckets first, then records only if all pass. Test (e) covers this.
  - Inline auto-mode (`_process_automatic_generation`) cannot use `_enforce_rate_limit` because it has no `Update` (background task spawned from `handle_message`). Used `rate_limiter.check_multi()` directly and surfaced denial via `context.bot.edit_message_text`.
  - `OnboardingManager.__init__` got an optional `rate_limiter` parameter (default `None` for backward-compat with existing tests/fixtures); when present, the two onboarding voice-clone paths self-enforce `clone_day`.
- **Debt/Future:**
  - Single-instance only; if we scale to >1 replica, swap the `dict[(user_id, bucket)] -> deque` storage for a Redis backend (interface stays the same).
  - 4 pre-existing test failures in `tests/test_onboarding.py` and `tests/test_database_new.py` are NOT caused by this work (verified by `git stash` re-run). Worth a separate cleanup task.
- **Verification Proof:** `pytest tests/test_rate_limit.py tests/test_handler_registration.py tests/test_localization.py tests/test_database_new.py tests/test_router.py` → 81 passed, 1 pre-existing failure unrelated to this task. New `tests/test_rate_limit.py` → 8 passed in 0.02s.

## 🔗 Related Context
- **Files:** `bot/src/bot/app.py`, `bot/src/bot/onboarding.py`, `bot/src/bot/messages.py`, `bot/src/bot/utils/rate_limit.py` (new), `tests/test_rate_limit.py` (new)
- **Existing Pattern:** `_processing` lock at `bot/src/bot/onboarding.py:278` (in-flight guard, kept orthogonal)
- **Plan:** [[Production_Hardening_Sprint_Plan]]
- **Board:** [[Voice_Cloning_Bot_Board]]

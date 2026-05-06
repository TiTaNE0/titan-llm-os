---
project: [[Voice_Cloning_Bot]]
status: in-progress
priority: high
created: 2026-05-03
type: task
---

# ⚡ Task: Synth Retry on NoSuchKey + Broken-Voice Recovery

## 📋 Declarative Objective
- [ ] Even with V3.1-only cloning, occasional first-synth-after-clone returns the 152-byte NoSuchKey while Smallest's index propagates. Add a retry layer so transient cases self-heal, and a clean recovery path so confirmed broken voices are queued for cleanup and the user can re-record.

## 🎯 Definition of Done (Success Criteria)
- [ ] New `BrokenVoiceError(TTSProviderError)` in `bot/src/bot/providers/base.py`.
- [ ] In `SmallestProvider.synthesize`: when the existing Tier-4 NoSuchKey detection fires, wrap the request in a 3-attempt retry loop with 1s/2s/4s backoff. Other errors (4xx, JSON error responses, non-RIFF) raise immediately.
- [ ] After 3 NoSuchKey attempts: raise `BrokenVoiceError` (subclass of `TTSProviderError`) with a clear message.
- [ ] Optional 500ms `await asyncio.sleep(0.5)` inside `clone_voice` after V3.1 success, before returning — defensive against eventual-consistency.
- [ ] `OnboardingManager.handle_audio_upload` Stage 3 catches `BrokenVoiceError` separately:
    - Calls `db.queue_external_deletion(user_id, provider_voice_id, SMALLEST_LIGHTNING)` to clean up
    - Calls `db.delete_voice_profile(voice_uuid)` to remove the local row
    - Calls `db.set_user_state(user_id, UserState.WAITING_FOR_AUDIO)`
    - Sends new EN+RU `error_voice_broken_retry_md`
- [ ] Generic `Exception` in Stage 3 keeps the existing recovery flow (state stays READY).

## 🧪 Verification Gateway
- [ ] **Test command:** `cd /Users/titane0/Programming/voice-bot && uv run pytest tests/test_providers.py tests/test_consent_gate.py tests/ -v`
- [ ] **Protocol:** New tests pass: `test_smallest_synth_retries_on_nosuchkey`, `test_smallest_synth_raises_broken_voice_after_retries`, `test_onboarding_broken_voice_re_queues_for_audio`.
- [ ] **Bot startup smoke** passes.
- [ ] **Manual via Telegram (mock):** mock `/lightning-v3.1/get_speech` to return 152-byte NoSuchKey → expect 3 retries → after fails, voice queued for deletion → state=WAITING_FOR_AUDIO → user can record again.

## 📝 Agent Implementation Plan
1. Add `BrokenVoiceError(TTSProviderError)` to `base.py`.
2. Refactor `SmallestProvider.synthesize`: extract the request-and-verify into a private helper, wrap in retry loop scoped to NoSuchKey detection.
3. Add 500ms sleep in `clone_voice` after V3.1 success.
4. Modify `OnboardingManager.handle_audio_upload` Stage 3 to catch `BrokenVoiceError` separately and execute the recovery path.
5. Add EN+RU `error_voice_broken_retry_md`.
6. Add 3 tests.
7. Run full suite + bot startup smoke; commit.

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** New `BrokenVoiceError(TTSProviderError)` in `bot/src/bot/providers/base.py`. `SmallestProvider.synthesize` wraps the request + 4-tier verification in a 3-attempt retry loop SCOPED to NoSuchKey (Tier 4) only — other errors (HTTP non-200, JSON error, non-RIFF) raise immediately. After 3 NoSuchKey attempts → `BrokenVoiceError`. `SmallestProvider.clone_voice` got a 500ms unconditional `asyncio.sleep` after V3.1 success (defensive against eventual-consistency window). `OnboardingManager.handle_audio_upload` Stage 3 catches `BrokenVoiceError` separately: queues orphan via `queue_external_deletion`, deletes local voice row, resets state to `WAITING_FOR_AUDIO`, sends new `error_voice_broken_retry_md`. Generic `Exception` path unchanged (transient failure → state stays READY). 5 new tests: 4 in `tests/test_smallest_synth_retry.py` (retry-then-succeed, persistent NoSuchKey → BrokenVoiceError, 5xx fatal, isinstance check) + 1 in `tests/test_consent_gate.py::test_onboarding_broken_voice_re_queues_for_audio`. Updated 2 clone-retry tests for the new +0.5s post-clone settle.
- **Deviations:** None. The 152-byte path in Tier 2 (size check) special-cases NoSuchKey content too — production reports show the error sometimes lands as <500-byte content with the marker embedded. Both paths now retry.
- **Debt/Future:** Could expose retry counts as env vars. Could surface a one-shot delay between clone success and Stage 3 demo synth in onboarding (in addition to the post-clone 500ms inside the provider) but the layered approach is sufficient for now.
- **Verification Proof:** `pytest tests/test_smallest_synth_retry.py` → 4 passed. `pytest tests/test_consent_gate.py::test_onboarding_broken_voice_re_queues_for_audio` → 1 passed. `pytest tests/` → 275 passed, 7 pre-existing failures unchanged. Bot smoke confirms `BrokenVoiceError` is a `TTSProviderError` subclass and provider imports + loads. Committed as `94a517e`.

## 🔗 Related Context
- **Files:** `bot/src/bot/providers/base.py`, `bot/src/bot/providers/smallest.py`, `bot/src/bot/onboarding.py`, `bot/src/bot/messages.py`, tests
- **Depends on:** Task 2 (no fallback removes one source of broken voices; Task 4 handles the residual eventual-consistency case)
- **Board:** [[Voice_Cloning_Bot_Board]]

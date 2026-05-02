---
project: [[Voice_Cloning_Bot]]
status: in-progress
priority: medium
created: 2026-05-02
type: task
---

# ⚡ Task: Onboarding Clone — Atomicity & Recoverable Failure States

## 📋 Declarative Objective
- [ ] `OnboardingManager.handle_audio_upload` does three things in sequence: (1) clone via Smallest, (2) `add_voice_profile` DB write, (3) demo synthesis + state→READY. Any partial failure between (1) and (3) leaks state. Make the flow atomic-ish: either (a) all three succeed and state is READY, or (b) the user is in a clean recoverable state.

## 🎯 Definition of Done (Success Criteria)
- [ ] **M1 — DB write fails after clone succeeded.** If `clone_voice_for(SMALLEST_LIGHTNING, …)` returns a `provider_voice_id` but `add_voice_profile` raises (unique constraint, DB lock, etc.), the orphaned external voice is **enqueued in `deletion_queue`** so the existing `_deletion_worker_loop` picks it up and deletes it from Smallest's servers. No silent leak.
- [ ] **M2 — Demo synthesis fails after voice profile written.** State transitions to `READY` **before** the demo synthesis attempt. If `router.generate(demo_text)` raises, the user sees a localized "your voice was saved, demo audio failed — send any text to /say" message, NOT the generic onboarding-broken error. The voice profile is usable; the user can retry synthesis manually.
- [ ] **No regression to the happy path** — successful onboarding still: clones → writes profile → moves to READY → sends demo audio → shows main menu.
- [ ] EN + RU localization string `error_demo_synthesis_failed_md` (or similar) covering the M2 message.
- [ ] Tests: extend `tests/test_consent_gate.py` or new file:
    - `test_onboarding_db_write_failure_queues_external_cleanup` — mock `clone_voice_for` to succeed, `add_voice_profile` to raise; assert a row landed in `deletion_queue` for the orphan.
    - `test_onboarding_demo_synthesis_failure_leaves_user_at_READY_with_voice` — mock clone + add_voice_profile to succeed, `router.generate` to raise; assert `set_user_state(READY)` was called and the user was shown the recovery message.

## 🧪 Verification Gateway
- [ ] **Test command:** `cd /Users/titane0/Programming/voice-bot && uv run pytest tests/ -v`
- [ ] **Protocol:** New tests pass; 237-pass count holds (7 pre-existing failures unchanged).
- [ ] **Manual smoke:** Temporarily break Smallest's API key → run `/start` → expect graceful "demo failed" message (not a generic crash). Inspect DB: voice profile exists, state=READY.

## 📝 Agent Implementation Plan
1. Wrap the `add_voice_profile` call in `handle_audio_upload` in a try/except. On failure, call `Database.queue_deletion(provider_voice_id, engine_id, r2_path=None)` (helper exists, used by `delete_all_user_data`). Re-raise or surface a localized error.
2. Reorder: call `set_user_state(READY)` immediately after `add_voice_profile` succeeds, BEFORE the demo synthesis block.
3. Wrap `router.generate(demo_text)` + `reply_voice` in their own try/except. On failure, send the new `error_demo_synthesis_failed_md` and still show the main menu (state is already READY).
4. Add EN+RU strings.
5. Write the two regression tests.

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** Split `handle_audio_upload` into 3 isolated try/except stages: (1) download + clone, (2) persist voice profile, (3) demo synthesis. New `Database.queue_external_deletion(user_id, provider_voice_id, engine_id, r2_storage_path)` helper factored out of `delete_all_user_data`'s deletion-queue insert pattern; called from Stage 2's failure handler so orphaned external voices get reaped by `_deletion_worker_loop`. State → READY moves BEFORE Stage 3 so a demo synth failure leaves the user at READY with a usable voice (recovery message points them at sending any text). New EN+RU `error_demo_synthesis_failed_md`. 2 regression tests in `tests/test_consent_gate.py`.
- **Deviations:** Test fixture lives in `test_consent_gate.py` (alongside other onboarding-flow tests) rather than a new file — reuses the established `_DEFAULT_USER_NO_CONSENT` + `_mock_dependencies` infrastructure.
- **Debt/Future:** Even queue-insert failure could be deferred to a structured recovery-log table; for now we just `logger.critical` and rely on operator inspection.
- **Verification Proof:** `pytest tests/` → 248 passed, 7 pre-existing failures unchanged. `pytest tests/test_consent_gate.py` → all 16 tests pass. Committed as `a811516`.

## 🔗 Related Context
- **Files:** `bot/src/bot/onboarding.py:357-500` (`handle_audio_upload`), `bot/src/bot/database.py` (deletion_queue helpers), `bot/src/bot/messages.py`
- **Reused:** `_deletion_worker_loop` (`bot/src/bot/app.py:619`), existing deletion_queue table schema
- **Found by:** Flow audit on 2026-05-02 (issues M1, M2)
- **Board:** [[Voice_Cloning_Bot_Board]]

---
project: [[Voice_Cloning_Bot]]
status: in-progress
priority: high
created: 2026-05-02
type: task
---

# ⚡ Task: Voice Setup — Use Displayed Script as Ref Text (Engine-Aware)

## 📋 Declarative Objective
- [ ] Eliminate the redundant "send me the text of what you just said" prompt in `/set_voice`. Make the wizard engine-aware: engines that don't need ref_text never ask; Qwen (the only family that needs ref_text) auto-uses the script the bot already displayed instead of asking the user to retype it.

## 🎯 Definition of Done (Success Criteria)
- [ ] New `needs_ref_text: bool = False` class attribute on `BaseTTSProvider`. Overridden to `True` on `QwenProvider` and `RunPodProvider`. All other providers inherit `False`.
- [ ] `set_voice_start` (`bot/src/bot/app.py:1095`) always shows the clone-script carousel (using `onboarding_lightning_prompt_md` + `clone_next_script` button + `clone_script_index = 0`), regardless of active engine. The script-less `onboarding_standard_prompt_md` branch is removed.
- [ ] `handle_voice_upload` (`bot/src/bot/app.py:1136`) consults `provider.needs_ref_text`:
    - If True (Qwen): retrieve the displayed script from `context.user_data["clone_script_index"]`, pass it to `finish_wizard` as ref_text, skip `AWAIT_REF_TEXT`. If `clone_script_index` is unexpectedly missing, fall back to the existing `AWAIT_REF_TEXT` path so the user can still type it.
    - If False (Lightning, ElevenLabs, Mistral): `finish_wizard(update, context, None)` — no prompt. (Lightning previously short-circuited; ElevenLabs/Mistral previously incorrectly went to `AWAIT_REF_TEXT`.)
- [ ] `finish_wizard` is unchanged — its existing Qwen-specific ref_text serialization at `app.py:1273–1296` already does the right thing.
- [ ] Onboarding (`OnboardingManager.handle_audio_upload`) is unchanged — Lightning doesn't need ref_text, so we don't force-store the script there.
- [ ] EN+RU strings unchanged — the existing `onboarding_lightning_prompt_md`, `wizard_btn_next_text`, and `wizard_voice_captured_md` (now defensive-only) all remain.

## 🧪 Verification Gateway
- [ ] **Test command:** `cd /Users/titane0/Programming/voice-bot && uv run pytest tests/test_voice_setup_uses_displayed_script.py tests/ -v`
- [ ] **Protocol:** All new tests pass + the existing 212-test count holds (4 pre-existing failures unchanged).
- [ ] **Manual smoke:**
    1. `/engine` → RUNPOD_QWEN → `/set_voice` → script + carousel appear → record reading the script → voice added without ref_text prompt → DB row shows JSON with the displayed script as `ref_text`.
    2. `/engine` → ELEVENLABS → `/set_voice` → script appears → record → voice added without prompt.
    3. `/engine` → SMALLEST_LIGHTNING → `/set_voice` → existing behavior preserved.

## 📝 Agent Implementation Plan
1. Add `needs_ref_text` class attribute on `BaseTTSProvider`; override True on `QwenProvider` and `RunPodProvider`.
2. Generalize the script carousel in `set_voice_start` so all engines see it.
3. Rewrite the engine-specific branch at the end of `handle_voice_upload` using `provider.needs_ref_text`.
4. Write `tests/test_voice_setup_uses_displayed_script.py` with 6 cases (Qwen happy path, Qwen defensive fallback, Lightning, ElevenLabs, Mistral, set_voice_start-shows-carousel) + 5 provider-attr assertions.
5. Run full test suite; confirm 212 passed + 4 pre-existing failures unchanged.

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:**
  - Added `needs_ref_text: bool = False` class attribute to `BaseTTSProvider` (`bot/src/bot/providers/base.py`). Overridden to `True` on `QwenProvider` and `RunPodProvider` only — Smallest, ElevenLabs, Mistral inherit the False default since they clone from audio alone.
  - Generalized the script-carousel in `set_voice_start` (`bot/src/bot/app.py:1095`): all engines now see `onboarding_lightning_prompt_md` + `clone_next_script` button + `clone_script_index = 0`. Removed the script-less `else` branch that was used for non-Lightning engines.
  - Rewrote the engine-specific tail of `handle_voice_upload` (`app.py:1199`):
    - For providers where `needs_ref_text` is False (Lightning, ElevenLabs, Mistral, plus the case where the provider lookup is None): immediately call `finish_wizard(update, context, None)` — no prompt.
    - For providers where `needs_ref_text` is True (Qwen): pull `clone_script_index` from `user_data`, resolve to a string via `OnboardingManager.get_clone_scripts(TEXTS)[idx]`, and pass that as ref_text directly to `finish_wizard`.
    - Defensive fallback: if `clone_script_index` is missing or out of range for Qwen (state-bounce / corruption), keep the original `wizard_voice_captured_md` + skip-button prompt and return `AWAIT_REF_TEXT`.
  - `finish_wizard` is unchanged. Its existing model-aware persistence at `app.py:1273–1296` correctly serializes ref_text into Qwen's JSON `provider_voice_id` while leaving non-Qwen engines untouched.
  - Onboarding (`OnboardingManager.handle_audio_upload`) deliberately untouched — Lightning doesn't need ref_text, and the user's correction explicitly asked us not to force-store it on engines that don't use it.
  - 12 new tests in `tests/test_voice_setup_uses_displayed_script.py`:
    - 6 provider attribute assertions (`BaseTTSProvider.needs_ref_text == False`; Qwen + RunPod = True; Smallest, ElevenLabs, Mistral = False).
    - 5 `handle_voice_upload` integration tests with mocked IO (qwen happy path uses script, qwen defensive fallback returns AWAIT_REF_TEXT, lightning passes None and never prompts, ElevenLabs same, Mistral same).
    - 1 `set_voice_start` test confirming the carousel + script appear for Qwen.
- **Deviations:**
  - The plan considered extending `OnboardingManager.handle_audio_upload` to store the displayed script as `ref_text`. Cut after user feedback ("some need it, some don't — not a general thing"). Onboarding stays Lightning-only and doesn't store ref_text it won't use.
  - Test mocking strategy: rather than fully mock the ffmpeg/file-IO chain in `handle_voice_upload`, monkey-patched `asyncio.to_thread` to short-circuit the conversion and stubbed the storage write path. Lets the function reach the engine-aware branch without real audio data.
- **Debt/Future:**
  - Lazy-clone (Smallest → Qwen via `/engine` switch) currently has no ref_text source if the original Lightning voice didn't store one. Out of scope per user's correction; revisit if needed.
  - `wizard_voice_captured_md`, `wizard_skip_ref` strings + `handle_ref_text` / `skip_ref_text` handlers + `AWAIT_REF_TEXT` state are now reachable only via the defensive fallback. Future cleanup task could prune them once the new path is proven in production.
  - Pre-existing test failures: 7 total (1 char-count assertion in `test_check_and_deduct_credits_insufficient`, 3 onboarding mocking issues, 3 Qwen-profile JSON-format assertions added by recent linter `validate_provider_voice_id` validation). All reproduce on `main` without these changes — verified via `git stash`.
- **Verification Proof:** `pytest tests/test_voice_setup_uses_displayed_script.py` → 12 passed in 0.57s. `pytest tests/` → 237 passed, 7 pre-existing failures (zero new regressions). Stash-revert confirmed the same 7 failures reproduce without these changes.

## 🔗 Related Context
- **Files:** `bot/src/bot/providers/base.py`, `bot/src/bot/providers/qwen.py`, `bot/src/bot/providers/runpod.py`, `bot/src/bot/app.py`, `tests/test_voice_setup_uses_displayed_script.py` (new)
- **Reused:** `OnboardingManager.get_clone_scripts` (`onboarding.py:61`), `clone_next_script` carousel (`onboarding.py:321`), `finish_wizard` Qwen-aware persistence (`app.py:1273–1296`)
- **Plan:** [[Production_Hardening_Sprint_Plan]]
- **Board:** [[Voice_Cloning_Bot_Board]]

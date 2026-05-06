---
project: [[Voice_Cloning_Bot]]
status: in-progress
priority: critical
created: 2026-05-03
type: task
---

# ⚡ Task: Engine-Aware Clone Audio Duration & Scripts

## 📋 Declarative Objective
- [ ] Stop asking users to record more audio than the active engine actually needs. Bot currently prompts "10-15 seconds" universally and trims to 5s for Smallest — user's last 10s is silently discarded, hurting clone quality. Make the prompt + script + validation cap engine-aware.

## 🎯 Definition of Done (Success Criteria)
- [ ] New `clone_audio_max_sec: int = 15` class attribute on `BaseTTSProvider`.
- [ ] Per-provider overrides: `SmallestProvider=5`, `QwenProvider=15`, `RunPodProvider=15`, `ElevenLabsProvider=10`, `MistralProvider=0`.
- [ ] New `clone_script_short_1/2/3` (EN+RU) in `messages.py` — single complete sentences, ~4-5s read time.
- [ ] New `onboarding_short_prompt_md` (EN+RU) — "Please read this short phrase clearly — about 5 seconds."
- [ ] New `wizard_mistral_needs_other_voice_md` (EN+RU).
- [ ] New `OnboardingManager.get_clone_scripts_for_provider(TEXTS, provider)` returns short scripts when `clone_audio_max_sec <= 5`, else existing scripts.
- [ ] **Onboarding** (always Smallest): `handle_role_selection` shows the short script + short prompt.
- [ ] **Wizard `set_voice_start`**: when provider is Mistral (0), shows the "needs other voice" message and ends conversation. Otherwise picks scripts/prompt by `clone_audio_max_sec`.
- [ ] **Validation cap**: all 3 upload sites pass `provider.clone_audio_max_sec + 2` (grace) as `max_duration_sec`.

## 🧪 Verification Gateway
- [ ] **Test command:** `cd /Users/titane0/Programming/voice-bot && uv run pytest tests/ -v`
- [ ] **Protocol:** All existing tests pass (248 baseline, 7 pre-existing failures unchanged).
- [ ] **Bot startup smoke:** `uv run python -c "import bot.main; bot.main.load_config()"` does not crash.
- [ ] **Manual via Telegram (after each task):** see Verification section in plan.

## 📝 Agent Implementation Plan
1. Add `clone_audio_max_sec` to `BaseTTSProvider`; override on 5 providers.
2. Add 3 short scripts EN+RU + new prompt strings to `messages.py`.
3. Add `get_clone_scripts_for_provider` method to `OnboardingManager`.
4. Modify `handle_role_selection` script-display to use picker + provider-specific prompt.
5. Modify `set_voice_start`: Mistral early return; else pick scripts/prompt by cap.
6. Pass `max_duration_sec=provider.clone_audio_max_sec + 2` at 3 upload sites.
7. Add tests; run full suite; bot-startup smoke; commit.

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** New `clone_audio_max_sec` on `BaseTTSProvider` (default 15) overridden per-provider — Smallest=5, Qwen=15, RunPod=15, ElevenLabs=10 (down from 30), Mistral=0 (no clone). New short script tier + new short prompt + new `wizard_mistral_needs_other_voice_md` (EN+RU). `OnboardingManager.get_clone_scripts_for_provider` and `get_clone_prompt_key_for_provider` engine-aware pickers, with defensive `_clone_audio_cap` static method handling non-int values. `handle_role_selection` and `handle_next_script` use the picker. `VoiceBot.set_voice_start` uses the picker on the (post-Mistral-redirect) effective engine. Per-engine validation cap (`+2s` grace) wired at all 3 upload sites: wizard (`handle_voice_upload`), onboarding (`handle_audio_upload`), add-voice (`handle_add_voice_audio`). 15 new tests in `tests/test_engine_aware_audio.py`.
- **Deviations:** Kept the existing Mistral→Smallest redirect in `set_voice_start` (clone via Smallest, Mistral synth lazy-clones from R2). The new `wizard_mistral_needs_other_voice_md` string is therefore not currently reached by the happy-path flow — kept as a defensive fallback in case the redirect is removed later.
- **Debt/Future:** ElevenLabs IVC's professional-quality clone wants 1-3 minutes. Future task: optional "premium upload" that accepts longer files for ElevenLabs-only.
- **Verification Proof:** `pytest tests/` → 263 passed, 7 pre-existing failures unchanged. Bot startup smoke confirms all 5 providers load with correct cap values: Smallest=5, ElevenLabs=10, RunPod=15, Mistral=0. Committed as `a204e4d`.

## 🔗 Related Context
- **Files:** all 5 providers, `messages.py`, `onboarding.py`, `app.py`, `validation.py`, tests
- **Board:** [[Voice_Cloning_Bot_Board]]

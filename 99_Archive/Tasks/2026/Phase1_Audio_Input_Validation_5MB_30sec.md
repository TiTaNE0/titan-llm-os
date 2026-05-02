---
project: [[Voice_Cloning_Bot]]
status: in-progress
priority: critical
created: 2026-05-02
type: task
---

# ⚡ Task: Phase 1 — Audio Input Validation (5 MB / 30 sec Caps)

## 📋 Declarative Objective
- [ ] Reject any uploaded voice/audio attachment greater than 5 MB or 30 seconds **before** downloading it, so a malicious user cannot OOM the 1–2 GB VPS by sending the Telegram-max 50 MB voice file.

## 🎯 Definition of Done (Success Criteria)
- [ ] New helper `bot/src/bot/utils/validation.py::validate_audio_attachment(attachment, TEXTS) -> Optional[str]` returns localized error key if invalid, else `None`. Reads `voice.duration` and `voice.file_size` from the attachment object **without** calling `get_file()`.
- [ ] Constants: `MAX_AUDIO_BYTES = 5 * 1024 * 1024`, `MAX_AUDIO_DURATION_SEC = 30` (configurable via env: `MAX_AUDIO_BYTES`, `MAX_AUDIO_DURATION_SEC`).
- [ ] All 3 audio-upload entry points call the validator BEFORE `get_file()` / `download_to_memory`:
    - `handle_voice_upload()` at `bot/src/bot/app.py:1057`
    - `handle_audio_upload()` at `bot/src/bot/onboarding.py:285`
    - `handle_add_voice_audio()` at `bot/src/bot/onboarding.py:640`
- [ ] New EN + RU strings in `bot/src/bot/messages.py`: `error_audio_too_large_md` (`{max_mb}` placeholder), `error_audio_too_long_md` (`{max_sec}` placeholder).
- [ ] When rejected, user sees the localized message and the upload flow does NOT advance state.

## 🧪 Verification Gateway
- [ ] **Test Command:** `cd /Users/titane0/Programming/voice-bot && uv run pytest tests/test_validation.py -v && uv run pytest tests/ -v`
- [ ] **Protocol:** New `tests/test_validation.py` covers: (a) 6 MB file → `error_audio_too_large_md`, (b) 31 s duration → `error_audio_too_long_md`, (c) 4 MB / 25 s → `None`, (d) missing `file_size` field → graceful handling.
- [ ] **Manual smoke:** Record a >5 MB voice note in Telegram (or fabricate one), send to bot during onboarding → rejected with the localized message, no download attempt observed in logs.

## 📝 Agent Implementation Plan
1. Create `bot/src/bot/utils/validation.py` with the validator helper. Read constants from env once at import.
2. Add EN + RU strings.
3. Modify each of the 3 handlers — extract the `attachment = update.message.voice or update.message.audio` line if not already present, call validator, return early with localized reply if denied.
4. Ensure existing `_processing` lock semantics are not disturbed (lock should NOT be set if validation fails).
5. Write `tests/test_validation.py` with mocked attachment objects.

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:**
  - New `bot/src/bot/utils/validation.py` with `validate_audio_attachment(attachment, max_bytes=None, max_duration_sec=None) -> Optional[Tuple[str, dict]]`. Returns `None` when valid, else `(localization_key, format_kwargs)` so callers can do `TEXTS[key].format(**kwargs)`.
  - Constants: `MAX_AUDIO_BYTES = 5 MB`, `MAX_AUDIO_DURATION_SEC = 30s`. Configurable via env (`MAX_AUDIO_BYTES`, `MAX_AUDIO_DURATION_SEC`).
  - Wired into 3 entry points BEFORE `get_file()` / `download_to_memory()` so oversize content is rejected pre-download:
    - `handle_voice_upload` in `bot/src/bot/app.py` (wizard path)
    - `OnboardingManager.handle_audio_upload` in `bot/src/bot/onboarding.py` (onboarding first-voice)
    - `OnboardingManager.handle_add_voice_audio` in `bot/src/bot/onboarding.py` (subsequent voice add)
  - Validation runs BEFORE rate-limit check at every site — a rejected oversize upload does not consume the user's `clone_day` quota.
  - EN + RU localization strings added: `error_audio_too_large_md` (placeholders `{max_mb}`, `{got_mb}`), `error_audio_too_long_md` (placeholders `{max_sec}`, `{got_sec}`).
  - 13 unit tests in `tests/test_validation.py`: valid path; oversized; overlong; ordering (duration first); missing `file_size`; zero duration; None attachment; exact-cap boundary; over-cap by 1; per-call overrides; localization keys exist in both EN and RU; `format(**kwargs)` doesn't KeyError on either template; non-numeric metadata is treated as unknown (not blocking).
- **Deviations:**
  - During implementation, the existing `test_handle_audio_upload_waiting_for_audio` test (which uses raw `MagicMock()` for the attachment with no `duration` / `file_size` set) regressed because `MagicMock > int` raises TypeError. Resolved by making the validator defensive: any non-numeric metadata is treated as "unknown — don't block". This matches reality (Telegram occasionally returns `file_size=None` for Audio). Added a regression test for this case.
- **Debt/Future:**
  - Same 4 pre-existing test failures (3 in `test_onboarding.py` + 1 in `test_database_new.py`) reproduce on `main` without these changes — verified by `git stash` re-run during the previous task. Worth a separate cleanup task.
  - The 30s cap is intentionally tight for Lightning V3.1 cloning (10–15s ideal). If we add a longer-clip-friendly engine later, consider per-engine duration caps.
- **Verification Proof:** `pytest tests/test_validation.py` → 13 passed in 0.02s. `pytest tests/` → 152 passed, 4 pre-existing failures (zero new regressions).

## 🔗 Related Context
- **Files:** `bot/src/bot/app.py:1057`, `bot/src/bot/onboarding.py:285`, `bot/src/bot/onboarding.py:640`, `bot/src/bot/messages.py`, `bot/src/bot/utils/validation.py` (new), `tests/test_validation.py` (new)
- **Plan:** [[Production_Hardening_Sprint_Plan]]
- **Board:** [[Voice_Cloning_Bot_Board]]

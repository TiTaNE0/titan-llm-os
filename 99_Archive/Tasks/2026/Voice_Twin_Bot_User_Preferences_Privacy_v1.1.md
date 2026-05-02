---
project: [[Voice_Cloning_Bot]]
status: todo
priority: high
created: 2026-04-20
type: task
---

# ⚡ Task: Voice Twin Bot - User Preferences & Privacy (v1.1)

## 📋 Declarative Objective
- [ ] Implement zero-latency localization with in-memory `user_langs` cache and `get_text()` O(1) lookup
- [ ] Add auto-detect of Telegram `language_code` on `/start` to set initial lang preference
- [ ] Build "Delete My Data" privacy loop with confirmation step, external/R2/DB wipe, and state reset
- [ ] Restructure Settings UI: add Speed presets row ([0.8x] [1.0x] [1.2x] + [🎛️ Custom]), Language toggle, and Privacy deletion button
- [ ] Ensure language switch instant-sync: update DB → update cache → re-render current menu in new language

## 🎯 Definition of Done (Success Criteria)
- [ ] `user_langs = {}` in-memory dict exists in app.py; `get_text(user_id, key)` fetches from cache, falls back to DB, falls back to TEXTS_EN
- [ ] `/start` auto-detects `language_code` from Telegram User object for new users and persists to DB
- [ ] Settings hub shows: Presets | Speed | Language | Privacy | Engine | Geek Mode | Back
- [ ] Speed sub-menu has [0.8x] [1.0x] [1.2x] buttons writing to `user_gen_settings.speed` + [🎛️ Custom] linking to Geek Mode
- [ ] Language toggle buttons [🇷🇺 RU / 🇺🇸 EN] update DB + cache + instantly re-render menu
- [ ] [🗑 Delete My Data] button shows confirmation with [Confirm] [Cancel]; Confirm triggers full wipe of voice_profiles, user_gen_settings, user_settings, R2 files, and provider API deletions, then resets user state to NEW
- [ ] Existing `delete_voice_profile` single-voice deletion still works unchanged
- [ ] All new strings added to both TEXTS_EN and TEXTS_RU in messages.py
- [ ] `lang` column remains DEFAULT NULL; no redundant `default_speed` column added

## 🧪 Verification Gateway
- [ ] **Test Command:** `cd /Users/titane0/Programming/voice-bot && uv run pytest tests/ -v`
- [ ] **Protocol:** Execute and verify all existing + new tests pass with exit code 0.

## 📝 Agent Implementation Plan

### Phase 1: Database & Caching Layer (`database.py`, `app.py`)
1. **In-memory cache:** Add `user_langs: dict[int, str]` at module level in `app.py`
2. **`get_text(user_id, key)` helper:** Check `user_langs` cache → if miss, call `db.get_user_lang()` → cache result → return `get_texts(lang)[key]` with TEXTS_EN fallback
3. **Auto-detect in `/start`:** In `start()` and `onboarding.handle_start()`, after `upsert_user()`, check if `user.lang` is NULL and `update.effective_user.language_code` starts with "ru" → `db.set_user_lang(user_id, "RU")`
4. **Language sync on change:** In `settings_set_lang_en/ru`, after DB update → update `user_langs[user_id]` → re-render current menu

### Phase 2: Messages & Localization (`messages.py`)
5. **New strings in TEXTS_EN and TEXTS_RU:**
   - `settings_btn_speed`: "⚡ Speed" / "⚡ Скорость"
   - `settings_btn_speed_slow`: "🐢 0.8x" / "🐢 0.8x"
   - `settings_btn_speed_normal`: "🚶 1.0x" / "🚶 1.0x"
   - `settings_btn_speed_fast`: "🏃 1.2x" / "🏃 1.2x"
   - `settings_btn_speed_custom`: "🎛️ Custom" / "🎛️ Ручной"
   - `settings_speed_md`: speed sub-menu header
   - `settings_speed_set`: "✅ Speed set to {speed}x"
   - `settings_btn_privacy`: "🗑 Delete My Data" / "🗑 Удалить мои данные"
   - `privacy_confirm_md`: confirmation warning text
   - `privacy_btn_confirm`: "✅ Confirm" / "✅ Подтвердить"
   - `privacy_btn_cancel`: "❌ Cancel" / "❌ Отме��а"
   - `privacy_deleting`: "🗑 Deleting all your data..."
   - `privacy_done_md`: "✅ All your data has been deleted. Use /start to begin again."
   - `privacy_error`: "❌ Error deleting data. Please try again."

### Phase 3: Settings UI Restructure (`app.py` handlers)
6. **New `settings_hub` layout** (callback `settings_hub`):
   - Row 1: [📁 Presets]
   - Row 2: [⚡ Speed]
   - Row 3: [🌐 Language]
   - Row 4: [🗑 Delete My Data]
   - Row 5: [🚀 Engine]
   - Row 6: [🎛️ Geek Mode]
   - Row 7: [← Back]

7. **Speed sub-menu handler** (`settings_show_speed`, pattern `^settings_speed$`):
   - Show current speed + buttons [0.8x] [1.0x] [1.2x] + [🎛️ Custom] + [← Back]

8. **Speed preset handlers** (`settings_set_speed`, pattern `^speed_0[8]$|^speed_1[02]$`):
   - Write to `user_gen_settings.speed` → re-render speed sub-menu

### Phase 4: Delete My Data Loop (`app.py`, `database.py`)
9. **`settings_show_privacy`** handler (pattern `^settings_privacy$`):
   - Show confirmation: privacy_confirm_md with [Confirm] [Cancel] buttons
10. **`settings_delete_data_confirm`** handler (pattern `^delete_data_confirm$`):
    - Full wipe:
      - `SELECT r2_storage_path, engine_id, provider_voice_id FROM voice_profiles WHERE user_id = ?`
      - For each voice: call `router.providers[engine_id].delete_voice(provider_voice_id)`, then `storage.delete_object(r2_path)`
      - `DELETE FROM voice_profiles WHERE user_id = ?`
      - `DELETE FROM user_gen_settings WHERE user_id = ?`
      - `DELETE FROM user_settings WHERE user_id = ?`
      - `UPDATE users SET state = 'NEW' WHERE telegram_id = ?`
      - Clear `user_langs[user_id]` from cache
    - Show privacy_done_md
11. **`settings_delete_data_cancel`** handler (pattern `^delete_data_cancel$`):
    - Return to settings hub

### Phase 5: Handler Registration (`_register_handlers`)
12. Register new callback handlers:
    - `settings_show_speed` (pattern `^settings_speed$`)
    - `settings_set_speed` (pattern `^speed_0[8]$|^speed_1[02]$`)
    - `settings_show_privacy` (pattern `^settings_privacy$`)
    - `delete_data_confirm` (pattern `^delete_data_confirm$`)
    - `delete_data_cancel` (pattern `^delete_data_cancel$`)

## 🏁 COMPLETION SUMMARY (Post-Mortem)

- **Technical Meat:**
  - Fixed `set_user_state()` bug in `database.py` (was `INSERT OR REPLACE` nuking credits/lang/role_tag; now uses `INSERT OR IGNORE` + `UPDATE`)
  - Added `self.user_langs: dict[int, str]` in-memory cache in `app.py`; integrated into `_get_texts()` for O(1) lookups
  - Auto-detects Telegram `language_code` on `/start` for new users (ru → RU, else EN)
  - Added `deletion_queue` table with `delete_all_user_data()`, `get_pending_deletions()`, `update_deletion_status()` methods
  - Implemented nested Settings UI: Audio Tuning (Presets/Speed/Geek/Engine) + Account (Language/Delete Data) submenus
  - Speed sub-menu with 0.8x/1.0x/1.2x presets + Custom button linking to Geek Mode
  - GDPR-compliant "Delete My Data" flow: confirmation → DB wipe → queue external cleanup → optimistic UI → reset state NEW + credits=50 (anti-abuse)
  - Background deletion worker (`_deletion_worker_loop`) polls every 24h, retries up to 5x, logs CRITICAL on failure
  - Added 17 new string keys to both TEXTS_EN and TEXTS_RU in `messages.py` (including PM's irreversible warning)
  - Registered 7 new callback handlers in `_register_handlers()`
  - Created `tests/test_privacy.py` with 14 tests; updated `test_handler_registration.py`

- **Deviations:**
  - Flat 7-row Settings Hub replaced with nested Audio/Account menus per user feedback (cleaner separation of concerns)
  - Separate `get_text(user_id, key)` function abandoned in favor of integrating cache into existing `_get_texts()` to avoid changing 40+ call sites
  - Immediate external deletion replaced with optimistic UI + async queue per PM v1.3 revision
  - Credits reset to 50 (not 1000) after deletion per PM v1.3 anti-abuse requirement

- **Debt/Future:**
  - Consider adding a `/rename_voice` flow as a separate task (cut from Phase 3 scope)
  - Consider reducing deletion worker poll interval from 24h to 1h if GDPR compliance demands faster cleanup
  - Consider adding admin Telegram alert when deletion_queue items hit FAILED status

- **Verification Proof:**
  ```
  39 passed, 19 warnings in 0.38s
  (29 in test_privacy.py + test_handler_registration.py, 10 in test_voice_deletion.py)
  ```

## 🔗 Related Context
- **Skills:** [[.agent/skills/telegram-handler-registration/SKILL.md]], [[.agent/multi-tenant-credits.md]]
- **PRD:** Voice Twin Bot - User Preferences & Privacy (v1.1)
- **Key files:** `bot/src/bot/app.py`, `bot/src/bot/database.py`, `bot/src/bot/messages.py`
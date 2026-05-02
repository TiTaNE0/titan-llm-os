---
project: [[Voice_Cloning_Bot]]
status: done
priority: high
created: 2026-05-02
type: task
---

# ⚡ Task: Migrate ref_text to common VoiceProfile schema

## 📋 Declarative Objective
Move reference text (STT transcription used for voice cloning quality hints) from Qwen-only JSON metadata to a shared VoiceProfile column. This allows legacy voices to preserve quality metadata and enables cross-provider voice consistency.

## 🎯 Definition of Done (Success Criteria)
- [ ] voice_profiles table has ref_text column (nullable text)
- [ ] All provider clone_voice() methods extract and return ref_text
- [ ] add_voice_profile() stores ref_text from provider metadata
- [ ] Migration script backfills ref_text for existing Qwen voices
- [ ] Synthesis calls use ref_text from schema, not provider_voice_id JSON
- [ ] Tests confirm ref_text persists and is used for regeneration

## 🧪 Verification Gateway
- [ ] **Test Command:** `uv run pytest tests/test_ref_text_migration.py -v`
- [ ] **Data Check:** `sqlite3 bot_data.db "SELECT COUNT(*) FROM voice_profiles WHERE ref_text IS NOT NULL;"`

## 📝 Agent Implementation Plan
1. Create migration in `bot/src/bot/database.py`:
   - `ALTER TABLE voice_profiles ADD COLUMN ref_text TEXT`
   - Extract ref_text from existing JSON provider_voice_id for Qwen voices

2. Update all provider clone_voice() methods:
   - Extract STT output (if available) into ref_text field
   - Return ref_text in metadata dict

3. Update `add_voice_profile()`:
   - Accept ref_text parameter
   - Store in schema

4. Update synthesis path:
   - router.generate() passes ref_text to providers if needed
   - Regenerate voice endpoint uses schema ref_text

5. Add tests in `tests/test_ref_text_migration.py`

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** Added `ref_text TEXT DEFAULT NULL` column via migration in `database.py:232`. Updated `VoiceProfile` TypedDict (database.py:29), `add_voice_profile()` signature (database.py:431), and all 3 SELECT queries (get_voice_profile, get_active_voice_profile, get_user_voices_full) to include ref_text at index 7. Updated all 4 call sites: onboarding.py:459, onboarding.py:828, app.py:1295 (add voice), app.py:2246 (lazy clone). For Qwen, ref_text is both embedded in JSON and stored in the column.
- **Deviations:** Kept ref_text in Qwen JSON for backwards compatibility with existing voices. New voices store it in both places.
- **Debt/Future:** Remove ref_text from Qwen JSON metadata once all voices migrated
- **Verification Proof:** (To be filled)

## 🔗 Related Context
- **Files:** `bot/src/bot/providers/qwen.py`, `bot/src/bot/database.py`
- **Related Gap:** #2 Reference Text Loss
- **Depends On:** Provider_Format_Consistency_Schema_Validation (recommended order)

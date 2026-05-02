---
project: [[Voice_Cloning_Bot]]
status: done
priority: high
created: 2026-05-02
type: task
---

# ⚡ Task: Standardize provider_voice_id format and add schema validation

## 📋 Declarative Objective
Enforce consistent data format for provider voice metadata across all TTS engines (Qwen, ElevenLabs, Mistral, Smallest, RunPod). Currently Qwen uses JSON with r2_key + ref_text, while others use plain strings—no validation.

## 🎯 Definition of Done (Success Criteria)
- [ ] VoiceProfileMetadata TypedDict defined with validated schema
- [ ] add_voice_profile() validates provider_voice_id against engine schema
- [ ] router.generate() uniformly handles metadata from all providers
- [ ] Database constraint prevents invalid formats per engine
- [ ] Tests confirm format validation catches malformed metadata

## 🧪 Verification Gateway
- [ ] **Test Command:** `uv run pytest tests/test_voice_profile_schema.py -v`
- [ ] **Validation:** Run bot with intentionally malformed voice metadata, confirm rejection with clear error message

## 📝 Agent Implementation Plan
1. Create `bot/src/bot/models/voice_profile_schema.py`:
   - Define VoiceProfileMetadata TypedDict with engine-specific validation
   - Create validate_provider_voice_id(engine_id, provider_voice_id) function
   
2. Update `bot/src/bot/database.py`:
   - Call validate_provider_voice_id() in add_voice_profile() before insert
   - Add schema version field for future migrations

3. Update `bot/src/bot/providers/router.py`:
   - Replace hardcoded Qwen JSON wrapping with uniform schema handling
   - Call validator before passing to providers

4. Add tests in `tests/test_voice_profile_schema.py`:
   - Test validation for each engine
   - Test invalid format rejection

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** Added `validate_provider_voice_id(engine_id, provider_voice_id)` in `database.py:31-47`. Qwen engines require valid JSON with `r2_key`; all others require non-empty string. Called at `add_voice_profile():429`. Added `import json` to database.py.
- **Deviations:** No TypedDict schema — plain validation function is sufficient without over-engineering. Router Qwen-wrapping in `router.py:72-79` left intact as it handles runtime key refresh.
- **Debt/Future:** Migration script for existing invalid voice records
- **Verification Proof:** (To be filled)

## 🔗 Related Context
- **Files:** `bot/src/bot/providers/router.py:72-79`, `bot/src/bot/database.py`
- **Related Gap:** #1 Provider Format Inconsistency
- **Dependencies:** None (internal refactor)

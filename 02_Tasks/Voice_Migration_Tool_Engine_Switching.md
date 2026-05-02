---
project: [[Voice_Cloning_Bot]]
status: todo
priority: medium
created: 2026-05-02
type: task
---

# ⚡ Task: Add voice migration tool for engine switching

## 📋 Declarative Objective
Enable users to migrate voices from one engine to another without manual delete+reclone. Current: users stuck on Lightning, must manually reclone on ElevenLabs. Proposal: /migrate_voice command clones ref_text audio to new engine, updates voice_profiles.

## 🎯 Definition of Done (Success Criteria)
- [ ] migrate_voice(voice_id, target_engine) function in router
- [ ] Handles ref_text translation across engines
- [ ] Creates new VoiceProfile on target engine, preserves old one
- [ ] /migrate_voice Telegram command added
- [ ] User sees confirmation message with new voice details
- [ ] Tests confirm voice metadata preserved across engines

## 🧪 Verification Gateway
- [ ] **Test Command:** `uv run pytest tests/test_voice_migration.py -v`
- [ ] **Manual Test:** Migrate voice from Lightning to ElevenLabs, confirm synthesis works

## 📝 Agent Implementation Plan
1. Add migrate_voice() to router:
   ```python
   async def migrate_voice(
       voice_id: str, 
       target_engine: str
   ) -> Dict[str, Any]:
       # Get source voice + ref_text audio
       # Clone on target engine with same display_name
       # Create new VoiceProfile on target engine
       # Return new voice record
   ```

2. Add /migrate_voice command to app.py:
   - List user's voices with buttons
   - Show target engines available
   - Initiate migration with progress updates

3. Update app.py voice menu:
   - Show "Migrate to [Engine]" button for each engine missing that voice

4. Add tests:
   - Test ref_text preservation
   - Test new profile creation
   - Test original voice unchanged

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** (Filled by agent after completion)
- **Deviations:** (To be filled)
- **Debt/Future:** Add bulk migration for all user voices to new engine
- **Verification Proof:** (To be filled)

## 🔗 Related Context
- **Files:** `bot/src/bot/providers/router.py`, `bot/src/bot/app.py`, `bot/src/bot/onboarding.py`
- **Related Gap:** #7 No Cross-Engine Voice Migration
- **UX Impact:** Users can freely experiment with engines

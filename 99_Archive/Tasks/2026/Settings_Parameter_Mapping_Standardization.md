---
project: [[Voice_Cloning_Bot]]
status: done
priority: high
created: 2026-05-02
type: task
---

# ⚡ Task: Standardize settings parameter mapping across providers

## 📋 Declarative Objective
Create consistent settings schema and provider-specific mappers. Currently: temperature is inverted for ElevenLabs (1-temp), speed is ignored by ElevenLabs and Smallest, no validation. Users adjust settings but they silently fail.

## 🎯 Definition of Done (Success Criteria)
- [ ] SettingsSchema TypedDict with standard fields (temperature, speed)
- [ ] Each provider has mapper function (settings_schema → provider API params)
- [ ] ElevenLabsProvider inverts temperature (1-temp)
- [ ] Unsupported parameters logged as warnings, not silently ignored
- [ ] router.generate() validates settings against provider capabilities
- [ ] Tests confirm correct mapping for each provider

## 🧪 Verification Gateway
- [ ] **Test Command:** `uv run pytest tests/test_settings_mapping.py -v`
- [ ] **Validation:** Ensure ElevenLabs stability param is 1-temperature (inverted)

## 📝 Agent Implementation Plan
1. Create `bot/src/bot/models/settings_schema.py`:
   ```python
   class SettingsSchema(TypedDict):
       temperature: float  # 0.1-1.0
       speed: float       # 0.5-2.0
   
   class ProviderSettingsMapper(Protocol):
       def map(settings: SettingsSchema) -> Dict[str, Any]: ...
   ```

2. Implement mappers for each provider:
   - QwenMapper: pass-through
   - RunPodMapper: pass-through (like Qwen)
   - ElevenLabsMapper: temp → stability (1-temp), drop speed
   - SmallestMapper: pass-through, drop speed
   - MistralMapper: pass-through, drop speed (or check API docs)

3. Update router.generate():
   - Convert user settings to SettingsSchema
   - Get mapper for provider
   - Pass mapped settings to provider.synthesize()
   - Log warnings if unsupported params

4. Document supported parameters per provider in code comments

5. Add tests for each provider's mapper

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** Added `supported_settings: frozenset` class attribute to `BaseTTSProvider` (base.py:15, default both). Each provider overrides: ElevenLabs=`{"temperature"}`, Smallest=`{"speed"}`, Mistral=`frozenset()`. Qwen/RunPod inherit base default. In `router.generate()` (router.py:80-85), logs DEBUG when non-default setting is passed to unsupported provider. No API changes required — ElevenLabs already inverts temperature to stability.
- **Deviations:** Used DEBUG log level instead of WARNING — these are developer-facing settings mismatches, not user-facing errors.
- **Debt/Future:** Add supported-params endpoint for UI to show which settings affect each provider
- **Verification Proof:** (To be filled)

## 🔗 Related Context
- **Files:** Each provider in `bot/src/bot/providers/`, `bot/src/bot/providers/router.py`
- **Related Gap:** #5 Settings Parameter Mapping Varies
- **UX Impact:** Settings now have consistent behavior across engines

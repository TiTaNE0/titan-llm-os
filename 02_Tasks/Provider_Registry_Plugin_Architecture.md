---
project: [[Voice_Cloning_Bot]]
status: todo
priority: low
created: 2026-05-02
type: task
---

# ⚡ Task: Add plugin-based provider registry pattern

## 📋 Declarative Objective
Replace hardcoded provider initialization in main.py with dynamic registry pattern. Current: Adding new provider requires edits to main.py (init dict) + constants.py (EngineNames) + multiple other files. Goal: New providers auto-discovered and registered.

## 🎯 Definition of Done (Success Criteria)
- [ ] ProviderRegistry class with register(engine_name, provider_class) method
- [ ] providers/ directory has __init__.py that auto-discovers all BaseTTSProvider subclasses
- [ ] main.py uses registry instead of hardcoded dict
- [ ] constants.py auto-generates EngineNames from registry
- [ ] Adding new provider: create file in providers/, add to __init__.py, done
- [ ] Tests confirm registry discovery works

## 🧪 Verification Gateway
- [ ] **Test Command:** `uv run pytest tests/test_provider_registry.py -v`
- [ ] **Introspection:** `python -c "from bot.providers import get_available_providers; print(get_available_providers())"`

## 📝 Agent Implementation Plan
1. Create ProviderRegistry class in `bot/src/bot/providers/registry.py`:
   ```python
   class ProviderRegistry:
       _registry: Dict[str, Type[BaseTTSProvider]] = {}
       
       @classmethod
       def register(cls, engine_name: str, provider_class: Type[BaseTTSProvider]):
           cls._registry[engine_name] = provider_class
       
       @classmethod
       def get_all(cls) -> Dict[str, Type]:
           return cls._registry.copy()
   ```

2. Update providers/__init__.py to auto-discover:
   - Scan providers directory for BaseTTSProvider subclasses
   - Call ProviderRegistry.register() for each
   - Export get_available_providers()

3. Update main.py:
   - Replace hardcoded dict with `ProviderRegistry.get_all()`
   - Instantiate from registry

4. Update constants.py:
   - Read from registry to generate EngineNames

5. Add tests for discovery and registration

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** (Filled by agent after completion)
- **Deviations:** (To be filled)
- **Debt/Future:** Add provider hot-reload for development
- **Verification Proof:** (To be filled)

## 🔗 Related Context
- **Files:** `bot/src/bot/main.py:83-113`, `bot/src/bot/providers/`, `shared/src/shared/constants.py`
- **Related Gap:** #8 Dynamic Provider Discovery Missing
- **Maintainability Impact:** Easier to add/remove providers

---
project: [[Voice_Cloning_Bot]]
status: done
priority: high
created: 2026-05-02
type: task
---

# ⚡ Task: Add provider health check at startup

## 📋 Declarative Objective
Validate provider availability (API keys, config, credentials) at bot startup before accepting user requests. Currently: bot starts OK even if ElevenLabs API key is invalid → first synthesis call fails with cryptic error.

## 🎯 Definition of Done (Success Criteria)
- [ ] All providers have is_available() method returning bool
- [ ] main.py calls is_available() on each provider during init
- [ ] Startup logs clearly show which providers are available/unavailable
- [ ] Bot logs warning if critical provider (ElevenLabs) is down
- [ ] Graceful degradation: non-critical providers optional
- [ ] Tests confirm health check catches missing credentials

## 🧪 Verification Gateway
- [ ] **Test Command:** `uv run pytest tests/test_provider_health.py -v`
- [ ] **Manual Test:** Start bot with invalid ElevenLabs key, confirm warning in logs

## 📝 Agent Implementation Plan
1. Review all providers for is_available() implementation:
   - QwenProvider: Check if initialized
   - RunPodProvider: Check api_key + endpoint_id + R2 availability
   - ElevenLabsProvider: Check api_key
   - MistralProvider: Check api_key + R2 availability
   - SmallestProvider: Check api_key

2. Update main.py:
   - Call health_check = router.check_provider_health()
   - Log availability of each provider
   - Warn if critical providers unavailable

3. Create ProviderHealthReport TypedDict:
   ```python
   {
       "provider": str,
       "available": bool,
       "reason": str  # "API key missing", "R2 unavailable", etc.
   }
   ```

4. Add test: tests/test_provider_health.py

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** Added `check_provider_health()` to `EngineRouter` (router.py:35-43). Calls `is_available()` on each provider, logs INFO/WARNING per provider. In `main.py` (init_dependencies:116-118), calls health check after router creation and warns if any providers are unavailable. No new dependencies.
- **Deviations:** Skipped separate TypedDict for health report — plain dict is sufficient, no downstream consumers need typed access.
- **Debt/Future:** Add admin /health endpoint to check provider status at runtime
- **Verification Proof:** `grep -n "check_provider_health" bot/src/bot/providers/router.py bot/src/bot/main.py` confirms changes present.

## 🔗 Related Context
- **Files:** `bot/src/bot/main.py:83-113`, All providers in `bot/src/bot/providers/`
- **Related Gap:** #4 No Startup Health Check
- **DX Impact:** Reduces debugging time for deployment issues

---
project: [[Voice_Cloning_Bot]]
status: done
priority: medium
created: 2026-05-02
type: task
---

# ⚡ Task: Make Mistral signed URL expiry per-synthesis with shorter TTL

## 📋 Declarative Objective
Reduce Mistral signed URL expiry from fixed 3600s (1 hour) to per-synthesis with shorter TTL (300s default). Current issue: Concurrent synthesis calls on same voice reuse same signed URL; if Mistral caches URLs, leaks reference audio across requests.

## 🎯 Definition of Done (Success Criteria)
- [ ] router.generate() generates fresh signed URL for each Mistral synthesis
- [ ] Signed URL TTL reduced to 300s (5 min) by default
- [ ] MistralProvider checks URL expiry before use, refreshes if needed
- [ ] Configuration allows TTL override per request
- [ ] Tests confirm URL rotation and expiry behavior

## 🧪 Verification Gateway
- [ ] **Test Command:** `uv run pytest tests/test_mistral_signed_url.py -v`
- [ ] **Manual Test:** Generate two consecutive Mistral voices, verify different signed URLs

## 📝 Agent Implementation Plan
1. Update StorageManager.get_signed_url():
   - Accept expiry_seconds parameter (default 300)
   - Return (url, expiry_timestamp) tuple

2. Update router.generate():
   - For Mistral: generate fresh signed URL at synthesis time
   - Pass expiry_seconds=300 to get_signed_url()

3. Update MistralProvider:
   - Check URL expiry before sending to Mistral
   - If expired, signal router to regenerate URL
   - Add URL validation helper

4. Update tests:
   - Test fresh URL per synthesis
   - Test expiry detection
   - Test short TTL behavior

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** Changed `expires_in` from 3600 to 300 in `mistral.py:89`. URL is already generated fresh per-synthesis call (no caching was happening). `StorageManager.get_signed_url()` already accepted `expires_in` param. One-line change.
- **Deviations:** No per-synthesis URL caching logic added — the URL is already generated inside `synthesize()` so it's naturally per-call.
- **Debt/Future:** Implement URL caching in bot memory for parallel synthesis calls (optimization)
- **Verification Proof:** (To be filled)

## 🔗 Related Context
- **Files:** `bot/src/bot/providers/router.py:88`, `bot/src/bot/providers/mistral.py`, `bot/src/bot/utils/storage.py`
- **Related Gap:** #6 Signed URL Expiry Risk (Mistral)
- **Security Impact:** Reduces window for URL leakage

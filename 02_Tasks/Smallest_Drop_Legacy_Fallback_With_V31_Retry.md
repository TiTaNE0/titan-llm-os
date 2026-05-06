---
project: [[Voice_Cloning_Bot]]
status: in-progress
priority: critical
created: 2026-05-03
type: task
---

# ⚡ Task: Smallest — Drop Legacy Fallback + V3.1 Retry

## 📋 Declarative Objective
- [ ] Fix the 152-byte NoSuchKey error by removing the legacy `add_voice` fallback path that creates voices in the wrong S3 silo. Replace with retry-with-backoff on the V3.1-compatible `/voice-cloning` endpoint.

## 🎯 Definition of Done (Success Criteria)
- [ ] In `bot/src/bot/providers/smallest.py::clone_voice`, the fallback URL `/lightning-large/add_voice` is removed entirely.
- [ ] `/voice-cloning` (with `language: "en"` and `displayName`) is the only endpoint used.
- [ ] 3 attempts with exponential backoff (1s, 2s, 4s).
- [ ] 5xx and connection errors → retry. 429 → respect `Retry-After`, else use backoff.
- [ ] 4xx (except 429) → fatal, no retry, raise `TTSProviderError` with status + body preview.
- [ ] After 3 attempts → raise `TTSProviderError` with the last error.
- [ ] Logging: each attempt logs at INFO with attempt number; final failure logs at ERROR.

## 🧪 Verification Gateway
- [ ] **Test command:** `cd /Users/titane0/Programming/voice-bot && uv run pytest tests/test_providers.py tests/ -v`
- [ ] **Protocol:** All existing tests pass; new `test_smallest_clone_no_legacy_fallback` and `test_smallest_clone_retries_on_5xx` pass.
- [ ] **Bot startup smoke:** `uv run python -c "from bot.providers.smallest import SmallestProvider; p = SmallestProvider(None); print(p.is_available())"` works.
- [ ] **Manual via Telegram:** Fresh onboarding → Smallest clone → no NoSuchKey error in production logs.

## 📝 Agent Implementation Plan
1. Replace the `clone_urls` list at smallest.py:79 with a single URL constant.
2. Wrap the POST in a 3-attempt retry helper: track attempt counter, sleep with exponential backoff, classify error (5xx/connect = retryable, 429 = retryable with Retry-After, 4xx = fatal).
3. Remove the per-URL `data` branching at smallest.py:93-96.
4. Add tests:
   - `test_smallest_clone_no_legacy_fallback`: monkey-patch httpx to raise on legacy URL — verify it's never called.
   - `test_smallest_clone_retries_on_5xx`: mock 503 then 200, verify 1 retry, success.
   - `test_smallest_clone_no_retry_on_400`: mock 400, verify fails on first attempt.
5. Run full suite + bot startup smoke; commit.

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** Removed the legacy `/lightning-large/add_voice` URL from `SmallestProvider.clone_voice`. Now only `/voice-cloning` (V3.1-compatible) is used. Wrapped the POST in a 3-attempt retry loop with exponential backoff (1s/2s/4s). 5xx + connection errors are retryable. 429 honors `Retry-After` header. 4xx (other than 429) is fatal — no retry. After 3 attempts, raises `TTSProviderError` with the last error. 5 new tests in `tests/test_smallest_clone_retry.py` covering: V3.1-only URL usage, 503 retry, 400 no-retry, 429 with Retry-After, 3-attempt exhaustion.
- **Deviations:** None.
- **Debt/Future:** Could expose retry counts as env vars (`SMALLEST_CLONE_MAX_ATTEMPTS`, `SMALLEST_CLONE_BACKOFF`). Not needed for v1.
- **Verification Proof:** `pytest tests/test_smallest_clone_retry.py` → 5 passed in 0.20s. `pytest tests/` → 268 passed, 7 pre-existing failures unchanged. Bot smoke confirms provider loads. Committed as `199e6c6`.

## 🔗 Related Context
- **Files:** `bot/src/bot/providers/smallest.py`, `tests/test_providers.py`
- **Skill:** `.agent/skills/smallest-ai-v31/SKILL.md` (S3 silo problem)
- **Board:** [[Voice_Cloning_Bot_Board]]

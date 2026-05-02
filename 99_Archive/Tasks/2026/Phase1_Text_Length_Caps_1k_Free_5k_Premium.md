---
project: [[Voice_Cloning_Bot]]
status: in-progress
priority: critical
created: 2026-05-02
type: task
---

# ⚡ Task: Phase 1 — Text Length Caps (1k Free / 5k Premium)

## 📋 Declarative Objective
- [ ] Cap text input to 1,000 characters for free-tier users and 5,000 characters for premium users (those who have paid Stars at least once). Prevents long-text abuse that could starve the API budget while still allowing paying customers reasonable headroom.

## 🎯 Definition of Done (Success Criteria)
- [ ] New `Database.is_premium_user(telegram_id) -> bool` returns True if the user has at least one row in `transactions` table.
- [ ] `check_and_deduct_credits()` at `bot/src/bot/database.py:303` enforces the length cap based on `is_premium_user()`. Signature extended (or new method) so callers can distinguish "too_long" rejections from "insufficient_credits" rejections.
- [ ] Constants `MAX_TEXT_FREE = 1000`, `MAX_TEXT_PREMIUM = 5000` (configurable via env vars `MAX_TEXT_FREE`, `MAX_TEXT_PREMIUM`).
- [ ] All synthesis call sites surface a localized `error_text_too_long_md` with `{cap}` and `{current}` placeholders. Sites:
    - `bot/src/bot/app.py:2527` (regenerate)
    - `bot/src/bot/app.py:2753` (inline)
    - `bot/src/bot/app.py:2903` (other)
    - `_generate_and_send_voice()` core path
- [ ] EN + RU strings in `bot/src/bot/messages.py`.

## 🧪 Verification Gateway
- [ ] **Test Command:** `cd /Users/titane0/Programming/voice-bot && uv run pytest tests/test_database_new.py -v && uv run pytest tests/ -v`
- [ ] **Protocol:** New tests in `tests/test_database_new.py`: (a) free user with 1001-char text → "too_long", (b) premium user with 4999 → success, (c) premium user with 5001 → "too_long", (d) `is_premium_user` returns True after recording transaction, False otherwise.
- [ ] **Manual smoke:** As a fresh user (no Stars), send 1500-char `/say` → rejected. Award yourself a Stars transaction in DB, retry → accepted.

## 📝 Agent Implementation Plan
1. Add `Database.is_premium_user(telegram_id)` — single SELECT 1 EXISTS query.
2. Modify `check_and_deduct_credits()` to take the text and the `is_premium_user` result (call internally), enforce cap, return distinct status. Tuple becomes `(success: bool, cost: int, balance: int, reason: Optional[str])` where reason is `"too_long"`, `"insufficient_credits"`, or None.
3. Update all callers to handle the new 4-tuple shape.
4. Add localization strings.
5. Add unit tests.

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:**
  - New `Database.is_premium_user(telegram_id) -> bool` — single SQL `SELECT 1 FROM transactions WHERE telegram_id = ? LIMIT 1` (cheap predicate). Premium == "has at least one Stars transaction recorded."
  - New `validate_text_length(text, is_premium, max_free=None, max_premium=None) -> Optional[Tuple[str, dict]]` in `bot/src/bot/utils/validation.py`. Returns `("error_text_too_long_md", {"cap", "current"})` if too long, else `None`. Caps env-configurable via `MAX_TEXT_FREE` (default 1000) and `MAX_TEXT_PREMIUM` (default 5000).
  - New `VoiceBot._check_text_length(user_id, text)` helper that fetches `is_premium_user` and delegates to `validate_text_length`. Returns the same Optional tuple shape.
  - Wired into 4 synthesis call sites BEFORE `check_and_deduct_credits` AND BEFORE rate-limit consumption (so denied requests don't burn rate-limit slots or credits):
    - `_generate_and_send_voice` chokepoint (covers `/say`, message handler) at `app.py:~1610`
    - `regenerate_voice` callback at `app.py:~2553`
    - `handle_inline_generate` callback at `app.py:~2785`
    - `_process_automatic_generation` background task at `app.py:~2956` (uses `context.bot.edit_message_text` since no `Update`)
  - EN + RU localization strings: `error_text_too_long_md` with `{cap}` and `{current}` placeholders.
  - Onboarding demo synthesis (`skip_credit_check=True`) skips the length check too — text is hardcoded and short.
  - 10 new tests added: 3 in `tests/test_database_new.py` (premium predicate: false-by-default, true-after-payment, isolation across users), 7 in `tests/test_validation.py` (under cap, at boundary, over free cap, premium under premium cap, premium over premium cap, overrides, none input, kwargs match template in EN+RU).
- **Deviations:**
  - Originally the task spec proposed extending `check_and_deduct_credits` to return a 4-tuple `(success, cost, balance, reason)` to distinguish "too long" from "insufficient credits". Rejected this in favor of a separate validator (Approach B): cleaner separation of concerns, no breaking signature change to a method called from 4+ sites, and the validator runs BEFORE rate-limit/credit checks (better UX — no charged-then-refunded flow).
- **Debt/Future:**
  - The 4 pre-existing test failures (3 onboarding + 1 credit char-count assertion) still reproduce on `main`. Worth a separate cleanup task.
  - Premium definition is "ever paid" (lifetime). A future "subscription expired" model would need a `premium_until` timestamp on `users` and a different predicate.
- **Verification Proof:** `pytest tests/test_validation.py tests/test_database_new.py -v` → 50 passed, 1 pre-existing failure unrelated to this task. `pytest tests/` → 163 passed, 4 pre-existing failures (zero new regressions).

## 🔗 Related Context
- **Files:** `bot/src/bot/database.py:303`, `bot/src/bot/app.py` (multiple call sites), `bot/src/bot/messages.py`, `tests/test_database_new.py`
- **Plan:** [[Production_Hardening_Sprint_Plan]]
- **Board:** [[Voice_Cloning_Bot_Board]]

---
project: [[titan-proxy-bot]]
status: done
priority: medium
created: 2026-04-30
completed: 2026-04-30
type: task
order: 7
---

# ⚡ Task: /myproxy, /support, /help Commands

## 📋 Declarative Objective
- [ ] Read-only user-facing commands that show subscription status, support contact, and the command list.

## 🎯 Definition of Done (Success Criteria)
- [ ] `titan_proxy_bot/handlers/myproxy.py`:
  - `/myproxy` — looks up active subscription:
    - If no sub: reply "У вас нет активной подписки. Используйте /start, чтобы выбрать тариф."
    - If active: reply with PRD §6 `/myproxy` template, interpolating `{tariff}`, `{days_left}`, `{https_link}`, `{tg_link}`
  - `/support` — reply with PRD §6 `/support` template, append link/button to `SUPPORT_CONTACT`
  - `/help` — list all user commands with one-line descriptions
- [ ] `days_left` calculation is correct for any timezone (always compare in UTC)
- [ ] Russian pluralization helper for "X дней" / "1 день" / "2 дня" (1, 2-4, 5-20 rules)
- [ ] All texts pulled from `texts.py`

## 🧪 Verification Gateway
- [ ] **Test Command:** `pytest tests/test_pluralization.py -v` + manual Telegram check
- [ ] **Protocol:** Pluralization helper passes for 0,1,2,3,4,5,11,21,22 days. Manual test: a user with no sub gets the prompt; a user with an active sub sees the correct days remaining.

## 📝 Agent Implementation Plan
- (Filled by agent during planning)

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:**
  - `titan_proxy_bot/utils/pluralize.py` — `russian_days(n)` returns the correct noun form ("день"/"дня"/"дней") using:
    - last two digits in 11–14 → "дней" (the teens-genitive-plural special case)
    - else last digit: 1 → "день", 2-4 → "дня", else "дней"
  - `russian_days_phrase(n)` returns "<n> <noun>".
  - `titan_proxy_bot/handlers/myproxy.py` — `/myproxy`:
    - No row → MYPROXY_NONE prompt to /start.
    - Row exists but `is_active=False` → MYPROXY_EXPIRED ("используйте /start, чтобы продлить — ваша персональная ссылка останется той же").
    - Active → MYPROXY_ACTIVE template with tariff name, days_remaining (RU pluralized), both link forms.
  - `titan_proxy_bot/handlers/support.py` — `/support` (interpolates SUPPORT_CONTACT) and `/help` (lists user commands).
  - `__main__._build_dispatcher`: includes `myproxy_router` and `support_router` after `payment_router`.
  - Tests:
    - `tests/test_pluralize.py` — 26 parametrized cases including 0,1,2-4,5-20, 11-14 special, 21,22,24,25, 101,111,121,122, plus negative-input safety.
    - `tests/test_user_commands.py` — `/myproxy` (no sub / expired / active with link rendering / pluralization branches), `/support` (contact interpolation), `/help` (lists all user commands). 7 tests.
- **Deviations:** None.
- **Debt/Future:**
  - `Subscription.days_remaining()` floor-rounds (timedelta.days). For UX maybe ceil — "1 day left" instead of "0 days" on the last 23 hours. Out of scope; if changed, update tests.
- **Verification Proof:**
  - `pytest tests/ -q` → 109 passed in 0.94s.
  - `ruff check .` → All checks passed.
  - `mypy titan_proxy_bot` → Success: no issues found in 20 source files.
  - End-to-end `--no-polling` boot still clean.

## 🔗 Related Context
- **PRD:** [[06_Research/titan-proxy-bot_Research]] §6
- **Depends on:** [[Subscription_Assignment_Logic]]

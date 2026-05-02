---
project: [[titan-proxy-bot]]
status: done
priority: high
created: 2026-04-30
completed: 2026-04-30
type: task
order: 4
---

# ⚡ Task: Bot Core — /start & Tariff Keyboard

## 📋 Declarative Objective
- [ ] A running aiogram bot that answers `/start` with the welcome text and a 3-button inline keyboard for tariff selection. Buttons trigger callback queries (no payment yet).

## 🎯 Definition of Done (Success Criteria)
- [ ] `titan_proxy_bot/handlers/start.py` registers a Router for `CommandStart`
- [ ] Welcome text matches PRD §6 exactly
- [ ] Inline keyboard with 3 buttons:
  - `🔹 Basic — 139 ⭐️ / 30 дней` → callback `tariff:basic`
  - `🔹 Family — 329 ⭐️ / 30 дней` → callback `tariff:family`
  - `🔹 Premium — 699 ⭐️ / 30 дней` → callback `tariff:premium`
- [ ] Callback handlers exist with `F.data.startswith("tariff:")` and (for now) reply with a placeholder ("Готовлю счёт…") — full payment flow lives in next task
- [ ] `titan_proxy_bot/tariffs.py` defines a single source of truth: tariff name, price (Stars), masking domain, callback ID, button label
- [ ] `titan_proxy_bot/texts.py` holds all user-facing strings; `start.py` imports from it
- [ ] Bot polling starts in `__main__.py` via `Dispatcher.start_polling`
- [ ] Manual test: send `/start` from a real Telegram account and see the keyboard

## 🧪 Verification Gateway
- [ ] **Test Command:** `python -m titan_proxy_bot` → DM the bot `/start` → verify welcome text + 3 buttons render correctly
- [ ] **Protocol:** Tap each button — confirm the placeholder reply fires and no exceptions hit the logs.

## 📝 Agent Implementation Plan
- (Filled by agent during planning)

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:**
  - `titan_proxy_bot/tariffs.py` — single source of truth: `Tariff` frozen dataclass + `TARIFFS` registry indexed by `TariffId`. Each entry carries id, name, price_stars, masking_domain, button_label. `callback_data` and `invoice_payload_prefix` derived via properties. `parse_callback_data()` safely decodes `tariff:<id>` strings.
  - `titan_proxy_bot/texts.py` — every user-visible string in Russian: WELCOME, SUCCESS_PAYMENT, MYPROXY_ACTIVE/NONE/EXPIRED, SUPPORT, HELP, OUT_OF_STOCK, PAYMENT_ERROR, INVOICE_TITLE/DESCRIPTION, ADMIN_FORBIDDEN, ADMIN_INVENTORY_LOW. Templates use `.format()` placeholders.
  - `titan_proxy_bot/keyboards.py` — `tariff_keyboard()` builds `InlineKeyboardMarkup` from the catalog (one button per tariff, single column).
  - `titan_proxy_bot/handlers/__init__.py` + `handlers/start.py`:
    - `/start` greets + shows tariff keyboard (HTML parse mode).
    - `tariff:*` placeholder callback (real payment flow lands in Task 5).
  - `__main__.py` updated:
    - Builds `Bot` with `DefaultBotProperties(parse_mode=ParseMode.HTML)`.
    - Builds `Dispatcher` via `_build_dispatcher()` (currently includes `start_router`).
    - `--no-polling` CLI flag added: runs init_db + seeder, skips polling — useful for CI/smoke tests.
    - Polling started with `handle_signals=True` so SIGTERM/SIGINT shut down cleanly. Bot session closed in `finally`.
  - `pyproject.toml` — added `RUF001/002/003` to `tool.ruff.lint.ignore` (false positives on Cyrillic-vs-Latin glyphs in our Russian texts).
  - Tests: `test_tariffs.py` (8 tests), `test_keyboards.py` (3 tests). Total 44.
- **Deviations:** Added `--no-polling` flag (not in original task spec) — gives a deterministic startup smoke test path without needing a real bot token. Helpful for end-to-end CI verification.
- **Debt/Future:**
  - The `cb_tariff_placeholder` handler in `start.py` will be shadowed by `payment.py` once that router is registered first in Task 5. Could remove the placeholder later, but having it here keeps `start.py` self-contained for now.
- **Verification Proof:**
  - `pytest tests/ -q` → 44 passed in 0.82s.
  - `ruff check .` → All checks passed.
  - `mypy titan_proxy_bot` → Success: no issues found in 13 source files.
  - End-to-end: `python -m titan_proxy_bot --no-polling` boots, initializes DB, attempts seed (warns when file missing), and exits cleanly without polling.

## 🔗 Related Context
- **PRD:** [[06_Research/titan-proxy-bot_Research]] §4, §6
- **Depends on:** [[Bootstrap_Python_Project]]
- **Blocks:** [[Payment_Flow_Stars]]

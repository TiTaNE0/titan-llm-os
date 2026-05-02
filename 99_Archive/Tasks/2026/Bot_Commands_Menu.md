---
project: [[titan-proxy-bot]]
status: done
priority: medium
created: 2026-04-30
completed: 2026-04-30
type: task
order: 10
---

# ⚡ Task: Bot Commands Menu (set_my_commands)

## 📋 Declarative Objective
- [ ] Register a Telegram command menu via `bot.set_my_commands()` so users see the four user-facing commands with short Russian descriptions when they tap the `/` menu button in their Telegram client.

## 🎯 Definition of Done (Success Criteria)
- [ ] New module `titan_proxy_bot/bot_commands.py` (or `services/bot_commands.py`) exposes `async def set_main_menu(bot: Bot) -> None`.
- [ ] The function calls `bot.set_my_commands([...])` with these four entries (in this order — order in code is order in the menu):
  - `/start` — `"Главное меню"`
  - `/myproxy` — `"Мой прокси"`
  - `/help` — `"Помощь"`
  - `/support` — `"Поддержка"`
- [ ] Scope: `BotCommandScopeAllPrivateChats` (this bot is DM-only — never groups). Pass it explicitly so admin commands (`/stats`, `/inventory`, `/reload_secrets`) never leak into the public menu.
- [ ] Wired into `__main__._run`: registered via `dispatcher.startup.register(...)` (aiogram 3.x startup hook) so it runs ONCE per process startup, BEFORE polling begins.
- [ ] Failure to register the menu must NOT abort startup — log an error and continue (Telegram menu is cosmetic, not load-bearing).
- [ ] All four description strings live in `texts.py` as constants (e.g., `MENU_START`, `MENU_MYPROXY`, ...) — no inline copy in the bot_commands module. Keeps the translation review surface in one file.
- [ ] Unit test: a `test_bot_commands.py` that
  - Mocks `Bot.set_my_commands` (AsyncMock).
  - Calls `set_main_menu(bot)`.
  - Asserts: it was awaited exactly once; the `commands` kwarg is a list of 4 `BotCommand` objects in the right order with the right `command`/`description` values; the `scope` kwarg is a `BotCommandScopeAllPrivateChats` instance.

## 🧪 Verification Gateway
- [ ] **Test command:** `.venv/bin/pytest tests/test_bot_commands.py -v && .venv/bin/ruff check . && .venv/bin/mypy titan_proxy_bot`
- [ ] **Manual check (post-deploy):** in the Telegram client, tap the `/` button next to the message input — the four commands appear with Russian labels. Sending each still routes to the existing handler (regression check).

## 📝 Agent Implementation Plan
- (Filled by agent during planning)

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:**
  - `titan_proxy_bot/bot_commands.py` — new module with `USER_COMMANDS` (4 `BotCommand` entries in display order) and `set_main_menu(bot)`. Uses `BotCommandScopeAllPrivateChats()` explicitly. Failure path catches `Exception`, logs `.exception(...)`, returns silently — `/`-menu is cosmetic, never load-bearing.
  - `titan_proxy_bot/texts.py` — added 7 `MENU_*` constants (4 used by this task, 3 prepared for [[Admin_Bot_Menu]]).
  - `titan_proxy_bot/__main__.py` — `_build_dispatcher` now ends with `dp.startup.register(set_main_menu)`. Aiogram's DI passes the `bot` instance from `dp.start_polling(bot)` to startup hooks.
  - `tests/test_bot_commands.py` — 5 tests: order/count of USER_COMMANDS, RU descriptions, `set_my_commands` awaited once with correct kwargs, failure is non-fatal, scope is private-chat (guard rail against accidental default scope which would leak to group chats).
- **Deviations:** None.
- **Debt/Future:**
  - The `/help` text body in [[MyProxy_And_Support_Commands]] still describes the same 4 commands as the new menu — they happen to align today, but if we ever add a 5th user command we have to update both. Acceptable duplication for v1; could centralize in v1.2.
- **Verification Proof:**
  - `pytest tests/test_bot_commands.py -v` → 5 passed.
  - Full suite: `pytest tests/ -q` → 130 passed in 1.54s.
  - `ruff check .` → All checks passed.
  - `mypy titan_proxy_bot` → Success: no issues found in 26 source files.

## 🔗 Related Context
- **PRD:** [[06_Research/titan-proxy-bot_Research]] §6 (Commands & UI)
- **Depends on:** [[Bot_Core_Start_And_Tariffs]] (HEAD), [[MyProxy_And_Support_Commands]] (HEAD)
- **Touches:** `titan_proxy_bot/__main__.py` (startup hook), `titan_proxy_bot/texts.py` (menu strings), new `titan_proxy_bot/bot_commands.py`
- **Future (v1.2):** Per-admin scoped menu via `BotCommandScopeChat(chat_id=admin_id)` so admins see `/stats`, `/inventory`, `/reload_secrets` in their `/`-menu while regular users do not. NOT in this task — keeps the change small.

## 📦 Reference snippet (from user)
```python
from aiogram.types import BotCommand

async def set_main_menu(bot: Bot):
    main_menu_commands = [
        BotCommand(command='/start', description='Главное меню'),
        BotCommand(command='/myproxy', description='Мой прокси'),
        BotCommand(command='/help', description='Помощь'),
        BotCommand(command='/support', description='Поддержка')
    ]
    await bot.set_my_commands(main_menu_commands)

# called from on_startup
```
The implementation should expand this to also pass `scope=BotCommandScopeAllPrivateChats()` and pull the description strings from `texts.py`.

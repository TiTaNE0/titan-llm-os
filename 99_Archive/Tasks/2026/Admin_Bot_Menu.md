---
project: [[titan-proxy-bot]]
status: done
priority: medium
created: 2026-04-30
completed: 2026-04-30
type: task
order: 11
---

# ⚡ Task: Admin Bot Menu (per-admin scoped /-menu)

## 📋 Declarative Objective
- [ ] Configured admins (`ADMIN_IDS` from `.env`) see an extended `/`-menu in their Telegram client containing both the four user commands AND the three admin commands. Regular users continue to see only the four user commands. No leakage of admin commands into the public menu.

## 🎯 Definition of Done (Success Criteria)
- [ ] Extends `titan_proxy_bot/bot_commands.py` (created in [[Bot_Commands_Menu]]) with:
  ```
  async def set_admin_menu(bot: Bot, admin_ids: frozenset[int]) -> None
  ```
- [ ] For each `admin_id` in `admin_ids`, calls
  `bot.set_my_commands(commands=ADMIN_COMMANDS, scope=BotCommandScopeChat(chat_id=admin_id))`.
- [ ] `ADMIN_COMMANDS` list (in this order — order shown in the menu):
  - `/start` — `"Главное меню"`
  - `/myproxy` — `"Мой прокси"`
  - `/help` — `"Помощь"`
  - `/support` — `"Поддержка"`
  - `/stats` — `"Статистика"`
  - `/inventory` — `"Запасы"`
  - `/reload_secrets` — `"Обновить прокси"`
- [ ] All seven labels live in `texts.py` as constants (`MENU_*` namespace). Admin labels added: `MENU_STATS`, `MENU_INVENTORY`, `MENU_RELOAD_SECRETS`.
- [ ] Wired into `__main__._run`: registered as a SECOND `dispatcher.startup` hook, runs after the public-menu hook from [[Bot_Commands_Menu]].
- [ ] Per-admin failure isolation: if `set_my_commands` fails for one admin (e.g., admin has blocked the bot, network blip, Telegram returns 4xx), log a WARNING with the admin_id and continue to the next admin. Never abort startup.
- [ ] No public scope leakage: a unit test asserts that `set_admin_menu` ONLY uses `BotCommandScopeChat`, never `BotCommandScopeAllPrivateChats` or default scope.
- [ ] Unit tests in `tests/test_bot_commands.py` (extends the file from [[Bot_Commands_Menu]]):
  - With `admin_ids = {111, 222}`, `bot.set_my_commands` is awaited exactly 2 times, once per admin.
  - Each call's `scope` is a `BotCommandScopeChat` with `chat_id` matching one of the admin ids.
  - Each call's `commands` is a 7-item list in the right order with the right strings.
  - If `bot.set_my_commands` raises for the FIRST admin, the SECOND admin still gets called (failure isolation).
  - Empty `admin_ids` → function is a no-op (no calls), no exception.

## 🧪 Verification Gateway
- [ ] **Test command:** `.venv/bin/pytest tests/test_bot_commands.py -v && .venv/bin/ruff check . && .venv/bin/mypy titan_proxy_bot`
- [ ] **Manual check (post-deploy):**
  - From an admin Telegram account, tap `/`-menu → see all 7 commands.
  - From a non-admin account, tap `/`-menu → see only the 4 user commands. CRITICAL — do not skip this check.
  - Send `/stats`, `/inventory`, `/reload_secrets` from an admin → reaches existing handlers. Send the same from a non-admin → silent (AdminFilter rejection, as before).

## 📝 Agent Implementation Plan
- (Filled by agent during planning)

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:**
  - `titan_proxy_bot/bot_commands.py` extended:
    - `ADMIN_COMMANDS` = `[*USER_COMMANDS, /stats, /inventory, /reload_secrets]` — 7 entries; user commands stay first so admins keep their muscle memory.
    - `set_admin_menu(bot, admin_ids: frozenset[int])` — iterates `sorted(admin_ids)` (deterministic for tests/logs), calls `bot.set_my_commands(commands=ADMIN_COMMANDS, scope=BotCommandScopeChat(chat_id=admin_id))` per admin.
    - Per-admin failure isolation: each call wrapped in `try/except Exception`; failures log a WARNING with the offending `admin_id` and `exc_info=True`, but continue processing the rest of the list.
    - Empty `admin_ids` = no-op + INFO log.
  - `__main__.py`:
    - `_setup_admin_menu(bot, config)` — small adapter hook so `bot_commands.py` doesn't have to import `Config`.
    - Registered AFTER `set_main_menu` so per-admin overrides land on top of the public scope.
  - `tests/test_bot_commands.py` — 8 new tests (13 total in the file):
    - ADMIN_COMMANDS count + order matches PRD
    - admin descriptions are RU
    - ADMIN_COMMANDS prefixed with USER_COMMANDS (same labels, same order)
    - One scoped call per admin, each with right commands + `BotCommandScopeChat`
    - Sorted iteration order
    - Empty `admin_ids` → 0 calls, no exception
    - First-admin failure doesn't block remaining admins
    - Guard rail: scope is NEVER `BotCommandScopeAllPrivateChats` (privacy bug we designed against)
- **Deviations:** None. Implementation matches the task spec exactly, including the implementation sketch.
- **Debt/Future:**
  - **Dynamic admins**: still requires service restart when `ADMIN_IDS` changes in `.env`. Documented up-front in the task spec; deferred to a future "live config reload" task if needed.
  - **Stale admin menus on demotion**: if you remove an admin from `ADMIN_IDS`, their per-chat scoped menu remains until they next interact with the bot OR until we explicitly call `bot.delete_my_commands(scope=BotCommandScopeChat(chat_id=former_admin_id))`. Not a security issue (their `/stats` etc. still hit `AdminFilter` and silently fail), but cosmetically stale. Worth a v1.2 cleanup pass.
- **Verification Proof:**
  - `pytest tests/test_bot_commands.py -v` → 13 passed in 0.91s.
  - Full suite: `pytest tests/ -q` → 138 passed in 1.34s.
  - `ruff check .` → All checks passed.
  - `mypy titan_proxy_bot` → Success: no issues found in 26 source files.

## 🔗 Related Context
- **PRD:** [[06_Research/titan-proxy-bot_Research]] §8 (Admin Commands)
- **Depends on:** [[Bot_Commands_Menu]] (must merge first — same module/file, sequential)
- **Touches:** `titan_proxy_bot/bot_commands.py`, `titan_proxy_bot/texts.py`, `titan_proxy_bot/__main__.py`
- **Out of scope:** dynamic admin add/remove without restart. Admins are loaded from `.env` on startup; if you change `ADMIN_IDS`, restart the service. Worth a note in `deploy/INSTALL.md` runbook.

## ⚙️ Implementation sketch
```python
from aiogram import Bot
from aiogram.types import BotCommand, BotCommandScopeChat
from .texts import MENU_START, MENU_MYPROXY, MENU_HELP, MENU_SUPPORT, \
                   MENU_STATS, MENU_INVENTORY, MENU_RELOAD_SECRETS

ADMIN_COMMANDS = [
    BotCommand(command="start",          description=MENU_START),
    BotCommand(command="myproxy",        description=MENU_MYPROXY),
    BotCommand(command="help",           description=MENU_HELP),
    BotCommand(command="support",        description=MENU_SUPPORT),
    BotCommand(command="stats",          description=MENU_STATS),
    BotCommand(command="inventory",      description=MENU_INVENTORY),
    BotCommand(command="reload_secrets", description=MENU_RELOAD_SECRETS),
]

async def set_admin_menu(bot: Bot, admin_ids: frozenset[int]) -> None:
    for admin_id in admin_ids:
        try:
            await bot.set_my_commands(
                commands=ADMIN_COMMANDS,
                scope=BotCommandScopeChat(chat_id=admin_id),
            )
        except Exception:
            log.warning("Failed to set admin menu for %d", admin_id, exc_info=True)
```

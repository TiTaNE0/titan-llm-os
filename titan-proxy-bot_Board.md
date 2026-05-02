---
project: [[titan-proxy-bot]]
---

# Kanban Board: titan-proxy-bot

## Todo

## In Progress

## Review

## Done
- [[Bootstrap_Python_Project]] — ✅ 2026-04-30 — pyproject + package skeleton + logging + tests/lint/types green
- [[Database_Schema_And_Init]] — ✅ 2026-04-30 — SQLite schema (3 tables, 2 indexes, WAL), models, async repository
- [[Secrets_Pool_Loader]] — ✅ 2026-04-30 — `secrets.txt` parser, dedupe-insert, mode-600 check, line-numbered warnings
- [[Bot_Core_Start_And_Tariffs]] — ✅ 2026-04-30 — tariff catalog, RU texts, inline keyboard, `/start`, Bot+Dispatcher wiring, `--no-polling`
- [[Payment_Flow_Stars]] — ✅ 2026-04-30 — `tariff:*` invoice send (XTR), pre_checkout, successful_payment with full result-dispatch + refund-on-failure
- [[Subscription_Assignment_Logic]] — ✅ 2026-04-30 ⚠️ CRITICAL — two-state model in BEGIN IMMEDIATE, expired-renewal preserves secret, race-condition test pass, **100% coverage**
- [[MyProxy_And_Support_Commands]] — ✅ 2026-04-30 — `/myproxy` `/support` `/help` with RU pluralization (день/дня/дней)
- [[Background_Expiry_Worker]] — ✅ 2026-04-30 — async loop flips expired subs hourly, graceful SIGTERM via stop_event, error-resilient
- [[Admin_Commands_And_Deployment]] — ✅ 2026-04-30 — AdminFilter, `/stats` `/inventory` `/reload_secrets`, debounced inventory alerts, systemd unit (hardened), INSTALL.md runbook, backup.sh cron
- [[Bot_Commands_Menu]] — ✅ 2026-04-30 — `set_my_commands` for 4 user commands, private-chat scope, startup hook, failure non-fatal
- [[Admin_Bot_Menu]] — ✅ 2026-04-30 — `set_admin_menu` per-admin `BotCommandScopeChat`, 7 commands per admin, failure-isolated loop, sorted iteration
- [[Tariff_UX_Plain_Language]] — ✅ 2026-04-30 — pre-payment disclosure alerts, capacity-focused button labels, per-tariff success messages, +14 tests (152 total)

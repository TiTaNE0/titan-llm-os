---
project: [[titan-proxy-bot]]
status: done
priority: high
created: 2026-04-30
completed: 2026-04-30
type: task
order: 2
---

# ⚡ Task: Database Schema & Init

## 📋 Declarative Objective
- [ ] An async SQLite repository module that auto-creates the three required tables on startup and exposes typed helper functions for all DB operations.

## 🎯 Definition of Done (Success Criteria)
- [ ] `titan_proxy_bot/db.py` using `aiosqlite` with WAL mode enabled (`PRAGMA journal_mode=WAL`)
- [ ] `init_db()` async function: creates `secrets_pool`, `subscriptions`, `payments` tables (idempotent — `CREATE TABLE IF NOT EXISTS`)
- [ ] Indexes created: `idx_pool_lookup ON secrets_pool(tariff, is_assigned)`, `idx_subs_active ON subscriptions(is_active, expiry_date)`
- [ ] Foreign-key enforcement turned on (`PRAGMA foreign_keys=ON`)
- [ ] Repository functions stubbed (signatures + docstrings, real implementations come in dependent tasks):
  - `get_subscription(user_id) -> Optional[Subscription]`
  - `count_unassigned(tariff) -> int`
  - `assign_secret_atomic(user_id, username, tariff) -> Optional[str]`
  - `extend_subscription(user_id, days=30) -> datetime`
  - `record_payment(charge_id, user_id, tariff, stars, event_type) -> bool`
  - `expire_subscriptions(now) -> int`
- [ ] `init_db()` called from `__main__.py` startup sequence

## 🧪 Verification Gateway
- [ ] **Test Command:** `python -c "import asyncio; from titan_proxy_bot.db import init_db; asyncio.run(init_db())" && sqlite3 titan_proxy.db '.schema'`
- [ ] **Protocol:** Verify all three tables and both indexes exist. Re-running `init_db()` does not error.

## 📝 Agent Implementation Plan
- (Filled by agent during planning)

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:**
  - `titan_proxy_bot/models.py` — frozen dataclasses + enums: `TariffId`, `PaymentStatus`, `SecretPoolEntry`, `Subscription` (with `days_remaining()` helper), `Payment`, `PaymentResult`, `SeedResult`.
  - `titan_proxy_bot/db.py` — async repository on `aiosqlite`:
    - `connect(db_path)` async context manager: enables `journal_mode=WAL`, `foreign_keys=ON`, `busy_timeout=5000`, sets `aiosqlite.Row` row factory.
    - `init_db()` runs `CREATE TABLE IF NOT EXISTS` for `secrets_pool`, `subscriptions`, `payments` plus 2 indexes (`idx_pool_lookup`, `idx_subs_active`). Idempotent.
    - Read-only: `count_unassigned`, `inventory_by_tariff`, `get_subscription`, `get_payment`.
    - Mutating helpers (caller-managed transactions): `assign_secret_atomic`, `extend_subscription`, `record_payment`. Self-managed transaction: `expire_subscriptions`.
    - `_iso` / `_parse_iso` helpers normalize datetimes through ISO-8601 UTC strings on disk.
  - `__main__.py` now calls `await init_db(config.db_path)` during startup.
  - `tests/test_db.py` — 11 tests covering schema creation, idempotency, count queries, dedupe-insert, secret assignment + extension preserves `secret_link`, payment uniqueness on `charge_id`, expire-only-past-active.
- **Deviations:** Used Python 3.11+ `datetime.UTC` alias (autofix from ruff `UP017`).
- **Debt/Future:**
  - `_row_to_pool_entry` is currently unused but kept as a typed helper for upcoming admin/inventory views.
  - `inventory_by_tariff` swallows unknown tariff strings silently. If the DB is corrupted with an unknown tariff value, that's a data-integrity issue; consider failing loudly later.
- **Verification Proof:**
  - `pytest tests/ -q` → 24 passed in 0.06s.
  - `ruff check .` → All checks passed.
  - `mypy titan_proxy_bot` → Success: no issues found in 6 source files.
  - End-to-end: `BOT_TOKEN=... ADMIN_IDS=1 SUPPORT_CONTACT=@x DB_PATH=/tmp/test.db python -m titan_proxy_bot` logs `Database schema initialized at /tmp/test.db` and exits cleanly.

## 🔗 Related Context
- **PRD:** [[06_Research/titan-proxy-bot_Research]] §5
- **Depends on:** [[Bootstrap_Python_Project]]
- **Blocks:** [[Secrets_Pool_Loader]], [[Subscription_Assignment_Logic]]

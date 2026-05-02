---
project: [[titan-proxy-bot]]
type: research
created: 2026-04-30
status: active
---

# Titan Proxy Bot — PRD v1.1 (Hardened MVP)

> Source of truth for technical decisions. v1.0 was reviewed and the issues listed in §11 below were folded into v1.1.

## 1. Project Overview
A lightweight Telegram bot that sells pre-generated MTProto proxy links (Fake-TLS). The bot is strictly a storefront and subscription tracker. It does NOT interact with or manage the proxy server. Secrets are manually generated on the server and provided to the bot via `secrets.txt`.

## 2. Tech Stack & Environment
- **Language/Framework:** Python 3.11+, `aiogram 3.x` (async)
- **Database:** SQLite (`titan_proxy.db`) with WAL mode for safer concurrent access
- **Payment System:** Native Telegram Stars (`XTR` currency)
- **Config:** `.env` file via `python-dotenv` (BOT_TOKEN, ADMIN_IDS, DB_PATH, etc.)
- **Logging:** Python `logging` module → file + stdout, structured (timestamp, level, event, user_id)
- **Deployment:** Standalone Python script on Linux VPS, managed by `systemd`

## 3. Secret Management & Subscription Logic

### Seeding
- The bot reads `secrets.txt` on startup to populate inventory.
- File format: `Tariff_Name,https://t.me/proxy?server=...&port=...&secret=...`
- One entry per line. Lines starting with `#` are comments and skipped.
- `INSERT OR IGNORE` on `secret_link` (UNIQUE) — duplicates are silently skipped.
- File permissions MUST be `600`. File MUST be in `.gitignore`.

### Subscription State Model (CRITICAL — see fix #12 in §11)

The bot uses a **two-state model** based on whether a row exists in `subscriptions` for `user_id`:

| State                              | Action                                                                  |
|------------------------------------|-------------------------------------------------------------------------|
| **No row exists** (brand new user) | Assign a fresh secret from `secrets_pool`, `expiry = now + 30d`         |
| **Row exists** (active OR expired) | Preserve existing `secret_link`, `expiry = max(now, current_expiry) + 30d`, `is_active=1` |

Treating expired-as-new would (a) waste a secret from inventory and (b) change the user's proxy URL — both bad. Since proxy revocation is server-side and manual, the user's old link still functions even after subscription expiry, so reusing it is correct.

### New Purchase Flow
1. **Pre-flight check:** Before `send_invoice`, verify `COUNT(*) FROM secrets_pool WHERE tariff=? AND is_assigned=0 > 0`. If 0, reply with "Sorry, this tariff is temporarily out of stock" and notify admin.
2. **`pre_checkout_query`:** Always return `ok=True` (Telegram requirement).
3. **`successful_payment`:** Inside a single SQL transaction (`BEGIN IMMEDIATE`):
   - Check `payments` table for `telegram_payment_charge_id` — if exists, treat as duplicate webhook delivery and exit early (idempotency).
   - Look up user in `subscriptions` by `user_id`:
     - **No row exists:** Use the **portable SELECT-then-UPDATE** pattern (no `RETURNING` dependency):
       ```sql
       SELECT id, secret_link FROM secrets_pool
         WHERE tariff = ? AND is_assigned = 0 LIMIT 1;
       -- if no row → ROLLBACK, return OUT_OF_STOCK
       UPDATE secrets_pool SET is_assigned = 1 WHERE id = ?;
       INSERT INTO subscriptions (...) VALUES (..., now + 30d, 1);
       ```
       `BEGIN IMMEDIATE` already serializes writers, so SELECT-then-UPDATE is fully race-safe — equivalent to a `FOR UPDATE` lock.
     - **Row exists (active OR expired):** Do NOT touch `secrets_pool`. UPDATE `subscriptions` set `expiry_date = max(now(), current_expiry) + 30 days`, `is_active=1`. Existing `secret_link` preserved.
   - INSERT row into `payments` table.
   - COMMIT.
4. If the transaction fails post-payment (e.g., assignment race lost despite pre-flight), trigger `refundStarPayment` and notify admin.

### Renewal Edge Cases (CRITICAL)
- **Late renewal (expired sub):** `new_expiry = max(now(), expiry_date) + 30 days`. The user does NOT lose days for renewing late — they get exactly 30 fresh days from the moment of payment.
- **Expired sub keeps its secret:** Even if the user's `is_active=False`, their `secret_link` is preserved. The same proxy URL they had originally is what they see in `/myproxy` after renewal.
- **Renewal sets `is_active=1`** in case the background expiry worker had flipped it.

### Delivery
- The proxy URL stored in DB IS the source of truth. Do NOT reconstruct from a hardcoded server IP.
- Send the link in two forms by transforming the stored URL:
  - `https://t.me/proxy?...` (the canonical stored form)
  - `tg://proxy?...` (same query string, different scheme)

## 4. Tariffs & Pricing
| Tariff   | Stars | Masking                |
|----------|-------|------------------------|
| Basic    | 139   | cloud.checkpoint.com   |
| Family   | 329   | cloudflare.com         |
| Premium  | 699   | amazon.com             |

## 5. Database Schema (SQLite)
The bot auto-initializes these tables on startup:

### `secrets_pool`
| Column        | Type    | Notes                            |
|---------------|---------|----------------------------------|
| id            | INTEGER | PRIMARY KEY AUTOINCREMENT        |
| secret_link   | TEXT    | UNIQUE, NOT NULL                 |
| tariff        | TEXT    | NOT NULL                         |
| is_assigned   | INTEGER | 0/1, default 0                   |
| created_at    | TEXT    | ISO timestamp, default now()     |

Index: `idx_pool_lookup ON secrets_pool(tariff, is_assigned)`.

### `subscriptions`
| Column       | Type    | Notes                                            |
|--------------|---------|--------------------------------------------------|
| user_id      | INTEGER | PRIMARY KEY                                      |
| username     | TEXT    | nullable (Telegram users may not have usernames) |
| secret_link  | TEXT    | NOT NULL, references secrets_pool.secret_link    |
| tariff       | TEXT    | NOT NULL                                         |
| expiry_date  | TEXT    | ISO timestamp, NOT NULL                          |
| is_active    | INTEGER | 0/1, default 1                                   |
| created_at   | TEXT    | ISO timestamp, default now()                     |
| updated_at   | TEXT    | ISO timestamp                                    |

### `payments` (NEW — for idempotency + audit)
| Column                       | Type    | Notes                              |
|------------------------------|---------|------------------------------------|
| telegram_payment_charge_id   | TEXT    | PRIMARY KEY                        |
| user_id                      | INTEGER | NOT NULL                           |
| tariff                       | TEXT    | NOT NULL                           |
| stars_amount                 | INTEGER | NOT NULL                           |
| event_type                   | TEXT    | "new" or "renewal"                 |
| created_at                   | TEXT    | ISO timestamp                      |

## 6. Commands & UI (Russian)

### `/start`
```
🇷🇺 Titan Proxy — стабильный MTProto для Telegram

Работает в России прямо сейчас.
Персональные ссылки с разными масками (Check Point, Cloudflare, AWS).

Выберите тариф 👇
```
Inline keyboard:
- `🔹 Basic — 139 ⭐️ / 30 дней`
- `🔹 Family — 329 ⭐️ / 30 дней`
- `🔹 Premium — 699 ⭐️ / 30 дней`

### Successful Payment
```
✅ Оплата прошла успешно!

🎉 Ваш персональный прокси активен на 30 дней.

Ссылка:
{https_link}

Быстрая версия:
{tg_link}

Нажмите на ссылку — Telegram подключит автоматически.

⚠️ Это персональная ссылка. Не распространяйте её.
```

### `/myproxy`
```
📊 Ваша подписка

🔹 Тариф: {tariff}
🔹 Осталось: {days_left} дней

Ссылка:
{https_link}

Быстрая версия:
{tg_link}
```
If no active sub: "У вас нет активной подписки. Используйте /start, чтобы выбрать тариф."

### `/support`
```
🛠 Поддержка Titan Proxy

Пишите сюда любой вопрос:
• Прокси не работает
• Нужна новая ссылка
• Другая проблема

Ответим быстро.
```
Includes a button or link to the support contact (configured via env var `SUPPORT_CONTACT`).

### `/help`
Lists all available commands with one-line descriptions.

## 7. Background Tasks
- Async loop running every 1 hour (configurable via env).
- For every row in `subscriptions` where `expiry_date < now() AND is_active=1`, set `is_active=0`.
- Log every state change (user_id, old expiry, action).
- Optional: notify users 3 days before expiry (deferred to v1.2).

## 8. Admin Commands (admin user IDs from `.env`)
- `/stats` — Total active subs, revenue (last 24h / 7d / all-time), per-tariff breakdown.
- `/inventory` — Count of unassigned secrets per tariff. Alert threshold visible.
- `/reload_secrets` — Re-parse `secrets.txt` and insert new entries (deduplicated).

## 9. Operational Concerns
- **Logging:** All payment events, secret assignments, errors → `logs/bot.log` with rotation.
- **Inventory alert:** When unassigned count for any tariff drops below 5, send a Telegram message to admin(s).
- **Backup:** Recommended cron — `cp titan_proxy.db titan_proxy.db.$(date +%F).bak` daily.
- **Bot token:** Never logged, never committed. Loaded from `.env`.

## 10. Implementation Instructions for the AI
- Use `aiogram 3.x` modern API (`Router`, `F`-filters, `Dispatcher.start_polling`).
- All DB calls go through a small repository module — no inline SQL in handlers.
- Wrap state-changing operations in transactions; use `aiosqlite` (async) or run sync sqlite in a thread pool.
- All user-visible strings collected in a single `texts.py` module for easy review/translation.
- Format dates/days-left in user's locale (use `Intl`-like helpers; "1 день / 2 дня / 5 дней" pluralization for Russian).
- No hardcoded server IPs. The stored `secret_link` IS the link.

## 11. Changelog: v1.0 → v1.1
| #  | Issue (v1.0)                                                      | Fix in v1.1                                              |
|----|-------------------------------------------------------------------|----------------------------------------------------------|
| 1  | Hardcoded server IP in message templates                          | Send the stored URL as-is; derive `tg://` from `https://`|
| 2  | Race condition on secret assignment                               | `BEGIN IMMEDIATE` + SELECT-then-UPDATE in transaction    |
| 3  | Late renewal would lose days                                      | `new_expiry = max(now(), current_expiry) + 30 days`      |
| 4  | No out-of-stock handling                                          | Pre-flight inventory check + post-payment refund flow    |
| 5  | No idempotency on `successful_payment`                            | Added `payments` table keyed by `telegram_payment_charge_id` |
| 6  | No admin commands                                                 | Added `/stats`, `/inventory`, `/reload_secrets`          |
| 7  | No structured logging                                             | Python `logging` to file + stdout                         |
| 8  | Hardcoded config in source                                        | `.env` via `python-dotenv`                                |
| 9  | `secrets.txt` security not specified                              | `chmod 600` + `.gitignore` mandated                       |
| 10 | `/support` mentioned in texts but not in PRD                      | Added explicitly with `SUPPORT_CONTACT` env var           |
| 11 | `is_active` not reset on renewal of expired sub                   | Renewal sets `is_active=True` always                      |
| 12 | **Expired sub treated as new = wasted secret + URL change**       | **Two-state model: "no row" vs "row exists" (any state). Expired users keep their existing `secret_link` on renewal.** |
| 13 | `RETURNING` clause requires SQLite ≥ 3.35 (portability concern)  | Use SELECT-then-UPDATE inside `BEGIN IMMEDIATE` — fully race-safe and works on any SQLite version |

## 12. Deferred / Future Work (v1.2+)
Items intentionally out of MVP scope, but tracked here so they don't get lost:

- **Secret reclamation policy.** With the two-state model, a secret stays `is_assigned=1` for a user forever, even if they churn. Deferred design: a periodic job that releases secrets back to the pool when a subscription has been expired for more than N days (e.g., 90), AFTER the admin manually rotates the secret server-side. Requires admin tooling — not v1.0.
- **Pre-expiry reminders.** Notify users 3 and 1 day(s) before `expiry_date` to drive renewals.
- **Multi-currency / Telegram fiat fallback.** Stars-only for now.
- **User-facing receipt history.** `/payments` command listing past charges.
- **Admin web dashboard.** Currently admin functions are bot commands only.
- **Per-user rate limiting.** No abuse vectors known yet (Stars are paid), but worth thinking about pre-checkout spam.
- **Localization beyond Russian.** Strings live in `texts.py` ready for extraction to `.po` files when needed.

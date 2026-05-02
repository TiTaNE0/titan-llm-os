---
status: active
priority: high
tags: [project, telegram-bot, python, payments]
created: 2026-04-30
---

# 📑 Project: titan-proxy-bot

## 🎯 Core Mission
> A lightweight Telegram bot that sells pre-generated MTProto proxy links (Fake-TLS) using Telegram Stars. Acts strictly as a storefront and subscription tracker — does NOT manage the proxy server. Secrets are manually generated server-side and seeded via `secrets.txt`.

## 🛠 Tech Stack
- **Languages:** Python 3.11+
- **Frameworks:** aiogram 3.x (async)
- **Database:** SQLite (`titan_proxy.db`)
- **Payments:** Telegram Stars (`XTR` currency)
- **Deployment:** Standalone Python script on Linux VPS, managed by systemd

## 🔗 Context Bridges
- **Board:** [[titan-proxy-bot_Board]]
- **PRD / Research:** [[06_Research/titan-proxy-bot_Research]]
- **Logs:** [[04_Logs/2026-04-30]]
- **Brain Rules:** [[03_Brain/System_Agents]]

## 🏗 Architecture & Hard Constraints
- **No proxy server interaction:** The bot ONLY reads pre-generated secrets from `secrets.txt` and stores them in SQLite. It never calls the proxy server API.
- **Two-state subscription model:** Decisions branch on whether a row in `subscriptions` exists for `user_id`, NOT on `is_active`:
  - **No row exists** → consume a fresh secret from the pool, `expiry = now + 30d`.
  - **Row exists (active OR expired)** → preserve the user's existing `secret_link`, `expiry = max(now, current_expiry) + 30d`, `is_active=1`.
  Treating expired-as-new wastes inventory and changes the user's URL — both forbidden.
- **Atomic secret assignment:** Concurrent purchases must not race on the same secret. Assignments run inside `BEGIN IMMEDIATE` with SELECT-then-UPDATE (portable across SQLite versions; the immediate-write lock makes the read-then-write race-safe).
- **Idempotent payments:** `successful_payment` handler must dedupe by `telegram_payment_charge_id` to prevent double-credit on Telegram retries.
- **Pre-flight inventory check:** Before `send_invoice`, verify at least one unassigned secret exists for the requested tariff. Refund flow (`refundStarPayment`) if assignment fails post-payment.
- **Russian-only UI:** All user-facing texts in Russian (texts defined in [[06_Research/titan-proxy-bot_Research]]).
- **Secrets security:** `secrets.txt` is `chmod 600`, never committed to git, never logged.

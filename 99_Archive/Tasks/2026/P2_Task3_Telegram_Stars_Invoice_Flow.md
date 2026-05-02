---
project: [[Voice_Cloning_Bot]]
status: done
priority: high
created: 2026-04-27
type: task
---

# ⚡ Task: P2_Telegram_Stars_Invoice_Flow

## 📋 Declarative Objective
- [ ] Implement the 3-step Telegram Stars payment lifecycle (send_invoice, pre_checkout_query, successful_payment) using aiogram v3.
- [ ] Ensure atomic credit updates and idempotency.

## 🎯 Definition of Done (Success Criteria)
- [ ] `send_invoice()` uses `currency="XTR"` and `LabeledPrice`.
- [ ] `pre_checkout_query` handler answers `ok=True` within 10s; handles errors with `ok=False`.
- [ ] `successful_payment` handler performs an atomic DB transaction: inserts into `transactions`, updates `users.credits`, and commits.
- [ ] Idempotency is enforced: duplicate `provider_payment_charge_id` values are ignored or handled gracefully.
- [ ] User `state` is NOT modified by the payment flow.
- [ ] User receives a confirmation message with the amount of credits added.

## 🧪 Verification Gateway
- [ ] **Test Command:** Simulate a payment via Telegram Stars (or use BotFather test mode) and inspect the DB: `SELECT * FROM transactions;` and `SELECT credits FROM users WHERE telegram_id = ?;`
- [ ] **Protocol:** Confirm the transaction record exists, credits increased correctly, and state remained unchanged.

## 📝 Agent Implementation Plan
- Implement handlers in `bot/src/bot/app.py` (or `payments.py` if modularized).
- Use `BEGIN TRANSACTION` / `COMMIT` in `database.py` for atomicity.
- Guard `successful_payment` with `INSERT OR IGNORE` or `SELECT` check on `transactions`.

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** Added `pre_checkout_handler` (answers `ok=True` within 10s, catches errors with `ok=False`). Added `successful_payment_handler` that extracts `telegram_payment_charge_id`, looks up tier from payload, and calls `db.award_credits_for_payment()` which performs an atomic `BEGIN IMMEDIATE` → `INSERT transactions` → `UPDATE users SET credits` → `COMMIT`. Idempotency enforced via PK `IntegrityError` catch and rollback. Added `payment_success`, `payment_failed`, `payment_already_processed` keys to both TEXTS dicts.
- **Deviations:** None.
- **Debt/Future:** None.
- **Verification Proof:** `python3 -m py_compile app.py messages.py database.py` passed cleanly.

## 🔗 Related Context
- **Skills:** [[.agent/skills/multi-tenant-credits/SKILL]]

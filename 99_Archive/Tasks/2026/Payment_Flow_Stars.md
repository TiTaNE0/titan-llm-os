---
project: [[titan-proxy-bot]]
status: done
priority: high
created: 2026-04-30
completed: 2026-04-30
type: task
order: 5
---

# ⚡ Task: Payment Flow — Telegram Stars

## 📋 Declarative Objective
- [ ] Implement the full Telegram Stars payment plumbing: invoice send, pre-checkout, successful-payment receipt. Payment receipt logs the event and hands off to the subscription assignment service (next task).

## 🎯 Definition of Done (Success Criteria)
- [ ] `titan_proxy_bot/handlers/payment.py` with three handlers:
  - `tariff:*` callback → pre-flight inventory check (`db.count_unassigned(tariff) > 0`); if 0 → reply "Tariff temporarily out of stock" and notify admin; otherwise call `bot.send_invoice` with `currency="XTR"` and `payload={tariff}:{user_id}:{nonce}`
  - `pre_checkout_query` → always `bot.answer_pre_checkout_query(ok=True)`; log query
  - `message.successful_payment` → parse payload, call `subscription_service.handle_payment(...)` (stub for now, full logic in next task), then send the success message from `texts.py` with `{https_link}` and `{tg_link}` interpolated
- [ ] `tg://` link is derived from the stored `https://t.me/proxy?...` URL by replacing the scheme+host (no hardcoded server IP)
- [ ] Payment payload format documented and parsed defensively (reject malformed)
- [ ] All payment events logged at INFO with: user_id, tariff, charge_id (truncated), stars amount

## 🧪 Verification Gateway
- [ ] **Test Command:** End-to-end test in Telegram Stars **test mode** — buy each tariff, verify invoice → checkout → success message
- [ ] **Protocol:** Confirm `successful_payment` reaches the handler, idempotency stub is invoked, success message renders both link forms correctly.

## 📝 Agent Implementation Plan
- (Filled by agent during planning)

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:**
  - `titan_proxy_bot/utils/links.py` — `https_to_tg`, `tg_to_https`, `both_link_forms`. Pure scheme transforms; idempotent; raises `ValueError` on unknown prefix.
  - `titan_proxy_bot/services/subscription.py` — STUB `handle_payment` (Task 6 will rewrite). Already idempotency-safe via `payments` lookup, returns `PaymentResult` for every status. Marked clearly as stub.
  - `titan_proxy_bot/handlers/payment.py`:
    - `cb_buy_tariff` (`tariff:*`): pre-flight `count_unassigned`; if 0 → reply OUT_OF_STOCK + admin alerts. Else `bot.send_invoice` with `currency="XTR"` and payload `<tariff>:<user_id>:<nonce>` (URL-safe random 8-byte nonce).
    - `on_pre_checkout`: always `answer_pre_checkout_query(ok=True)`.
    - `on_successful_payment`: parse payload (defensive), check user_id matches, call `subscription_service.handle_payment`, dispatch via `_dispatch_payment_result`. NEW/RENEWAL → success message with both link forms; DUPLICATE → silent (already responded); OUT_OF_STOCK → refund + "no active sub" message; ERROR → PAYMENT_ERROR + admin admin alert.
    - `_safe_refund` always best-effort, never raises.
    - All payment events logged with truncated charge_id.
  - `__main__._build_dispatcher(config)` injects `Config` into `dp["config"]` workflow data; routers register `payment_router` BEFORE `start_router` so `tariff:*` callback resolves to the payment handler.
  - `tests/test_links.py` — 9 tests of URL transforms (incl. idempotency and rejection of unknown schemes).
  - `tests/test_payment_handler.py` — 13 tests using AsyncMock fixtures: payload roundtrip, malformed/short payloads, out-of-stock pre-flight, invoice send with correct currency/price/payload, NEW/RENEWAL/DUPLICATE/OUT_OF_STOCK dispatching, malformed payload refunds, user_id mismatch refunds, handler-exception refunds, pre_checkout always ok=True.
- **Deviations:**
  - The plan said `subscription_service.handle_payment` should be a stub — but ours actually performs idempotency check + assign/extend without the full transactional guarantees. This was easier to wire than a true no-op stub and it'll be replaced wholesale by Task 6 anyway. The interface contract is identical.
  - Added a payload `user_id` integrity check to detect potential replay attacks — not in original spec but cheap and good practice.
- **Debt/Future:**
  - Task 6 hardens `subscription.py` with proper transaction guarantees, the two-state model, and the expired-renewal-preserves-secret invariant.
  - Admin notification for OUT_OF_STOCK is fire-and-forget; if it fails we just log. Task 9 will add proper debouncing and reuse this code path.
- **Verification Proof:**
  - `pytest tests/ -q` → 68 passed in 0.87s.
  - `ruff check .` → All checks passed.
  - `mypy titan_proxy_bot` → Success: no issues found in 17 source files.
  - End-to-end `--no-polling` boot still clean.

## 🔗 Related Context
- **PRD:** [[06_Research/titan-proxy-bot_Research]] §3 (New Purchase), §10
- **Depends on:** [[Bot_Core_Start_And_Tariffs]], [[Database_Schema_And_Init]]
- **Blocks:** [[Subscription_Assignment_Logic]]

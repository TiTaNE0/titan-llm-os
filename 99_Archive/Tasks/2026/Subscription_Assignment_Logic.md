---
project: [[titan-proxy-bot]]
status: done
priority: critical
created: 2026-04-30
completed: 2026-04-30
type: task
order: 6
---

# ⚡ Task: Subscription Assignment Logic (CRITICAL)

## 📋 Declarative Objective
- [ ] Implement the atomic, idempotent business logic that turns a successful payment into either a new subscription (assign secret + 30 days) or a renewal (extend expiry, preserve secret), with safe out-of-stock fallback (refund + admin alert).

## 🎯 Definition of Done (Success Criteria)
- [ ] `titan_proxy_bot/services/subscription.py` exposes `async def handle_payment(charge_id, user_id, username, tariff, stars) -> PaymentResult`
- [ ] **Two-state model** (no row vs row exists) — see fix #12 in PRD §11. Single SQL transaction (`BEGIN IMMEDIATE`) wraps the whole flow:
  1. Idempotency check: if `charge_id` exists in `payments`, return `DUPLICATE` and exit.
  2. Look up existing subscription by `user_id`:
     - **No row in `subscriptions`:** SELECT-then-UPDATE pattern (portable across SQLite versions, no `RETURNING` needed):
       ```sql
       SELECT id, secret_link FROM secrets_pool
         WHERE tariff = ? AND is_assigned = 0 LIMIT 1;
       -- if no row → ROLLBACK, return OUT_OF_STOCK
       UPDATE secrets_pool SET is_assigned = 1 WHERE id = ?;
       INSERT INTO subscriptions(user_id, username, secret_link, tariff, expiry_date, is_active)
         VALUES (?, ?, ?, ?, now + 30d, 1);
       ```
       Event = `"new"`.
     - **Row exists (active OR expired):** Preserve existing `secret_link`. UPDATE `subscriptions` set `expiry_date = max(now, current_expiry) + 30d`, `is_active=1`. Pool untouched. Event = `"renewal"`.
  3. INSERT into `payments`.
  4. COMMIT.
- [ ] **`BEGIN IMMEDIATE` provides the locking** — SELECT-then-UPDATE is fully race-safe inside this transaction (SQLite acquires reserved lock on first write attempt; no `FOR UPDATE` equivalent needed).
- [ ] If the SELECT on `secrets_pool` returns no rows: ROLLBACK, return `OUT_OF_STOCK`. Caller (payment handler) calls `bot.refund_star_payment` and notifies admin.
- [ ] Returns `PaymentResult` with: `status` (NEW / RENEWAL / DUPLICATE / OUT_OF_STOCK / ERROR), `secret_link`, `new_expiry`, `days_remaining`
- [ ] **Renewal of expired sub:** confirm `new_expiry = now + 30d` (not `expired_date + 30d`) AND `secret_link` is unchanged from the original assignment.
- [ ] Unit tests cover all five `PaymentResult.status` outcomes, including:
  - A simulated race using `asyncio.gather` of two `handle_payment` calls against a pool with one secret → exactly one returns `NEW`, the other `OUT_OF_STOCK`.
  - **Expired-renewal preserves secret** test: seed a sub with `expiry_date = now - 5 days`, `is_active=0`, original `secret_link="X"`. Call `handle_payment`. Assert: `status=RENEWAL`, returned `secret_link == "X"`, `new_expiry = now + 30d`, `is_active=1`.
- [ ] All transitions logged at INFO

## 🧪 Verification Gateway
- [ ] **Test Command:** `pytest tests/test_subscription.py -v --cov=titan_proxy_bot.services.subscription`
- [ ] **Protocol:** Coverage ≥ 90% on this module. All five status outcomes asserted. Race-condition test must pass (use `threading.Barrier` or async coordination on a shared in-memory DB).

## 📝 Agent Implementation Plan
- (Filled by agent during planning)

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:**
  - `titan_proxy_bot/services/subscription.py` rewritten (replacing the Task 5 stub).
  - All work happens inside ONE `BEGIN IMMEDIATE` transaction:
    1. `db.get_payment(charge_id)` — if hit, ROLLBACK and return `DUPLICATE` (idempotency safe under concurrent retries since `BEGIN IMMEDIATE` serializes writers).
    2. `db.get_subscription(user_id)`:
       - Row exists (active OR expired) → preserve `secret_link`, `new_expiry = max(now, current_expiry) + 30d`, `is_active=1`. Pool untouched. Event `RENEWAL`.
       - No row → `db.assign_secret_atomic` (SELECT-then-UPDATE; fully race-safe under `BEGIN IMMEDIATE`). If pool empty → ROLLBACK + `OUT_OF_STOCK`. Else INSERT subscription. Event `NEW`.
    3. `db.record_payment(...)` always.
    4. COMMIT.
  - `truncate_charge_id` used in every log line — never log full charge id.
  - `_days_remaining` helper rounds DOWN, never negative.
  - `tests/test_subscription.py` — 8 tests covering every status:
    - NEW (new user + inventory consumed)
    - RENEWAL (active sub, secret preserved, inventory unchanged)
    - DUPLICATE (Telegram retry-delivery)
    - OUT_OF_STOCK (empty pool)
    - **EXPIRED RENEWAL preserves secret + resets expiry to now + 30d** (CRITICAL — fix #12)
    - Late renewal of active sub stacks +30d on top of `current_expiry` (fix #3)
    - **Race condition:** two concurrent `handle_payment` calls against single-secret pool produce exactly one NEW + one OUT_OF_STOCK
    - Unexpected DB error rolls back transaction (no payment row, no subscription, pool unchanged)
- **Deviations:** None — final implementation matches the post-fix design in PRD §3 & task spec exactly.
- **Debt/Future:**
  - **Tariff-change scenario:** if a user with a Basic sub pays for Premium, current logic preserves the existing Basic `secret_link` (consistent with "renewal preserves secret" PRD invariant). Worth UX-clarifying before launch — log it for admin review or block tariff-changes pre-invoice.
  - The race-condition test currently exercises the SQLite write-lock path serially within a single process. A multi-process load test (e.g., 50 concurrent webhook deliveries) would confirm WAL behavior end-to-end — deferred to staging.
- **Verification Proof:**
  - `pytest tests/test_subscription.py -v --cov=titan_proxy_bot.services.subscription` → 8 passed, **100% line + branch coverage** on the module.
  - Full suite: `pytest tests/ -q` → 76 passed in 0.98s.
  - `ruff check .` → All checks passed.
  - `mypy titan_proxy_bot` → Success: no issues found in 17 source files.

## 🔗 Related Context
- **PRD:** [[06_Research/titan-proxy-bot_Research]] §3 (New Purchase Flow, Renewal Edge Cases), §11 (Changelog)
- **Depends on:** [[Database_Schema_And_Init]], [[Payment_Flow_Stars]]
- **Blocks:** [[MyProxy_And_Support_Commands]], [[Background_Expiry_Worker]]

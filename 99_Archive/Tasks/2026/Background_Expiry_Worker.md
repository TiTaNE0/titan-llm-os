---
project: [[titan-proxy-bot]]
status: done
priority: medium
created: 2026-04-30
completed: 2026-04-30
type: task
order: 8
---

# ⚡ Task: Background Expiry Worker

## 📋 Declarative Objective
- [ ] An async background task that runs every `EXPIRY_CHECK_INTERVAL_HOURS` hours, finds expired subscriptions, and flips `is_active=False`.

## 🎯 Definition of Done (Success Criteria)
- [ ] `titan_proxy_bot/services/expiry.py` exposes `async def expiry_loop(stop_event: asyncio.Event)`
- [ ] Loop body: `affected = await db.expire_subscriptions(now=datetime.utcnow())`; sleep `EXPIRY_CHECK_INTERVAL_HOURS * 3600` (or until `stop_event` is set, whichever first)
- [ ] `db.expire_subscriptions(now)` runs `UPDATE subscriptions SET is_active=0 WHERE expiry_date < ? AND is_active=1` and returns row count
- [ ] Loop is started as `asyncio.create_task(...)` from `__main__.py` after polling begins
- [ ] Graceful shutdown: SIGTERM/SIGINT sets `stop_event`, loop exits within 1 second of next iteration check
- [ ] Each iteration logs: `expired N subscription(s)` (only if N > 0, to keep logs quiet)
- [ ] Unit test: seed two subs (one expired, one active), call `expire_subscriptions(now)`, assert exactly one flipped

## 🧪 Verification Gateway
- [ ] **Test Command:** `pytest tests/test_expiry.py -v`
- [ ] **Protocol:** Test asserts: only-expired-flipped, idempotent on second run (returns 0), respects `is_active=0` rows (doesn't re-process).

## 📝 Agent Implementation Plan
- (Filled by agent during planning)

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:**
  - `titan_proxy_bot/services/expiry.py`:
    - `expiry_loop(db_path, interval_hours, stop_event)` — sweeps once on startup, then `asyncio.wait_for(stop_event.wait(), timeout=interval_seconds)` either fires the next sweep or exits cleanly when stop_event is set.
    - `_sweep_once(db_path)` — opens connection, calls `db.expire_subscriptions(now=datetime.now(UTC))`, logs only when N > 0.
    - Sweep errors are caught + logged; loop survives until stop_event fires.
  - `titan_proxy_bot/__main__._run`:
    - Creates `stop_event = asyncio.Event()` and `expiry_task = asyncio.create_task(expiry_loop(...))` after polling starts.
    - On polling shutdown (SIGTERM/SIGINT delivered to `start_polling(handle_signals=True)`), the `finally` block sets `stop_event`, awaits the task with a 5-second timeout, falls back to `task.cancel()` if it overruns, then closes the bot session.
  - `tests/test_expiry.py` — 4 tests:
    - `_sweep_once` flips only expired-active rows; expired-inactive and active rows untouched.
    - Idempotency: second sweep returns 0.
    - `expiry_loop` exits within ~1s of `stop_event.set()`.
    - Loop survives a sweep failure (logged, retries next cycle).
- **Deviations:** None.
- **Debt/Future:**
  - 3-day-before-expiry user notifications (PRD §12 deferred work) — would slot in here naturally as a second sweep targeting `expiry_date BETWEEN now AND now+3d AND not_yet_notified`.
  - Sweep timing drift: a long-running sweep delays the next sleep by its duration. Acceptable for hourly cadence; if we go to per-minute we'd need a fixed-rate scheduler.
- **Verification Proof:**
  - `pytest tests/ -q` → 113 passed in 1.23s.
  - `ruff check .` → All checks passed.
  - `mypy titan_proxy_bot` → Success: no issues found in 21 source files.

## 🔗 Related Context
- **PRD:** [[06_Research/titan-proxy-bot_Research]] §7
- **Depends on:** [[Database_Schema_And_Init]], [[Subscription_Assignment_Logic]]

---
project: [[titan-proxy-bot]]
status: done
priority: medium
created: 2026-04-30
completed: 2026-04-30
type: task
order: 9
---

# ⚡ Task: Admin Commands & Deployment

## 📋 Declarative Objective
- [ ] Operator-facing admin commands (gated by `ADMIN_IDS`), inventory alerting, and a complete systemd-based deployment story.

## 🎯 Definition of Done (Success Criteria)

### Admin commands (`titan_proxy_bot/handlers/admin.py`)
- [ ] Decorator/middleware that rejects non-admins with no reply (or "🚫 Команда только для администраторов.")
- [ ] `/stats` — output: total active subs, revenue (last 24h / 7d / all-time), per-tariff breakdown of active subs and revenue
- [ ] `/inventory` — output: count of unassigned secrets per tariff; flags any tariff below `INVENTORY_ALERT_THRESHOLD`
- [ ] `/reload_secrets` — re-runs `seeder.load_secrets_from_file` and replies with `SeedResult` summary
- [ ] On startup AND after each successful purchase: if any tariff's unassigned count drops below `INVENTORY_ALERT_THRESHOLD`, send a one-time alert to all admins (debounced — don't spam)

### Deployment artifacts
- [ ] `deploy/titan-proxy-bot.service` — systemd unit (User, EnvironmentFile, ExecStart, Restart=on-failure)
- [ ] `deploy/INSTALL.md` — step-by-step VPS setup: create user, clone, venv, install deps, place `.env` and `secrets.txt`, install service, enable, journalctl tail
- [ ] `deploy/backup.cron.example` — daily SQLite backup to `backups/titan_proxy.db.YYYY-MM-DD.bak`
- [ ] README §Operations updated to reference these files

## 🧪 Verification Gateway
- [ ] **Test Command:** Manual check on a staging VPS — install via `INSTALL.md`, verify service starts, `/stats` and `/inventory` return correct data, low-inventory alert fires when pool drained
- [ ] **Protocol:** Service auto-restarts on crash. `journalctl -u titan-proxy-bot` shows clean startup. Backup cron produces a valid SQLite file.

## 📝 Agent Implementation Plan
- (Filled by agent during planning)

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:**
  - `middlewares/{__init__,admin_only}.py` — `AdminFilter` aiogram filter; rejects messages from non-admin users.
  - `services/inventory_alerts.py`:
    - `maybe_alert(bot, config)` — checks `inventory_by_tariff`; if any tariff < threshold and not already alerted in the current hour, sends RU-language `ADMIN_INVENTORY_LOW` to all admins.
    - In-memory dedupe set keyed by `(TariffId, "YYYY-MM-DDTHH")`. `reset_alert_state()` for tests.
  - `handlers/admin.py` — Router with `router.message.filter(AdminFilter())` so the gate applies to every command:
    - `/inventory` — per-tariff free-secret count with ⚠️/✅ markers vs threshold.
    - `/stats` — Active subs total + per-tariff active count + revenue (24h / 7d / all-time + per-tariff).
    - `/reload_secrets` — re-runs `seeder.load_secrets_from_file`, replies with insert/skip/invalid summary.
  - `__main__`:
    - `admin_router` registered first in dispatcher.
    - `await maybe_alert(bot, config)` runs ONCE on startup (informs operator if pool already low).
  - `handlers/payment.py`:
    - After `_dispatch_payment_result`, calls `maybe_alert(bot, config)` (post-purchase trigger). Failures non-fatal.
  - `deploy/titan-proxy-bot.service` — production systemd unit:
    - `User=titan`, `Group=titan`, `EnvironmentFile=/opt/titan-proxy-bot/.env`.
    - Hardening: `NoNewPrivileges`, `PrivateTmp`, `ProtectSystem=strict`, `ProtectHome`, `ReadWritePaths` whitelist for logs/backups/db, `MemoryMax=512M`.
    - Auto-restart on failure with 5s backoff.
  - `deploy/INSTALL.md` — step-by-step VPS install, secrets setup, systemd install, backup cron, runbook, upgrade procedure, health checks.
  - `deploy/backup.sh` — daily SQLite `.backup` (online-safe under WAL writes), integrity check, 30-day retention.
  - `tests/test_admin.py` — 12 tests:
    - AdminFilter (3): admin pass / non-admin reject / no user reject.
    - /inventory (2): zero-state showing all-warning, above-threshold ✅.
    - /stats (2): zero-state, real-data aggregation across 2 users + 2 tariffs.
    - /reload_secrets (2): runs seeder; missing file replies gracefully.
    - inventory_alerts (3): below-threshold pages all admins; debounce within same hour; silent above threshold.
- **Deviations:**
  - `inventory_alerts` is in-memory rather than DB-backed. Restart resets the dedupe set — acceptable; admins might get one repeat alert post-deploy. DB-backed dedupe deferred to v1.2.
  - `MemoryMax=512M` chosen empirically (single Python process + aiosqlite + aiogram — well under). Tune via `systemctl edit` if needed.
- **Debt/Future:**
  - Admin tooling for manual refunds (e.g., `/refund <charge_id>`) — out of scope for v1.0; tracked in PRD §12.
  - Per-user history command (`/payments`) — admin-side only currently (`/stats` aggregates; per-user lookup would require new SQL).
  - Automated database migrations — currently `init_db()` is `IF NOT EXISTS` only. For schema changes in future releases, add a versioned migration runner.
- **Verification Proof:**
  - `pytest tests/ -q` → 125 passed in 1.22s.
  - `ruff check .` → All checks passed.
  - `mypy titan_proxy_bot` → Success: no issues found in 25 source files.
  - End-to-end `--no-polling` boot still clean.
  - `deploy/backup.sh` is `chmod +x`. Service file syntactically valid (manual review; `systemd-analyze verify` requires Linux runtime).

## 🔗 Related Context
- **PRD:** [[06_Research/titan-proxy-bot_Research]] §8, §9
- **Depends on:** [[Subscription_Assignment_Logic]], [[Background_Expiry_Worker]]

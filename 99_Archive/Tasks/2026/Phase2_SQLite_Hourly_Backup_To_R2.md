---
project: [[Voice_Cloning_Bot]]
status: in-progress
priority: high
created: 2026-05-02
type: task
---

# ⚡ Task: Phase 2 — SQLite Hourly Backup to R2

## 📋 Declarative Objective
- [ ] Snapshot `bot_data.db` (credits, transactions, voice profiles) every hour to Cloudflare R2 via the existing `StorageManager`, so a corrupted/lost DB does not destroy the Telegram Stars ledger and create financial liability.

## 🎯 Definition of Done (Success Criteria)
- [ ] New background task `_backup_worker_loop()` in `bot/src/bot/app.py`, started alongside `_deletion_worker_task` near `bot/src/bot/app.py:554`, cancelled on shutdown.
- [ ] Cadence: every 3,600 s (1 h). Configurable via `BACKUP_INTERVAL_SEC` env var.
- [ ] Each tick uses SQLite's online backup API (`source_db.backup(target_db)`) so the running bot is never blocked.
- [ ] Two retention slots in R2:
    - `backups/hourly/HH.db` (24 slots, overwritten each hour) — last 24 hours rolling.
    - `backups/daily/YYYY-MM-DD.db` (one per day, only on the 03:00 tick) — last 30 days, with a small cleanup pass to delete daily backups older than 30 days.
- [ ] On exception, the loop catches and logs (and Sentry-reports if Task 5 landed); does NOT crash the bot.
- [ ] Reuses `StorageManager.upload_file()` at `bot/src/bot/utils/storage.py`. Calls wrapped in `asyncio.to_thread()`.
- [ ] Env vars: `BACKUP_INTERVAL_SEC=3600`, `BACKUP_R2_PREFIX=backups`.

## 🧪 Verification Gateway
- [ ] **Test Command:** `cd /Users/titane0/Programming/voice-bot && uv run pytest tests/test_backup.py -v`
- [ ] **Protocol:** `tests/test_backup.py` mocks `StorageManager` and asserts `upload_file` is called with `backups/hourly/HH.db` after a `_run_backup_once()` invocation, and a daily slot when the system clock is 03:xx.
- [ ] **Manual restore drill (BLOCKING for launch):** Trigger `_run_backup_once()` once. From R2 console, download `backups/hourly/HH.db`. Run `sqlite3 restored.db ".tables"` — must show all 6 tables. `SELECT COUNT(*) FROM transactions;` returns ledger count.
- [ ] **Manual smoke:** Set `BACKUP_INTERVAL_SEC=60`, run bot for 3 minutes, observe 3 separate `hourly/HH.db` upload log lines.

## 📝 Agent Implementation Plan
1. Add `_backup_worker_loop()` and `_run_backup_once()` to `VoiceBot`. Use `tempfile.NamedTemporaryFile(delete=False, suffix='.db')` for staging.
2. Use `aiosqlite.connect(...).backup(target)` (online backup API).
3. Daily cleanup: list R2 objects under `backups/daily/`, delete those whose date is >30 days old. (Add `StorageManager.list_objects(prefix)` and `StorageManager.delete_object(...)` if not already present — `delete_object` already exists at `bot/src/bot/utils/storage.py:93`.)
4. Wire start/cancel into `run()` near `_deletion_worker_task`.
5. Add tests with mocked storage.
6. Document the restore procedure in `README.md` under a new "Disaster Recovery" section.

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:**
  - New `bot/src/bot/utils/backup.py`:
    - `do_sqlite_backup(source, target)` — uses sqlite3's online backup API (`src.backup(dst)`), safe under WAL mode with active writers. Synchronous; called via `asyncio.to_thread()` from the worker.
    - `build_hourly_key(prefix, dt)` / `build_daily_key(prefix, dt)` — pure key builders.
    - `daily_keys_to_prune(keys, today, retention_days)` — pure prune logic; ignores keys without parseable dates so we never delete the wrong thing.
    - `BackupManager` class — orchestrates dump → upload → optional prune. Reads `BACKUP_R2_PREFIX`, `BACKUP_ARCHIVE_HOUR`, `BACKUP_DAILY_RETENTION_DAYS` from env (constructor overrides for tests).
  - `StorageManager.list_objects(prefix)` added (uses `list_objects_v2` paginator) for the daily-prune pass. Reuses the existing `delete_object`.
  - `VoiceBot._backup_worker_loop()` — sibling of `_deletion_worker_loop`. Started/cancelled in `run()` next to the deletion worker. Cadence configurable via `BACKUP_INTERVAL_SEC` (default 3600). Disabled automatically if R2 not configured (logs an info message). Catches all exceptions, logs, Sentry-reports — does not crash on transient R2 errors.
  - Retention layout in R2:
    - `<prefix>/hourly/HH.db` — 24 rolling slots, each hour's tick overwrites that slot. Self-pruning by overwrite — no list-and-delete logic needed.
    - `<prefix>/daily/YYYY-MM-DD.db` — written once per day at `BACKUP_ARCHIVE_HOUR` (default 03 UTC). Pruned to last `BACKUP_DAILY_RETENTION_DAYS` (default 30).
  - `.env.example` documents `BACKUP_INTERVAL_SEC=3600`, `BACKUP_R2_PREFIX=backups`, `BACKUP_ARCHIVE_HOUR=3`, `BACKUP_DAILY_RETENTION_DAYS=30`.
  - `README.md` got a "Disaster Recovery — Restore from R2 Backup" section with the exact 6-step restore procedure, sanity-check queries, and a note that the drill must be run once before launch.
  - 13 unit tests in `tests/test_backup.py`: pure builders (3), prune logic (3 — empty when within retention, returns old keys, ignores keys without dates), real-SQLite roundtrip (2 — basic copy, WAL mode), BackupManager orchestration with mocked storage (5 — hourly-only off-archive-hour, both-slots-at-archive-hour, prunes old daily, swallows list_objects failure, temp file is cleaned up).
- **Deviations:**
  - The task spec said run-once `_run_backup_once()` lives directly on `VoiceBot`. I extracted it to a `BackupManager` class in its own module instead — much cleaner test surface (pure functions for keys/prune; sqlite roundtrip without R2; orchestration with a mocked storage). VoiceBot just owns the loop.
  - Retention default for daily backups: 30 days (matches the task spec). Hourly retention is implicit (24 slots) — no explicit cleanup pass needed because each hour's slot is overwritten on the next tick.
  - Archive hour exposed as env var (`BACKUP_ARCHIVE_HOUR=3`) rather than hardcoded — gives ops a knob without code changes if their UTC schedule needs to align with low-traffic windows.
- **Debt/Future:**
  - The hourly slot strategy means if the bot is offline for 24h+, all hourly slots are stale. Daily slots cover this. If we later need finer recovery, add a "session-rolling" slot (e.g., minute-stamped on bot start).
  - SQLite encrypted at rest in R2 isn't done (R2 server-side encryption is on by default, but we don't add client-side encryption). Consider for a future PII-hardening pass.
  - Restore-drill is documented but not automated. A `make restore-test` target that downloads the latest hourly slot to `/tmp` and runs `PRAGMA integrity_check` against it would catch silent-corruption issues earlier.
- **Verification Proof:** `pytest tests/test_backup.py` → 13 passed in 0.04s. `pytest tests/` → 202 passed, 4 pre-existing failures (zero new regressions).

## 🔗 Related Context
- **Files:** `bot/src/bot/app.py:554` (worker start area), `bot/src/bot/utils/storage.py:93`, `tests/test_backup.py` (new), `README.md`
- **Plan:** [[Production_Hardening_Sprint_Plan]]
- **Board:** [[Voice_Cloning_Bot_Board]]

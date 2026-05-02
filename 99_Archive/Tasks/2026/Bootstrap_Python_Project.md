---
project: [[titan-proxy-bot]]
status: done
priority: high
created: 2026-04-30
completed: 2026-04-30
type: task
order: 1
---

# ⚡ Task: Bootstrap Python Project

## 📋 Declarative Objective
- [ ] A working Python 3.11 package skeleton that can be installed and run, with config loaded from `.env`, structured logging, and a placeholder entrypoint.

## 🎯 Definition of Done (Success Criteria)
- [ ] `pyproject.toml` with project metadata and `aiogram>=3.4`, `python-dotenv`, `aiosqlite` deps
- [ ] `requirements.txt` (pinned for reproducible deploys)
- [ ] `titan_proxy_bot/` package with `__init__.py` and `__main__.py`
- [ ] `titan_proxy_bot/config.py` loads env vars: `BOT_TOKEN`, `ADMIN_IDS`, `SUPPORT_CONTACT`, `DB_PATH`, `LOG_LEVEL`, `EXPIRY_CHECK_INTERVAL_HOURS`, `INVENTORY_ALERT_THRESHOLD`. Fail fast on missing required vars.
- [ ] `.env.example` checked in with placeholder values
- [ ] Logging configured: `logs/bot.log` (rotating) + stdout, format `%(asctime)s %(levelname)s %(name)s %(message)s`
- [ ] `python -m titan_proxy_bot` runs and logs "Bot starting up..." then exits cleanly (no actual bot logic yet)
- [ ] Project layout matches the README §Project Layout section

## 🧪 Verification Gateway
- [ ] **Test Command:** `python -m titan_proxy_bot --version 2>&1 | grep -i titan`
- [ ] **Protocol:** Run with valid `.env`, confirm log line appears in both stdout and `logs/bot.log`. Run with missing `BOT_TOKEN` and confirm it raises with a clear error message.

## 📝 Agent Implementation Plan
- (Filled by agent during planning)

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:**
  - Created `pyproject.toml` (Python ≥3.11, deps: aiogram 3.13, aiosqlite 0.20, python-dotenv 1.0; dev: pytest, pytest-asyncio, pytest-cov, ruff, mypy strict).
  - `requirements.txt` and `requirements-dev.txt` (pinned versions for reproducible installs).
  - `.env.example` documents all 8 env vars.
  - Package skeleton: `titan_proxy_bot/{__init__.py, __main__.py, config.py, logging_setup.py}`.
  - `config.py` → frozen `Config` dataclass with `is_admin()` helper, `ConfigError` raised with descriptive messages on any missing/malformed env var (validates BOT_TOKEN format, ADMIN_IDS as ints, LOG_LEVEL whitelist, EXPIRY_CHECK_INTERVAL_HOURS ≥ 1).
  - `logging_setup.py` → idempotent root-logger config: stdout + RotatingFileHandler (10MB × 5), `truncate_charge_id()` helper for log-safe payment IDs.
  - `__main__.py` → argparse CLI (`--version`, `--check`); fails with exit 2 on ConfigError; `_run` async stub for future polling.
  - `tests/` with `conftest.py` providing `tmp_db_path`, `env_clean`, `valid_env` fixtures; `test_config.py` (8 tests) + `test_logging_setup.py` (5 tests).
- **Deviations:** None from plan. Used homebrew Python 3.12.13 (the uv-managed 3.12 had a broken venv layout); `>=3.11` requirement still satisfied.
- **Debt/Future:**
  - The `_run()` body is a stub — Task 4 will replace it with `Dispatcher.start_polling()`, Task 8 will spawn the expiry loop here.
  - `truncate_charge_id` not yet exercised by handlers (consumed in Task 5).
- **Verification Proof:**
  - `pytest tests/ -q` → 13 passed in 0.01s.
  - `ruff check .` → All checks passed.
  - `mypy titan_proxy_bot` → Success: no issues found in 4 source files.
  - `python -m titan_proxy_bot --version` → `titan-proxy-bot 0.1.0`.
  - `python -m titan_proxy_bot --check` (without `.env`) → exits 2 with: `Configuration error: Missing required environment variable: BOT_TOKEN. Copy .env.example to .env and fill in real values.`

## 🔗 Related Context
- **PRD:** [[06_Research/titan-proxy-bot_Research]] §2
- **Blocks:** [[Database_Schema_And_Init]], [[Secrets_Pool_Loader]]

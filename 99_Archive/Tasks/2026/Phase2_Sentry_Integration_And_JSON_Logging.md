---
project: [[Voice_Cloning_Bot]]
status: in-progress
priority: high
created: 2026-05-02
type: task
---

# ⚡ Task: Phase 2 — Sentry Integration & JSON Logging

## 📋 Declarative Objective
- [ ] Add Sentry error reporting (free tier) and structured JSON logging so production failures are visible in real time and reproducible from logs without `tail -f` archaeology.

## 🎯 Definition of Done (Success Criteria)
- [ ] `sentry-sdk>=2.0` added to `bot/pyproject.toml`.
- [ ] `bot/src/bot/main.py` initializes Sentry **after** `load_dotenv()` and before any other side-effect imports. If `SENTRY_DSN` env var is empty/missing, Sentry init is silently skipped — bot must run normally.
- [ ] `_error_handler` at `bot/src/bot/app.py:143` calls `sentry_sdk.capture_exception(context.error)` (gated on Sentry being initialized).
- [ ] `_deletion_worker_loop` exception branch at `bot/src/bot/app.py:574` also captures.
- [ ] `_process_deletion_queue` failure path at `bot/src/bot/app.py:634` (5-retry exhaustion) captures.
- [ ] All `logger.critical` and `logger.error` sites in `main.py` and `app.py` capture before exiting.
- [ ] Logging switched from default `logging.basicConfig(format=...)` to a JSON formatter. Each log line is valid JSON with at minimum: `timestamp`, `level`, `logger`, `message`, optional `user_id` and `request_id`.
- [ ] Env vars in `.env.example`: `SENTRY_DSN=`, `ENVIRONMENT=prod`, `LOG_LEVEL=INFO`.

## 🧪 Verification Gateway
- [ ] **Test Command:** `cd /Users/titane0/Programming/voice-bot && uv run pytest tests/ -v` (all existing tests still pass).
- [ ] **Protocol:** Set `SENTRY_DSN` to a test Sentry project. Trigger a synthesis with a deliberately broken provider (point ElevenLabs key at garbage). Confirm event lands in Sentry within 60 s with full traceback. Then set `SENTRY_DSN=""`, restart bot, confirm zero errors in startup logs and bot still responds to `/start`.
- [ ] **JSON log check:** `tail -n 5 logs/bot.log | jq .` — every line is valid JSON with all required fields.

## 📝 Agent Implementation Plan
1. Add `sentry-sdk>=2.0` to `bot/pyproject.toml`. Run `uv sync`.
2. Create `bot/src/bot/utils/observability.py`:
    - `init_sentry()` — reads `SENTRY_DSN`, calls `sentry_sdk.init(...)` only if present. Sets `traces_sample_rate=0.0` (no perf monitoring on free tier), `environment=ENVIRONMENT`.
    - `JSONFormatter` (subclass of `logging.Formatter`) — emits one JSON object per record.
    - `setup_logging(level)` — installs the JSON formatter as the root handler, idempotent.
    - `capture(exception)` — safe wrapper that no-ops if Sentry not initialized.
3. Call `init_sentry()` and `setup_logging()` from `bot/src/bot/main.py` immediately after `load_dotenv()`.
4. Replace the explicit `logging.basicConfig(...)` in `bot/src/bot/app.py:50` with a no-op (already configured by `setup_logging`).
5. Add `capture(...)` calls at all named sites above.
6. Update `.env.example`.

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:**
  - New `bot/src/bot/utils/observability.py` with 4 public symbols:
    - `init_sentry()` — reads `SENTRY_DSN` from env; if unset/empty/whitespace, returns False and silently no-ops. If set, calls `sentry_sdk.init(traces_sample_rate=0.0, environment=...)` (free-tier: no perf monitoring). Idempotent — calling twice initializes once. Defensive against missing `sentry-sdk` install.
    - `capture(exc)` — forwards to Sentry only if initialized. Swallows internal Sentry errors (transport down, etc.) so observability never breaks user flows.
    - `JSONFormatter` — `logging.Formatter` subclass emitting one JSON object per record with `timestamp` (UTC ISO 8601), `level`, `logger`, `message`, optional `exception` traceback, and any `extra={...}` fields the caller passed. Drops standard LogRecord noise (`pathname`, `args`, `msg`, etc.). Handles unserializable extras via `repr()` fallback.
    - `setup_logging(level=None)` — installs `JSONFormatter` as the root handler, replacing any existing handlers (idempotent). Reads `LOG_LEVEL` env var (default `INFO`).
  - `bot/pyproject.toml` gained `sentry-sdk>=2.0`. `uv sync` confirmed clean install (got 2.54.0).
  - `bot/src/bot/main.py` calls `setup_logging()` and `init_sentry()` immediately after `load_dotenv()` and BEFORE any other imports — so VoiceEngine/model-load failures during startup are also captured.
  - `bot/src/bot/app.py`:
    - Removed redundant `logging.basicConfig(...)` (was racing the central setup).
    - `_error_handler` now calls `capture(context.error)` after logging.
    - `_deletion_worker_loop` exception branch captures.
    - `_process_deletion_queue` 5-attempt-exhaustion site captures a synthetic `RuntimeError` so Sentry has a stack trace to group on.
  - `main.py`: both `logger.critical` exit paths (dependency init failure, bot start failure) capture before `sys.exit(1)`.
  - `.env.example` documents `SENTRY_DSN` (empty by default — disabled), `ENVIRONMENT=prod`, `LOG_LEVEL=INFO`.
  - 16 unit tests in `tests/test_observability.py`: Sentry gating (no-DSN / empty / whitespace / present), capture as no-op-when-uninitialized / forwards-when-initialized / swallows-internal-errors, idempotent init, JSON formatter (valid JSON / extras / drops noise / unserializable fallback / exception traceback), setup_logging (replaces handlers / respects level / bad level safe / writes to stdout).
- **Deviations:**
  - The task spec called for `traces_sample_rate=0.0` — done. No transaction sampling on the free tier, only error events.
  - `send_default_pii=False` added (Sentry default ships breadcrumbs with cookies/headers) — important when Sentry has access to logs that include user IDs.
  - The `_process_deletion_queue` capture wraps the message in a synthetic `RuntimeError` because Sentry groups by exception class+message — `logger.critical(...)` alone doesn't carry an exception object.
- **Debt/Future:**
  - When the bot scales up: enable `traces_sample_rate=0.05` (5%) for selective performance traces.
  - Add Sentry tags for `user_id` and `engine_id` via `sentry_sdk.set_tag()` at synthesis sites — would help debugging by sharding events.
  - Consider `sentry_sdk.set_user({"id": ...})` in handlers so per-user issue grouping works in Sentry's UI.
- **Verification Proof:** `pytest tests/test_observability.py` → 16 passed in 0.07s. `pytest tests/` → 189 passed, 4 pre-existing failures (zero new regressions). `uv run python -c "import sentry_sdk; print(sentry_sdk.VERSION)"` → 2.54.0.

## 🔗 Related Context
- **Files:** `bot/pyproject.toml`, `bot/src/bot/main.py`, `bot/src/bot/app.py`, `bot/src/bot/utils/observability.py` (new), `.env.example`
- **Plan:** [[Production_Hardening_Sprint_Plan]]
- **Board:** [[Voice_Cloning_Bot_Board]]

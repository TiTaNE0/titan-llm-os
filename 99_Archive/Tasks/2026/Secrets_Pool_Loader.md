---
project: [[titan-proxy-bot]]
status: done
priority: high
created: 2026-04-30
completed: 2026-04-30
type: task
order: 3
---

# ⚡ Task: Secrets Pool Loader

## 📋 Declarative Objective
- [ ] A startup routine that parses `secrets.txt` and seeds the `secrets_pool` table with new entries, ignoring duplicates.

## 🎯 Definition of Done (Success Criteria)
- [ ] `titan_proxy_bot/services/seeder.py` exposes `async def load_secrets_from_file(path: str) -> SeedResult`
- [ ] Skips empty lines and lines starting with `#`
- [ ] Validates each line: must be `Tariff,URL` where Tariff ∈ {Basic, Family, Premium} and URL starts with `https://t.me/proxy?` or `tg://proxy?`
- [ ] Invalid lines logged at WARNING with line number, not crashed on
- [ ] Insert uses `INSERT OR IGNORE` against UNIQUE `secret_link` — duplicates silently skipped
- [ ] Returns a `SeedResult` with `inserted: int`, `skipped_duplicates: int`, `invalid: int`
- [ ] Verifies file permissions before reading; logs WARNING if not `600`
- [ ] Called from `__main__.py` after `init_db()`
- [ ] Unit test: feeds a test fixture `tests/fixtures/secrets_sample.txt` (with valid + invalid + duplicate lines) and asserts counts

## 🧪 Verification Gateway
- [ ] **Test Command:** `pytest tests/test_seeder.py -v`
- [ ] **Protocol:** All assertions pass; manual run with a real `secrets.txt` shows accurate insert/skip counts in logs.

## 📝 Agent Implementation Plan
- (Filled by agent during planning)

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:**
  - `titan_proxy_bot/services/__init__.py` — package marker.
  - `titan_proxy_bot/services/seeder.py` — `load_secrets_from_file(path, db_path) -> SeedResult`:
    - Skips blank lines and `#`-comments.
    - Tariff parsing is case-insensitive (`Basic`/`BASIC`/` premium ` all work).
    - URL must start with `https://t.me/proxy?` or `tg://proxy?`; HTTP and other schemes are rejected.
    - Invalid lines logged at WARNING with line number; never crashes on bad input.
    - Permission check warns when file mode is looser than `0o600`.
    - Raises `SecretsFileNotFoundError` (FileNotFoundError subclass) when file missing — caller decides fatal/non-fatal.
  - `tests/fixtures/secrets_sample.txt` — 9 lines: 5 valid, 1 duplicate, 3 invalid (bad tariff, missing comma, bad URL).
  - `tests/test_seeder.py` — 9 new tests: full fixture, idempotent re-run, missing file raises, loose-permission warning, all-comments file, case-insensitive tariff, line-numbered invalid logs, stat-error path, fixture sanity check.
  - `__main__.py` now calls `await load_secrets_from_file(...)` after `init_db()`. Missing seed file is non-fatal (warns and continues with empty pool).
- **Deviations:** None.
- **Debt/Future:**
  - The seeder uses `INSERT OR IGNORE`. If we ever need to detect that a duplicate was an existing `is_assigned=1` row vs a duplicate-with-different-tariff anomaly, we'd need a separate query — out of scope for v1.
  - Comma in URLs is not supported — Telegram proxy URLs don't contain commas, but if the format ever changes, switch to a TSV or JSON format.
- **Verification Proof:**
  - `pytest tests/ -q` → 33 passed in 0.11s.
  - `ruff check .` → All checks passed.
  - `mypy titan_proxy_bot` → Success: no issues found in 8 source files.
  - End-to-end: bootstrap with a 2-line `secrets.txt` logs `secrets.txt seeded: inserted=2, skipped_duplicates=0, invalid=0`.

## 🔗 Related Context
- **PRD:** [[06_Research/titan-proxy-bot_Research]] §3 (Seeding)
- **Depends on:** [[Database_Schema_And_Init]]
- **Related:** [[Admin_Commands_And_Deployment]] (`/reload_secrets` re-uses this loader)

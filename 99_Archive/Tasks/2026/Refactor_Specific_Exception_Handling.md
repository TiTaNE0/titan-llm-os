---
project: [[Voice_Cloning_Bot]]
status: in-progress
priority: low
created: 2026-05-02
type: task
---

# ⚡ Task: Replace Bare Except with Specific Exception Types

## 📋 Declarative Objective
- [ ] Replace bare `except:` clauses in `bot/src/bot/database.py` and other bot modules with specific exception types (`aiosqlite.OperationalError`, etc.) to improve debuggability and avoid swallowing critical errors.

## 🎯 Definition of Done (Success Criteria)
- [ ] No bare `except:` clauses remain in `bot/src/bot/database.py`.
- [ ] Every `except` clause specifies the exception type(s) it expects to catch.
- [ ] Test suite still passes.

## 🧪 Verification Gateway
- [ ] **Test Command:** `cd /Users/titane0/Programming/voice-bot && grep -nE 'except\s*:' bot/src/bot/database.py`
- [ ] **Protocol:** Command should produce no output. Then run `uv run pytest tests/test_database_new.py` and verify exit code 0.

## 📝 Agent Implementation Plan
1. Identify the bare `except:` at line 109 in `database.py`.
2. Change it to `except aiosqlite.OperationalError:` (the only error that can occur on an `ALTER TABLE` / `SELECT` against a missing column).
3. Run tests.

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** Replaced `except:` at line 109 of `bot/src/bot/database.py` (legacy `user_settings` migration check) with `except aiosqlite.OperationalError:` — the only error that can occur on `SELECT state FROM user_settings` if the column was missing.
- **Deviations:** None.
- **Debt/Future:** Worth running the same audit across `bot/src/bot/app.py`, `bot/src/bot/onboarding.py`, and provider modules in a follow-up task.
- **Verification Proof:** `grep -nE 'except\s*:' bot/src/bot/database.py` produces no output. `pytest tests/test_database_new.py` shows 26 passed (1 pre-existing failure unrelated to this work).

## 🔗 Related Context
- **Files:** `bot/src/bot/database.py`
- **Board:** [[Voice_Cloning_Bot_Board]]

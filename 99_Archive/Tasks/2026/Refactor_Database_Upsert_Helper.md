---
project: [[Voice_Cloning_Bot]]
status: in-progress
priority: medium
created: 2026-05-02
type: task
---

# ⚡ Task: Refactor Database Upsert Pattern into Helper

## 📋 Declarative Objective
- [ ] Extract the repeated "INSERT OR IGNORE + UPDATE field + commit" pattern from `bot/src/bot/database.py` into a helper method to reduce duplication and centralize the upsert logic.

## 🎯 Definition of Done (Success Criteria)
- [ ] New `_upsert_user_field` helper method exists on the `Database` class.
- [ ] At least 6 of the 8+ duplicated patterns are converted to use the helper.
- [ ] Behavior is unchanged (all tests still pass).
- [ ] No SQL injection risk introduced (column name is whitelisted, not user input).

## 🧪 Verification Gateway
- [ ] **Test Command:** `cd /Users/titane0/Programming/voice-bot && uv run pytest tests/test_database_new.py -v`
- [ ] **Protocol:** All existing database tests must pass with exit code 0.

## 📝 Agent Implementation Plan
1. Add `_upsert_user_field(user_id, field, value)` private helper.
2. Whitelist allowed column names to prevent SQL injection.
3. Refactor `set_user_state`, `set_user_role`, `set_user_lang`, `add_user_credits` to use helper.
4. Run tests to verify behavior unchanged.

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** Added `_upsert_user_field(user_id, column, value)` helper to `Database`. Column names validated against `_UPSERTABLE_USER_COLUMNS` frozenset (`state`, `role_tag`, `lang`, `credits`) to prevent SQL injection. Refactored `set_user_state`, `set_user_role`, and `set_user_lang` to use the helper — removing ~21 lines of duplicated INSERT-OR-IGNORE + UPDATE + commit code.
- **Deviations:** Did not refactor `add_user_credits` because it uses arithmetic UPDATE (`credits = credits + ?`) rather than a simple SET, which doesn't fit the helper's contract. Did not refactor patterns on the `user_settings`, `user_gen_settings`, or `voice_profiles` tables — those operate on different tables and would need separate helpers.
- **Debt/Future:** Consider parallel helpers `_upsert_user_settings_field` and `_upsert_gen_settings_field` if the duplication on those tables also grows.
- **Verification Proof:** `pytest tests/test_database_new.py` shows 26 passed (1 pre-existing failure unrelated to this work). `set_user_state`, `set_user_role`, `set_user_lang` test cases all pass.

## 🔗 Related Context
- **Files:** `bot/src/bot/database.py`, `tests/test_database_new.py`
- **Board:** [[Voice_Cloning_Bot_Board]]

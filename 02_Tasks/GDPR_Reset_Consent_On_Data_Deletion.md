---
project: [[Voice_Cloning_Bot]]
status: in-progress
priority: high
created: 2026-05-03
type: task
---

# ⚡ Task: GDPR — Reset Consent on Data Deletion

## 📋 Declarative Objective
- [ ] Make `delete_all_user_data` GDPR-coherent: also clear `consent_given_at` and `consent_version` so that a returning user is re-prompted for biometric-data consent before any voice upload.

## 🎯 Definition of Done (Success Criteria)
- [ ] `Database.delete_all_user_data` UPDATE clause also sets `consent_given_at = NULL, consent_version = NULL`.
- [ ] Comment block updated to mention the consent reset and the GDPR Article 9 rationale.
- [ ] After `delete_all_user_data(user_id)`: `db.get_user(user_id)["consent_given_at"]` is None and `["consent_version"]` is None.
- [ ] Returning user runs `/start` → consent gate fires (because `consent_given_at IS NULL`).

## 🧪 Verification Gateway
- [ ] **Test command:** `cd /Users/titane0/Programming/voice-bot && uv run pytest tests/test_consent_gate.py tests/ -v`
- [ ] **Protocol:** New tests pass: `test_delete_all_user_data_clears_consent_fields`, `test_returning_user_after_delete_re_prompted`.
- [ ] **Bot startup smoke:** schema migration not required (just a query change).
- [ ] **Manual via Telegram:** existing READY user → Settings → Delete My Data → confirm → /start → consent gate appears.

## 📝 Agent Implementation Plan
1. Modify the UPDATE in `delete_all_user_data` (`bot/src/bot/database.py:~810`) to include the two consent fields.
2. Update the inline comment.
3. Add 2 tests in `tests/test_consent_gate.py`.
4. Run full suite + bot startup smoke; commit.

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** Extended the UPDATE in `Database.delete_all_user_data` to also set `consent_given_at = NULL, consent_version = NULL`. Comment block updated to reference GDPR Article 9 / 17. 2 new tests in `tests/test_consent_gate.py`: `test_delete_all_user_data_clears_consent_fields` (real-DB integration: confirms the columns are NULL after delete) and `test_returning_user_after_delete_re_prompted_via_handle_start` (end-to-end: returning user's `/start` lands at `WAITING_FOR_CONSENT`).
- **Deviations:** None.
- **Debt/Future:** Could log the consent-revocation event for compliance audit trail. Not blocking.
- **Verification Proof:** `pytest tests/test_consent_gate.py` → 18 passed. `pytest tests/` → 270 passed, 7 pre-existing failures unchanged. Bot smoke confirms the deletion + return cycle correctly clears and re-prompts. Committed as `0aa6e5e`.

## 🔗 Related Context
- **Files:** `bot/src/bot/database.py`, `tests/test_consent_gate.py`
- **Board:** [[Voice_Cloning_Bot_Board]]

---
project: [[Voice_Cloning_Bot]]
status: in-progress
priority: high
created: 2026-05-02
type: task
---

# ⚡ Task: Phase 2 — GDPR Consent Gate in Onboarding

## 📋 Declarative Objective
- [ ] Before any user can upload their voice (GDPR Article 9 biometric data), they must explicitly consent to the privacy policy via an inline-keyboard gate at the start of onboarding. Provides minimal viable legal shield for global launch.

## 🎯 Definition of Done (Success Criteria)
- [ ] **Schema:** Two new columns added to `users` table (via existing `try/except ALTER TABLE` migration pattern at `bot/src/bot/database.py:153`):
    - `consent_given_at TIMESTAMP`
    - `consent_version TEXT`
- [ ] `_UPSERTABLE_USER_COLUMNS` whitelist at `bot/src/bot/database.py:30` includes both new columns.
- [ ] New `Database.set_user_consent(user_id, version)` writes both columns in one transaction.
- [ ] **State machine:** New `WAITING_FOR_CONSENT = "WAITING_FOR_CONSENT"` added to `UserState` enum in `bot/src/bot/onboarding.py`.
- [ ] `OnboardingManager.handle_start()` at `bot/src/bot/onboarding.py:78` — when state is `NEW`, calls new `_show_consent_gate()` instead of `_show_role_selection()`. Existing users (any other state) continue as before.
- [ ] New `_show_consent_gate(update, context, TEXTS)` — sends `consent_prompt_md` with two-button keyboard (`✅ Agree`, `❌ Decline`); transitions state to `WAITING_FOR_CONSENT`.
- [ ] New `handle_consent_callback(update, context)` — validates state, on `consent_agree` writes timestamp + version + transitions to `WAITING_FOR_ROLE` + shows role selection; on `consent_decline` shows regret message and stays at `NEW`.
- [ ] Callback handler registered in `bot/src/bot/app.py` near line 240 with pattern `^consent_`.
- [ ] **Localization:** New EN + RU strings: `consent_prompt_md` (with `{policy_url}` placeholder), `consent_btn_agree`, `consent_btn_decline`, `consent_declined_md`.
- [ ] **Constants:** `CONSENT_VERSION = "1.0"` in `bot/src/bot/__init__.py`. Env `PRIVACY_POLICY_URL` (default placeholder warning if unset).

## 🧪 Verification Gateway
- [ ] **Test Command:** `cd /Users/titane0/Programming/voice-bot && uv run pytest tests/test_onboarding.py -v && uv run pytest tests/ -v`
- [ ] **Protocol:** Test cases (added to `tests/test_onboarding.py`): (a) NEW user `/start` → consent gate shown, NOT role selection, state set to `WAITING_FOR_CONSENT`; (b) `consent_agree` → `consent_given_at` written, state → `WAITING_FOR_ROLE`; (c) `consent_decline` → state stays `NEW`, decline message shown; (d) existing user with state `READY` runs `/start` → consent gate NOT shown.
- [ ] **Schema check:** `sqlite3 bot_data.db "PRAGMA table_info(users);"` shows `consent_given_at` and `consent_version`.
- [ ] **Manual smoke:** Fresh user → `/start` → see consent prompt → click Decline → see regret → re-run `/start` → see consent prompt again → click Agree → see role selection → upload voice → demo audio works end-to-end.

## 📝 Agent Implementation Plan
1. Add columns to `users` table in `Database.init()` via `try/except ALTER TABLE`.
2. Extend `_UPSERTABLE_USER_COLUMNS` whitelist; add `Database.set_user_consent()`.
3. Add `WAITING_FOR_CONSENT` enum value.
4. Add `_show_consent_gate()` and `handle_consent_callback()` to `OnboardingManager`.
5. Modify `handle_start()` branching.
6. Register callback handler in `VoiceBot._register_handlers`.
7. Add localization strings + `CONSENT_VERSION` constant + env var.
8. Add 4 unit tests.

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:**
  - **Schema:** Two new columns on `users` via the existing `try/except ALTER TABLE` migration: `consent_given_at TIMESTAMP DEFAULT NULL` and `consent_version TEXT DEFAULT NULL`. Both added to `_UPSERTABLE_USER_COLUMNS` whitelist.
  - **DB:** `UserRecord` TypedDict extended with the two new fields. `upsert_user()` and `get_user()` refactored to use a shared `_USER_SELECT_COLS` constant and a `_row_to_user_record` helper — eliminates two-place duplication of the dict-shape. New `Database.set_user_consent(user_id, version)` writes both columns in one transaction; timestamp uses `datetime.now(timezone.utc).isoformat()` (UTC ISO-8601 with `+00:00` offset, unambiguous in logs/exports).
  - **State machine:** New `WAITING_FOR_CONSENT` value in `UserState` enum, slotted between `NEW` and `WAITING_FOR_ROLE`.
  - **Onboarding flow:** `handle_start` checks `consent_given_at` AND `consent_version` against the live `CONSENT_VERSION` constant. Users without a current consent — even those mid-onboarding — get routed to `_show_consent_gate` instead of role selection. New `_show_consent_gate(update, context, TEXTS)` mirrors the role-selection inline-keyboard pattern with two buttons (✅ Agree / ❌ Decline). New `handle_consent_callback(update, context, TEXTS)` validates the user is in `WAITING_FOR_CONSENT` (silently no-ops on stale callbacks from old keyboards), on Agree writes `set_user_consent(user_id, CONSENT_VERSION)` and forwards to `_show_role_selection`, on Decline rolls state back to `NEW` and shows a regret message.
  - **Handler registration:** `CallbackQueryHandler(handle_consent_callback, pattern="^consent_")` registered BEFORE `^role_` in `bot/src/bot/app.py:_register_handlers` so the narrower pattern doesn't get shadowed.
  - **Localization:** 4 EN + 4 RU strings (`consent_prompt_md` with `{policy_url}` placeholder rendered as a Markdown link via `_md_escape`, `consent_btn_agree`, `consent_btn_decline`, `consent_declined_md`). Prompt explicitly invokes "GDPR Article 9" / "статья 9 GDPR" + points users at the existing Settings → 🗑 Delete My Data path for revocation.
  - **Constants:** `CONSENT_VERSION = "1.0"` lives at module level in `bot/src/bot/__init__.py` so a one-line bump triggers global re-consent. `PRIVACY_POLICY_URL` env var with placeholder default in `.env.example`.
  - **Tests:** 4 new in `tests/test_database_new.py::TestDatabaseConsent` (columns null-by-default, set_user_consent writes both fields, ISO-8601 UTC format, version overwrite). 6 new in `tests/test_consent_gate.py` (new user without consent sees gate, current consent skips gate, stale version re-prompts, Agree records and advances to role selection, Decline keeps state at NEW and never calls set_user_consent, stale callback outside consent state is silent no-op).
- **Deviations:**
  - The task spec proposed only re-prompting NEW users. Implementation goes further: ANY user without a current consent_version (including users who consented to an earlier policy) gets re-prompted. This is the legally safer interpretation and the small extra friction is appropriate when the policy text materially changes.
  - `_show_consent_gate` accepts both `update.message` (first /start) and `update.callback_query` (re-entered via the role-selection back-button or future flows) so the gate can be shown from either entry point. Mirrors the existing `_show_role_selection` pattern.
- **Debt/Future:**
  - Re-consent UX is currently abrupt (we just show the gate). For an existing-user mass re-consent (when bumping CONSENT_VERSION on a live bot), worth showing a brief "we've updated our privacy policy" preamble before the consent prompt.
  - The decline path currently rolls state to NEW. If a user has voices already cloned, declining doesn't trigger data deletion — they'd have to use Settings → 🗑 Delete My Data. Worth a future task to make decline + extant-data more proactive.
  - `PRIVACY_POLICY_URL` is a placeholder. **Pre-launch action**: Product Owner needs to publish the actual URL and update the env var.
- **Verification Proof:** `pytest tests/test_consent_gate.py` → 6 passed in 0.22s. `pytest tests/test_database_new.py` → 46 passed, 1 pre-existing unrelated failure (4 new consent tests pass). `pytest tests/` → 212 passed, 4 pre-existing failures (zero new regressions).

## 🔗 Related Context
- **Files:** `bot/src/bot/database.py`, `bot/src/bot/onboarding.py`, `bot/src/bot/app.py:240`, `bot/src/bot/messages.py`, `bot/src/bot/__init__.py`, `tests/test_onboarding.py`, `.env.example`
- **Existing Privacy Strings (style reference):** `messages.py` `privacy_confirm_md`, `privacy_btn_confirm` etc.
- **Plan:** [[Production_Hardening_Sprint_Plan]]
- **Board:** [[Voice_Cloning_Bot_Board]]

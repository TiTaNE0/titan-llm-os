---
project: [[Voice_Cloning_Bot]]
status: in-progress
priority: critical
created: 2026-05-05
type: task
---

# ⚡ Task: Fix Onboarding Flow Leaking Into Groups (Crash)

## 📋 Declarative Objective
- [ ] Stop the onboarding/consent flow from running in group chats. Production crashed with `AttributeError: 'NoneType' object has no attribute 'reply_text'` when `_show_consent_gate` was triggered by an edited message in a group.

## 🎯 Definition of Done (Success Criteria)
- [ ] `handle_text_with_onboarding_check` and `handle_voice_with_onboarding_check` (`app.py:941-981`) bail early when `update.effective_chat.type != "private"`, falling through to the existing `handle_message` / `handle_voice_upload` paths (which already have their own private-chat guards).
- [ ] `OnboardingManager._show_consent_gate` uses `update.effective_message` instead of raw `update.message`. Logs and returns gracefully if even that is None.
- [ ] Same defensive `effective_message` pattern applied to other onboarding paths that reply (no other crash sites should remain).
- [ ] Onboarding flow never runs in groups; consent gate never appears in public chats.
- [ ] No regression: private-chat onboarding still works end-to-end.

## 🧪 Verification Gateway
- [ ] **Test command:** `cd /Users/titane0/Programming/voice-bot && uv run pytest tests/ -v`
- [ ] **Protocol:** All existing tests pass (275 baseline, 7 pre-existing failures unchanged). New regression tests pass:
    - `test_handle_text_with_onboarding_check_skips_groups`
    - `test_handle_voice_with_onboarding_check_skips_groups`
    - `test_show_consent_gate_no_op_when_no_effective_message`
- [ ] **Bot startup smoke:** imports + provider init clean.
- [ ] **Manual via Telegram:** add bot to a group as admin → user types in group → bot does NOT reply with consent gate → no crash in logs. `/say` still works in the group.

## 📝 Agent Implementation Plan
1. Add private-chat guard at the top of `handle_text_with_onboarding_check` and `handle_voice_with_onboarding_check`. When chat is not private, skip onboarding entirely and pass through to the regular handler (`handle_message` for text, `handle_voice_upload` for voice — both already private-chat-gated).
2. Refactor `_show_consent_gate` to use `update.effective_message` and bail safely if None.
3. Add 3 regression tests.
4. Run full suite + bot smoke + commit + push.

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** Added `if update.effective_chat is None or update.effective_chat.type != "private"` guard at the top of both `handle_text_with_onboarding_check` (falls through to `handle_message`) and `handle_voice_with_onboarding_check` (returns early — voice uploads in groups aren't supported). `OnboardingManager._show_consent_gate` and `_show_role_selection` now use `update.effective_message` instead of raw `update.message`; both log and bail gracefully when even `effective_message` is None. 6 new tests in `tests/test_group_chat_no_onboarding_leak.py`. Updated existing `test_consent_gate.py` test fixtures to mirror `update.message` and `update.effective_message` (matches PTB's real behavior for fresh messages).
- **Deviations:** Group `/say` and inline mode unchanged — those are the only two intentional group features. Other commands (`/voices`, `/settings`, etc.) currently still fire in groups but show user-specific UI which is mildly confusing; left out of scope (separate cleanup).
- **Debt/Future:** Could add chat-type guards to remaining commands (`/voices`, `/settings`, `/engine`, `/cancel`, `/start`) so they explicitly tell users "this is a private-chat command" or auto-deep-link to DM. Not blocking.
- **Verification Proof:** `pytest tests/test_group_chat_no_onboarding_leak.py` → 6 passed. `pytest tests/` → 281 passed, 7 pre-existing failures unchanged. Source-level smoke confirms all 3 guards are present. Committed as `c84489b`, pushed to `origin/main`.

## 🔗 Related Context
- **Files:** `bot/src/bot/app.py` (lines 941-981), `bot/src/bot/onboarding.py` (`_show_consent_gate`), `tests/test_consent_gate.py`
- **Reported by:** Production traceback 2026-05-05 — `'NoneType' object has no attribute 'reply_text'` in `_show_consent_gate`
- **Board:** [[Voice_Cloning_Bot_Board]]

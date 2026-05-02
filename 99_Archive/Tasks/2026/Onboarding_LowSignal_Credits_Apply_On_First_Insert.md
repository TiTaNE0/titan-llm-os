---
project: [[Voice_Cloning_Bot]]
status: in-progress
priority: high
created: 2026-05-02
type: task
---

# ⚡ Task: Apply Low-Signal Starting Credits on First Insert (Anti-Abuse Fix)

## 📋 Declarative Objective
- [ ] The Phase-1 abuse-prevention task added a low-signal credit reduction (100 credits instead of 1000 for accounts with no Telegram Premium and no `@username`). It is silently disarmed: `start()` upserts every new user with the default 1000 credits **before** `handle_start` runs the low-signal logic. The second `upsert_user(starting_credits=100)` call no-ops because the row already exists (`ON CONFLICT DO NOTHING`).

## 🎯 Definition of Done (Success Criteria)
- [ ] Low-signal Telegram accounts (no `is_premium`, no `username`) start with `LOW_SIGNAL_STARTING_CREDITS` (default 100), as the Phase-1 task originally intended.
- [ ] Normal accounts continue to start with 1000.
- [ ] Existing users are unaffected (their balances are not retroactively modified).
- [ ] No double-upsert of the user row in the `/start` codepath.
- [ ] **Single insert site** for new users — only one place in the codebase that creates the row, with the correct starting_credits computed from `update.effective_user`.
- [ ] Unit test in `tests/test_consent_gate.py` (or `tests/test_database_new.py`): simulate a fresh `/start` from a low-signal account, verify the user row is created with 100 credits (not 1000).

## 🧪 Verification Gateway
- [ ] **Test command:** `cd /Users/titane0/Programming/voice-bot && uv run pytest tests/ -v`
- [ ] **Protocol:** New regression test passes; 237-pass count holds (7 pre-existing failures unchanged).
- [ ] **Manual smoke:** From a fresh Telegram account (no Premium, no `@username`), run `/start` → check `SELECT credits FROM users WHERE telegram_id=<id>` → expect 100, not 1000.

## 📝 Agent Implementation Plan
1. Pick the cleaner of two refactors:
    - **(A, preferred)** Remove the `await self.db.upsert_user(user_id)` call at `bot/src/bot/app.py:738`. Move the language-detection + auto-set logic to AFTER `handle_start` returns (or pass `update.effective_user.language_code` into the flow another way). `handle_start`'s upsert with `starting_credits=...` becomes the single insert site.
    - **(B)** Compute `starting_credits` inside `start()` before the upsert, pass it through, and skip the second upsert in `handle_start`.
2. Verify language auto-detection still works for new users (it currently relies on the user row existing; if we move the upsert later, the language-set may need re-ordering).
3. Add the unit test described above.

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** Moved the `is_low_signal` detection + `starting_credits` computation from `OnboardingManager.handle_start` to `VoiceBot.start` (`app.py:734`). `start` now does a single `upsert_user(user_id, starting_credits=...)` call with the correct value computed from `update.effective_user` signals. `handle_start` was refactored to read the canonical user record via `db.get_user` (defensive fallback to `upsert_user(user_id)` only if missing). 2 regression tests in `tests/test_consent_gate.py` covering low-signal (100 credits) + premium (1000 credits) paths. Updated `test_handle_start_existing_user_shows_menu` fixture to override `db.get_user` since handle_start now reads from there.
- **Deviations:** Used Approach A from the task plan (move logic into start()) rather than Approach B (pass starting_credits through to handle_start). Cleaner because start() already has direct access to `update.effective_user` and the language-detection block.
- **Debt/Future:** None.
- **Verification Proof:** `pytest tests/` → 245 passed, 7 pre-existing failures unchanged (zero new regressions). Committed as `a20bba9`.

## 🔗 Related Context
- **Files:** `bot/src/bot/app.py:734-771` (`start`), `bot/src/bot/onboarding.py:99-118` (`handle_start` low-signal logic), `bot/src/bot/database.py:upsert_user`
- **Found by:** Flow audit on 2026-05-02 (issue H1)
- **Related:** [[Phase1_Abuse_Prevention_Velocity_And_Killswitch]] — this fix unblocks the abuse-prevention defense that task added.
- **Board:** [[Voice_Cloning_Bot_Board]]

---
project: [[Voice_Cloning_Bot]]
status: in-progress
priority: critical
created: 2026-05-02
type: task
---

# ⚡ Task: Consent Gate Hardening — Enforce at Every Voice-Touching Entry Point

## 📋 Declarative Objective
- [ ] The GDPR Article 9 consent gate currently fires only at `/start`. Any other entry point that touches a user's voice data — `/set_voice`, raw voice uploads while not in `WAITING_FOR_AUDIO`, `/engine` switching, etc. — bypasses consent entirely. Additionally, bumping `CONSENT_VERSION` does NOT re-prompt existing READY users with voices. Fix all of these so consent is a true cross-cutting precondition.

## 🎯 Definition of Done (Success Criteria)
- [ ] **C1 — Wizard bypass closed.** `set_voice_start` (`bot/src/bot/app.py:1094`) checks current consent before entering the wizard. If `consent_given_at is None` or `consent_version != CONSENT_VERSION`, it shows the consent gate via `OnboardingManager._show_consent_gate` and returns `ConversationHandler.END` (don't enter the wizard).
- [ ] **C2 — Voice-upload bypass closed.** When a user in `WAITING_FOR_CONSENT` (or any state without current consent) sends a voice message, the wizard `handle_voice_upload` is NOT reached. Either:
    - (preferred) `OnboardingManager.handle_audio_upload` adds a `WAITING_FOR_CONSENT` branch that re-shows the gate and returns `True` (intercepting before the fall-through), OR
    - `handle_voice_upload` checks consent at the top and aborts the wizard if not current.
- [ ] **C3 — Stale `consent_version` re-prompts existing users.** In `OnboardingManager.handle_start` (`bot/src/bot/onboarding.py:120-143`), the consent-version check moves **above** the `has_voices && state == READY` early return. Bumping `CONSENT_VERSION` re-prompts every user, voiced or not.
- [ ] **L1 — Text from `WAITING_FOR_CONSENT` users routes back to the gate.** `OnboardingManager.handle_text_message` adds a branch for `WAITING_FOR_CONSENT` that returns `True` and re-shows the consent gate (or replies with a message pointing back to `/start`).
- [ ] **L2 — `/cancel` re-shows the gate when consent isn't current.** `cancel_command` (`bot/src/bot/app.py:773`) — when there are no voices yet — checks consent before falling through to `_show_role_selection`. If consent isn't current, show the gate instead.
- [ ] **Single source of truth.** New helper, e.g. `Database.has_current_consent(user_id, version) -> bool` OR `OnboardingManager.has_current_consent(user_id) -> bool` (reuse `CONSENT_VERSION`). Every guard above goes through this one helper.
- [ ] **Tests:** New cases in `tests/test_consent_gate.py`:
    - `test_set_voice_start_blocks_when_consent_missing`
    - `test_set_voice_start_blocks_when_consent_version_stale`
    - `test_voice_upload_in_waiting_for_consent_state_re_shows_gate`
    - `test_handle_start_re_prompts_when_existing_user_has_stale_consent_version_AND_voices` (this currently fails on master because of the C3 bug — should pass after the fix)
    - `test_text_message_in_waiting_for_consent_routes_back_to_gate`
    - `test_cancel_command_with_no_voices_re_shows_gate_when_consent_missing`

## 🧪 Verification Gateway
- [ ] **Test command:** `cd /Users/titane0/Programming/voice-bot && uv run pytest tests/test_consent_gate.py -v && uv run pytest tests/ -v`
- [ ] **Protocol:** All new tests pass + existing 237-test count holds (7 pre-existing failures unchanged).
- [ ] **Manual smoke:**
    1. Fresh user → `/start` → consent gate appears → click Decline → state=NEW → run `/set_voice` directly → consent gate appears again, wizard does NOT start.
    2. User in WAITING_FOR_CONSENT → uploads a voice → bot re-shows consent gate, voice is NOT cloned.
    3. Bump `CONSENT_VERSION` to "2.0" → existing READY user with voices runs `/start` → sees the new consent gate (not the normal menu).
    4. Existing user uploads voice via Telegram (no /start) before consenting → re-shown gate.

## 📝 Agent Implementation Plan
1. Add `OnboardingManager.has_current_consent(user_id) -> bool` reading `consent_given_at` + `consent_version` and comparing against `bot.CONSENT_VERSION`.
2. In `handle_start`: move the consent check above the `has_voices && READY` early-return.
3. In `set_voice_start`: add `if not await self.onboarding.has_current_consent(user_id):` → `await self.onboarding._show_consent_gate(update, context, TEXTS); return ConversationHandler.END`.
4. In `handle_audio_upload`: add a `WAITING_FOR_CONSENT` branch that returns `True` after re-showing the gate (so `handle_voice_with_onboarding_check` doesn't fall through to the wizard).
5. In `handle_text_message`: add the same branch.
6. In `cancel_command`: add the consent check before `_show_role_selection`.
7. Add 6 new tests covering each guard.

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:**
  - New `OnboardingManager.has_current_consent(user_id) -> bool` — single source of truth, reads `consent_given_at` + `consent_version` and compares against `bot.CONSENT_VERSION`.
  - **C3:** Reordered `handle_start` (`onboarding.py:120`): consent-version check now runs BEFORE the `has_voices && state == READY` early-return so existing READY users with stale consent are re-prompted.
  - **C1:** Added consent check at the top of `set_voice_start` (`app.py:1100-1106`); blocks wizard entry and shows gate via `_show_consent_gate` if consent isn't current; returns `ConversationHandler.END`.
  - **C2:** Added `WAITING_FOR_CONSENT` / no-current-consent branch at the top of `handle_audio_upload` (`onboarding.py:381-388`); intercepts and returns True so `handle_voice_with_onboarding_check` doesn't fall through to the wizard.
  - **L1:** Same branch in `handle_text_message` (`onboarding.py:529-535`).
  - **L2:** `cancel_command` (`app.py:794-797`) re-shows gate when no voices AND no current consent.
  - 6 new tests in `tests/test_consent_gate.py`: stale-version + has-voices re-prompt; voice upload in WAITING_FOR_CONSENT; voice upload in any state without consent; text in WAITING_FOR_CONSENT; `has_current_consent` returns False for missing user; `has_current_consent` returns True only for current version (with stale + never-given negative cases).
  - Updated test fixtures in `tests/test_onboarding.py` and `tests/test_voice_setup_uses_displayed_script.py` to provide a default consented user record so existing post-consent tests don't regress.
- **Deviations:**
  - Kept the gate-decision logic in `handle_start` inline (using the user record we already loaded via `upsert_user`) rather than calling `has_current_consent` to avoid a second DB read on every /start. The other 4 sites use `has_current_consent`.
  - The audio/text handlers re-show the gate AND set state to `WAITING_FOR_CONSENT` (via `_show_consent_gate`), even if state was something else (e.g., user manually got into WAITING_FOR_AUDIO somehow without consent). Idempotent — preserves user's path back through the gate.
- **Debt/Future:**
  - Inline mode (`handle_inline_generate`, `_process_automatic_generation`) doesn't enforce consent. Inline mode synthesizes from the user's existing voice profile — they can only have a voice profile if they consented at creation time. So existing flows are safe; but a CONSENT_VERSION bump won't lock out inline-mode usage of an old voice profile until the user runs `/start` and re-consents. Consider adding consent check to inline paths too.
  - The defensive `state == WAITING_FOR_CONSENT` short-circuit in audio/text handlers is technically redundant once `has_current_consent` is robust; kept for clarity and defense-in-depth.
- **Verification Proof:** `pytest tests/test_consent_gate.py` → 12 passed in 0.27s. `pytest tests/` → 243 passed, 7 pre-existing failures unchanged (zero new regressions). Committed as `a23dba2`.

## 🔗 Related Context
- **Files:** `bot/src/bot/onboarding.py` (handle_start, handle_audio_upload, handle_text_message, _show_consent_gate, new helper), `bot/src/bot/app.py` (set_voice_start, cancel_command, possibly handle_voice_upload), `tests/test_consent_gate.py`
- **Reused:** `OnboardingManager._show_consent_gate` (`onboarding.py:189`), `bot.CONSENT_VERSION` constant (`bot/__init__.py`)
- **Found by:** Flow audit on 2026-05-02 (issues C1, C2, C3, L1, L2)
- **Board:** [[Voice_Cloning_Bot_Board]]

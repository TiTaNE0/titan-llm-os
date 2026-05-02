---
project: [[Voice_Cloning_Bot]]
status: done
priority: high
created: 2026-05-02
type: task
---

# ⚡ Task: Enable Local Qwen TTS for admin user

## 📋 Declarative Objective
Configure Local Qwen as an available TTS provider for admin user (developer mode). Currently: hardcoded to skip or unavailable. Goal: Admin can test LOCAL_QWEN engine for free, local GPU synthesis without cloud API costs.

## 🎯 Definition of Done (Success Criteria)
- [ ] ADMIN_USER_IDS env var checked in router for LOCAL_QWEN access
- [ ] Admin user can select LOCAL_QWEN from /engine command
- [ ] Admin can clone voices to LOCAL_QWEN
- [ ] Admin can synthesize with LOCAL_QWEN (no credit cost)
- [ ] Non-admin users see LOCAL_QWEN disabled with reason message
- [ ] Router blocks non-admin LOCAL_QWEN synthesis with error
- [ ] Tests confirm access control works

## 🧪 Verification Gateway
- [ ] **Test Command:** `uv run pytest tests/test_localqwen_admin_access.py -v`
- [ ] **Manual Test:** Login as admin → /engine → select LOCAL_QWEN → synthesize → confirm works

## 📝 Agent Implementation Plan
1. Check router.generate() and router.clone_voice():
   - Validate LOCAL_QWEN access: `if "qwen" in engine_id.lower() and "LOCAL" in engine_id: check if user in ADMIN_USER_IDS`
   - Raise PermissionError if non-admin attempts LOCAL_QWEN

2. Update /engine command in app.py:
   - Filter engine list: include LOCAL_QWEN only for admin users
   - Show "Developer Mode" label for admin-only engines

3. Update /clone_voice flow:
   - Allow LOCAL_QWEN for admin
   - Prevent non-admin from cloning to LOCAL_QWEN

4. Update credit deduction:
   - LOCAL_QWEN synthesis should not deduct credits for admins

5. Add tests:
   - Admin can access LOCAL_QWEN
   - Non-admin blocked from LOCAL_QWEN
   - Credit flow correct

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** UI-level admin checks already existed at 3 engine selection points in `app.py` (lines 1025, 1063, 2106). Added defense-in-depth guard at synthesis time in `_generate_and_send_voice()` (app.py:1707-1712) — blocks LOCAL_QWEN synthesis for non-admins even if they somehow have it as active engine (legacy DB, manual override, etc.). Uses existing `_is_admin()`, `EngineNames`, and `error_generic` text key.
- **Deviations:** No credit bypass for admin LOCAL_QWEN synthesis — local GPU has no cost, but credit deduction is a separate concern and out of scope here.
- **Debt/Future:** Add LOCAL_QWEN warm-start pool for faster cold starts
- **Verification Proof:** (To be filled)

## 🔗 Related Context
- **Files:** `bot/src/bot/providers/router.py`, `bot/src/bot/app.py`, `.env` example
- **Environment:** ADMIN_USER_IDS (comma-separated Telegram user IDs)
- **DX Impact:** Free developer testing on local GPU

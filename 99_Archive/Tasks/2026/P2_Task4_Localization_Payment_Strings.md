---
project: [[Voice_Cloning_Bot]]
status: done
priority: medium
created: 2026-04-27
type: task
---

# ⚡ Task: P2_Localization_Payment_Strings

## 📋 Declarative Objective
- [ ] Update `bot/src/bot/messages.py` (`TEXTS_EN` and `TEXTS_RU`) with all payment-related UI strings.

## 🎯 Definition of Done (Success Criteria)
- [ ] All required keys are present in both dictionaries:
  - `menu_buy_credits_title`
  - `invoice_title_tier1`, `invoice_desc_tier1`
  - `invoice_title_tier2`, `invoice_desc_tier2`
  - `invoice_title_tier3`, `invoice_desc_tier3`
  - `payment_success`
  - `payment_failed`
- [ ] `payment_success` supports a `{credits}` placeholder.
- [ ] English fallback remains intact (`{**TEXTS_EN, **TEXTS_RU}`).

## 🧪 Verification Gateway
- [ ] **Test Command:** `python -c "from bot.messages import get_texts; t=get_texts('RU'); print(t['payment_success'].format(credits=2500))"`
- [ ] **Protocol:** Confirm no `KeyError` and formatted output is correct in both EN and RU.

## 📝 Agent Implementation Plan
- Append new keys to `TEXTS_EN` and `TEXTS_RU` in `bot/src/bot/messages.py`.
- Ensure dynamic values in `_md` keys use `_md_escape()` if rendered with MarkdownV2.

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** All required payment keys were added incrementally during Tasks 2 and 3. Verified via script that all 12 keys exist in both TEXTS_EN and TEXTS_RU.
- **Deviations:** Task was completed ahead-of-schedule (inline with Tasks 2 and 3) to prevent runtime KeyErrors.
- **Debt/Future:** None.
- **Verification Proof:** `python3 -c "from messages import TEXTS_EN, TEXTS_RU; keys=[...]; print('All present:', all(k in TEXTS_EN and k in TEXTS_RU for k in keys))"` returned `True`.

## 🔗 Related Context
- **Skills:** [[.agent/skills/telegram-handler-registration/SKILL]]

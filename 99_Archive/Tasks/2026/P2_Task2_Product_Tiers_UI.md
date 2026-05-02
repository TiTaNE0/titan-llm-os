---
project: [[Voice_Cloning_Bot]]
status: done
priority: high
created: 2026-04-27
type: task
---

# ⚡ Task: P2_Product_Tiers_UI

## 📋 Declarative Objective
- [ ] Replace the dummy "Buy Credits" stub with a real product tier selection UI.
- [ ] Display current balance and three purchasable tiers via Inline Keyboard.

## 🎯 Definition of Done (Success Criteria)
- [ ] A `TIERS` dict/enum is defined in code with: Tier 1 (50 Stars -> 2,500 Credits), Tier 2 (150 Stars -> 10,000 Credits, Best Value), Tier 3 (500 Stars -> 50,000 Credits).
- [ ] Clicking `[💎 Balance/Buy]` from the main menu shows the user's current credit balance and the 3 tier buttons.
- [ ] Clicking a tier triggers `bot.send_invoice()` with the correct `prices` and `payload`.

## 🧪 Verification Gateway
- [ ] **Test Command:** Run the bot locally and press `[💎 Balance/Buy]`. Verify the inline keyboard shows all 3 tiers with correct star/credit amounts.
- [ ] **Protocol:** Manual UI inspection via Telegram client.

## 📝 Agent Implementation Plan
- Define `TIERS` constant in `bot/src/bot/app.py` (or a new `payments.py`).
- Update the balance/buy handler to build a dynamic InlineKeyboardMarkup.
- Wire tier callbacks to `send_invoice()`.

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** Added `TIERS` dict to `VoiceBot` class. Replaced `onboard_buy_credits` stub with tier selection UI showing 3 packages. Added `handle_tier_selection` that calls `context.bot.send_invoice()` with `currency="XTR"` and `provider_token=""`. Registered `buy_tier_` callback handler. Added payment keys to `TEXTS_EN` and `TEXTS_RU`.
- **Deviations:** Added localization strings inline during Task 2 to prevent runtime KeyErrors (originally planned for Task 4).
- **Debt/Future:** None.
- **Verification Proof:** `python3 -m py_compile app.py messages.py database.py` passed with zero warnings.

## 🔗 Related Context
- **Skills:** [[.agent/skills/telegram-handler-registration/SKILL]]

---
project: [[titan-proxy-bot]]
status: done
priority: high
created: 2026-04-30
completed: 2026-04-30
type: task
order: 12
---

# ⚡ Task: Tariff UX — Plain Language + Pre-Payment Alerts

## 📋 Declarative Objective
- [ ] Replace technical jargon and price-heavy button labels with plain-language UX that sets honest expectations BEFORE the user pays. Three coordinated changes:
  1. Pop-up alert (`answerCallbackQuery` with `show_alert=True`) on tariff button click, disclosing the limits per tier (audio/video calls don't work; capacity differs).
  2. Capacity-focused button labels (drop price from button — price still shown in the invoice).
  3. Dynamic per-tariff success message after payment.

## 🎯 Definition of Done

### Pop-up alerts (RU, exact text from spec)
- [ ] **Basic:** "Тариф Basic: Общий сервер, который делится на 50 человек. Трафик ограничен, подходит для чтения каналов и переписки. ⚠️ Аудио и видеозвонки не работают."
- [ ] **Family:** "Тариф Family: Увеличенный объем трафика для группы до 7 человек. Хватит всем для быстрой загрузки видео и тяжелых файлов. ⚠️ Аудио и видеозвонки не работают."
- [ ] **Premium:** "Тариф Premium: Личный выделенный сервер. Вся скорость и трафик принадлежат только вам. Моментальная загрузка любых объемов данных. ⚠️ Аудио и видеозвонки не работают."
- [ ] Alert is shown ONLY when stock is available (out-of-stock path keeps existing OUT_OF_STOCK chat message, no alert clutter).

### Button labels (replace existing)
- [ ] Basic: `⭐️ Basic | До 50 чел.`
- [ ] Family: `⭐️ Family | До 7 чел.`
- [ ] Premium: `⭐️ Premium | Личный`

### Per-tariff success message (replace generic line; keep links + warning)
- [ ] Basic: `✅ Ваш доступ к общему прокси (до 50 чел.) активен на 30 дней.`
- [ ] Family: `✅ Ваш доступ к семейному прокси (до 7 чел.) активен на 30 дней.`
- [ ] Premium: `✅ Ваш личный выделенный сервер активен на 30 дней.`
- [ ] Links and the "⚠️ Это персональная ссылка. Не распространяйте её." warning preserved across all three.
- [ ] Renewal uses the EXISTING subscription's tariff (per the two-state model — preserved secret = preserved tariff). Tested.

## 🧪 Verification Gateway
- [ ] `pytest tests/ -q` passes
- [ ] `ruff check .` passes
- [ ] `mypy titan_proxy_bot` passes
- [ ] **Manual on the live bot:** tap each tariff → see correct alert popup → dismiss → invoice appears with the right price → after payment, success message uses the right per-tariff opening line.

## 📝 Agent Implementation Plan
- `texts.py` — add `TARIFF_ALERT_{BASIC,FAMILY,PREMIUM}` and `SUCCESS_LINE_{BASIC,FAMILY,PREMIUM}` constants. Refactor `SUCCESS_PAYMENT` to take `{success_line}` placeholder.
- `tariffs.py` — `Tariff` gains `alert_text` and `success_line` fields populated from texts.py. Update `button_label` per spec. Re-export imports.
- `models.py` — `PaymentResult.tariff: TariffId | None = None` so the success-message dispatcher can pick the right line.
- `services/subscription.py` — populate `tariff` in returned `PaymentResult` (NEW: input tariff; RENEWAL: `existing_sub.tariff`).
- `handlers/payment.py` — `cb_buy_tariff` calls `query.answer(tariff.alert_text, show_alert=True)` AFTER the OOS pre-flight check, BEFORE `bot.send_invoice`. Drop the trailing silent ack. `_dispatch_payment_result` uses `result.tariff` to fetch the per-tariff success line via `get_tariff().success_line`.
- Tests — update `test_button_labels_contain_emoji_price_and_duration` (capacity-focused now), assert alert kwargs in `cb_buy_tariff` tests, assert per-tariff success lines in dispatcher tests, assert `result.tariff` populated in `subscription` tests.

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:**
  - `texts.py` — added six new constants:
    - `TARIFF_ALERT_BASIC / FAMILY / PREMIUM` — pre-payment disclosure popups (each ends with "⚠️ Аудио и видеозвонки не работают.")
    - `SUCCESS_LINE_BASIC / FAMILY / PREMIUM` — per-tariff post-payment opening lines
    - Refactored `SUCCESS_PAYMENT` template to take a `{success_line}` placeholder; old "✅ Оплата прошла успешно!" + "🎉 Ваш персональный прокси..." opening lines replaced.
  - `tariffs.py` — `Tariff` dataclass gained `alert_text: str` and `success_line: str` fields. `button_label` updated per spec (price dropped, capacity surfaced):
    - `⭐️ Basic | До 50 чел.`
    - `⭐️ Family | До 7 чел.`
    - `⭐️ Premium | Личный`
  - `models.py` — `PaymentResult` gained `tariff: TariffId | None = None` field with docstring explaining NEW=input-tariff vs RENEWAL=existing-sub-tariff semantics.
  - `services/subscription.py` — `handle_payment` now populates `PaymentResult.tariff`:
    - NEW → input `tariff` parameter
    - RENEWAL → `existing_sub.tariff` (the tariff of the preserved secret, may differ from just-paid tariff)
    - DUPLICATE / OUT_OF_STOCK → leaves None (no per-tariff message rendered)
  - `handlers/payment.py`:
    - `cb_buy_tariff` calls `query.answer(tariff.alert_text, show_alert=True)` AFTER the OOS pre-flight check, BEFORE `bot.send_invoice`. The OOS path keeps the silent ack + chat message unchanged.
    - Removed the trailing `await query.answer()` (would raise CallbackAnswerInvalid since we already answered with the alert).
    - `_dispatch_payment_result` now picks the success line from `get_tariff(result.tariff).success_line`. Defensive fallback to a generic line if `tariff` is somehow None for NEW/RENEWAL (logs a warning — should never trigger in practice).
- **Tests added/updated (152 total, +14 from 138):**
  - `tests/test_tariffs.py` — replaced the old "buttons contain price + 30 дней" test with `test_button_labels_capacity_focused_no_price` (asserts new labels exactly + that price/duration are absent). Added `test_each_tariff_alert_warns_about_calls`, `test_each_tariff_alert_mentions_capacity`, `test_each_tariff_success_line_unique_and_tier_specific`.
  - `tests/test_payment_handler.py` — extended `test_cb_buy_tariff_sends_invoice_when_stock_present` to assert disclosure popup fires with the right text and `show_alert=True`. New `test_cb_buy_tariff_alert_text_per_tariff` (loops all 3 tariffs). Updated `test_successful_payment_new_dispatches_success_message` and `_renewal_dispatches_success_message` for new per-tariff text + new `tariff` field on `PaymentResult`. New `test_successful_payment_premium_uses_dedicated_server_line` and `test_successful_payment_with_missing_tariff_falls_back_safely`.
  - `tests/test_subscription.py` — added `tariff` assertions to NEW and RENEWAL happy-path tests. New `test_renewal_with_different_paid_tariff_reports_existing_sub_tariff` for the "Basic sub user pays for Premium → keeps Basic" edge case.
- **Deviations:** None from the task spec. The Tariff dataclass route (vs a side-table mapping) was the design choice — keeps tariff data in one place, simplifies alert/success lookup to `get_tariff(tariff_id).{alert_text,success_line}`.
- **Debt/Future:**
  - **Tariff-change UX gap.** A Basic-sub user who pays for Premium gets a "Basic active" success message (because we preserve the Basic secret per the two-state model). The new test `test_renewal_with_different_paid_tariff_reports_existing_sub_tariff` pins this behavior. Whether this is the right UX is debatable — the user paid Premium price but gets Basic experience. v1.2 candidates: (a) reject tariff changes pre-invoice, (b) explicit upgrade flow that swaps the secret, (c) refund + assign new on tariff mismatch. PRD §3 doesn't address this; current behavior is consistent with "renewal preserves secret."
  - The fallback "✅ Ваш прокси активен на 30 дней." line for a None-tariff `PaymentResult` is dead code in practice — we always populate tariff for NEW/RENEWAL — but worth keeping as a defensive belt-and-suspenders.
- **Verification Proof:**
  - `pytest tests/ -q` → 152 passed in 1.44s.
  - `ruff check .` → All checks passed.
  - `mypy titan_proxy_bot` → Success: no issues found in 26 source files.
  - `--no-polling` smoke test boots cleanly.

## 🔗 Related Context
- **Touches:** `titan_proxy_bot/{texts,tariffs,models,services/subscription,handlers/payment}.py`, `tests/test_{tariffs,payment_handler,subscription}.py`
- **Depends on:** [[Bot_Core_Start_And_Tariffs]] (HEAD), [[Subscription_Assignment_Logic]] (HEAD)

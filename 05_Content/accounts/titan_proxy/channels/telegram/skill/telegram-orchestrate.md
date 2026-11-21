---
type: operator_runbook
channel: telegram
account: titan_proxy
status: active
created: 2026-11-18
---

# Runbook — Telegram Channel Post Pipeline (Titan Proxy)

Repeatable workflow for researching, drafting, verifying, and shipping new posts for `@TitanMTProxyNews` into `/Users/titane0/Programming/titan-proxy-bot/content/posts.json`.

## Prerequisites
- Vault link available at `./.vault_link/` (or `/Users/titane0/Programming/titan-proxy-bot/.vault_link/`).
- Gemini access via `agy -p` for independent Critic veto.
- Optional: `grok -p` only when researching a brand-new external topic or payment shift.

## Phase 1: Calendar & Topic Selection (Strategist — Autonomous)
1. Read `05_Content/accounts/titan_proxy/channels/telegram/calendar.yaml`, `backlog.md`, and `LEDGER.md`.
2. Any `planned` calendar event within its `lead_days` window is autonomously promoted to `active` (no human approval required) inside `promo_guardrails` (`5..14` bonus days, fixed `139/329/699` Star prices): register/update the campaign in `content/promos.json` and schedule time-windowed posts (`publish_from`, `publish_until`, `priority`, `max_sends`, `promo_slug`), generating photorealistic seasonal Russian winter/landscape visuals when appropriate.
3. Read `05_Content/accounts/titan_proxy/channels/articles/LEDGER.md` to find newly published `live` articles not yet promoted in `channels/telegram/LEDGER.md`.
4. Select 1–2 evergreen selling topics and/or 1–2 article-bridge topics for the current batch. Never duplicate keys or `source_article` entries already in `channels/telegram/LEDGER.md`.

## Phase 2: Live Research (Scout — Optional)
- **Skip on routine batches** when objections are already known from `/support`, `backlog.md`, or an article from `channels/articles/LEDGER.md`.
- **Run only for genuinely new external topics** (e.g., changes to Telegram Stars payment options in Russia):
  ```bash
  grok -p "Найди реальные формулировки вопросов русскоязычных пользователей Telegram по теме: [Тема]. Выдели 3 практических сомнения без выдуманных цифр."
  ```

## Phase 3: Drafting (Writer)
1. Load `05_Content/accounts/titan_proxy/account.md`, `brand.md`, `voice/business_ru.md`, and `channels/telegram/drafting_contract.md`.
2. Draft new JSON post object(s) in `business_ru` (`Titan`) voice:
   - Unique `key` (`ch_14`+, or `art_<short_slug>`), `role: "rotational"`, `enabled: true`.
   - `start_param`: `ch_<key>` or `article_<article_slug>`.
   - **Length & Format:** For all standard rotational posts, write **120–260 plain-text chars** (`2–3` short lines, max 2 micro-paragraphs, opening bold hook `<= 55` chars so it fits Telegram's chat-list preview; up to **290 chars** only if the call-limitation footer is required). Reserve **300–600 chars** exclusively for `role: "pin"` or reference rubrics (`offer_reference`, `stars_guide`).
   - Telegram HTML (`<b>`, `<i>`, `<code>`, `<a href="...">` only; do not wrap `@usernames` in `<code>`).
   - Zero `!`, zero Stealth Protocol stop-words (including `необходимость`), zero protocol acronyms (`MTProto`, `TCP BBR`, `HTTPS`, `XTR`), zero `пользователь`/`кружочки`/`чел.`, zero `устройств` for server capacity (use `мест`: `До 50 мест`, `До 7 мест`), zero hardcoded Star prices.
   - Include `Важно: аудио- и видеозвонки не поддерживаются.` on `pin`, `offer_reference`, `offer`, `transparency`, `trial_to_paid`, and any post mentioning calls or tariffs (`drafting_contract.md` § 5); omit it from pure informational/article-bridge posts.

## Phase 4: Adversarial Verification (Critic & Gate)
1. Append the candidate post(s) to `/Users/titane0/Programming/titan-proxy-bot/content/posts.json`.
2. Run deterministic gate:
   ```bash
   bash /Users/titane0/Programming/titan-proxy-bot/.vault_link/05_Content/accounts/titan_proxy/channels/telegram/bin/gate_telegram.sh /Users/titane0/Programming/titan-proxy-bot/content/posts.json
   ```
   If the gate fails, fix immediately and re-run until `GATE PASS`.
3. Submit candidate post(s) to Critic against `channels/telegram/rubric.md` via `agy -p`:
   ```bash
   agy -p "Оцени новые посты в content/posts.json против .vault_link/05_Content/accounts/titan_proxy/channels/telegram/rubric.md. Вынеси вердикт SHIP или FIX со списком дефектов."
   ```
   If Critic returns `FIX`, revise and re-run `gate_telegram.sh`.

## Phase 5: Production & Ledger Sync
1. Record new entries in `05_Content/accounts/titan_proxy/channels/telegram/LEDGER.md` with status `ready`.
2. Commit and push in `/Users/titane0/Programming/titan-proxy-bot`:
   ```bash
   git add content/posts.json
   git commit -m "content(telegram): add posts <keys>"
   git push origin main
   ```

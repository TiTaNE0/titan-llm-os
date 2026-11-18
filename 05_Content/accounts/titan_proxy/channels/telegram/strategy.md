---
account: "[[accounts/titan_proxy/account]]"
type: channel_strategy
channel: telegram
status: active
created: 2026-11-18
---

# Titan Proxy — Telegram Channel Strategy (`@TitanMTProxyNews`)

## 1. Mission & Scope
The Telegram channel (`https://t.me/TitanMTProxyNews`) serves as the read-only warm-up showcase and proxy sponsor surface for `@TitanTGProxy_bot`. Every visitor who connects a temporary trial link from `titanproxy.tech`, `bestproxy.deals`, or `mtproxy.guru` sees `@TitanMTProxyNews` pinned in Telegram; the channel also distributes weekly SEO articles from `[[channels/articles/LEDGER]]` and converts readers into 30-day Telegram Stars subscriptions.

- **Single Public Voice:** `[[voice/business_ru]]` (`Titan`, `business_ru`). Never mix `terminal_ru` or `family_ru` markers into public channel posts.
- **Read-Only Format:** No open user comments. Social proof via limited reactions and anonymous polls; all support goes to `/support` inside `@TitanTGProxy_bot`.
- **Target Feed File:** `/Users/titane0/Programming/titan-proxy-bot/content/posts.json` (read by `titan-proxy-bot` on the VPS).

## 2. Publication Cadence
- **Channel Posting (Bot on VPS):** `5/7` (Mon–Fri) default schedule in `Europe/Moscow`, max 3 sound notifications (`silent: false`) per week, quiet hours `22:00–09:00` MSK.
- **Content Generation (Automation):** Weekly batch of 2–3 new posts added to `content/posts.json`:
  - **1–2 article-bridge posts** summarizing newly published `live` entries from `[[channels/articles/LEDGER]]` with `?start=article_<slug>` attribution and article URL.
  - **1–2 evergreen / FAQ / scenario posts** from `[[channels/telegram/backlog]]` with `?start=ch_<key>`.

## 3. Structural Conventions
1. **Two-Tier Ultra-Short Length Discipline:**
   - **Standard feed posts (default):** `120–260` plain-text chars (`2–3` short lines, max 2 micro-paragraphs, up to `290` chars only when carrying the call disclosure). Vary format across posts instead of repeating multi-bullet boilerplate.
   - **Pin & Reference posts (exceptions only):** `300–600` plain-text chars (single mobile screen, no scrolling), strictly reserved for `role == "pin"` (`ch_pin`) and reference guides (`offer_reference` for tier overview, `stars_guide` for Stars payment instructions).
2. **Hook (1 line bold, `<= 55` chars):** Fits intact inside Telegram's chat-list preview.
3. **Selective Limitation Disclosure:** Include `Важно: аудио- и видеозвонки не поддерживаются.` on `ch_pin`, tariff/offer/trial-to-paid/limitation posts, and any post mentioning calls or tariffs (aligned with `[[channels/articles/drafting_contract]]` § 4); omit it from pure informational/article-bridge posts to prevent visual fatigue.
4. **Pricing Rule:** Never hardcode Star prices in channel copy (`account.md`); link readers to `@TitanTGProxy_bot`.
5. **Single CTA Button:** `https://t.me/TitanTGProxy_bot?start=<start_param>` (`ch_*` or `article_*`).
6. **Optional Scout Research:** Do not run `grok -p` on routine batches — pull topics from `[[channels/articles/LEDGER]]`, `[[channels/telegram/backlog]]`, and real `/support` / `funnel_events` feedback; invoke `grok -p` only when investigating new external objections.

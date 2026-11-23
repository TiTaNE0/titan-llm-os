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
- **Channel Posting (Bot on VPS):** `7/7` (Mon–Sun) daily schedule in `Europe/Moscow` (quiet background value 80–90%, max 3 sound notifications `silent: false` per week, quiet hours `22:00–09:00` MSK, `IMAGE_COOLDOWN = 18h` bypassed for `priority >= 10`).
- **Immediate Breaking News (`news_brief`):** Outage digests and urgent news (`rubric: "news_brief"`, `priority >= 10`, `max_sends: 1`, valid `publish_from`/`publish_until`) publish immediately on the next daytime tick (`09:00–22:00` MSK) independent of the daily slot (allowing up to 2 posts on news days).
- **Content Generation (Autonomous Calendar + Evergreen Batches, 4:1 Value-to-Offer Ratio):**
  - Check `[[channels/telegram/calendar.yaml]]` on every run (`human_approval_required: false`). Any `planned` event within its `lead_days` window is autonomously promoted by the Agent Council (`strategist` + `tech_fact_critic` + `growth_calendar_critic` + `gate_telegram.sh`) within `promo_guardrails` (`bonus_days` 5..14, `price_changes_allowed: false`, max 20 days window), wired into `content/promos.json` + time-windowed `content/posts.json` entries (`publish_from`/`publish_until`, `priority`, `max_sends`).
  - Evergreen batches add **5–7 new posts/week** to keep `7/7` fresh without repetition fatigue: `1–2` article-bridge summaries from `[[channels/articles/LEDGER]]` + `3–5` value/selling/scenario/Q&A/micro-tip/weekend-checklist topics (targeting ~80% practical utility/status vs ~20% direct tier offers).
  - **Selling Angles (Zero Hype):** Frame real workflow stakes (guest test vs daily work, peak-hour file delivery, honest plain-language technical limits, `/gift` separate access for relatives/colleagues) rather than dry technical notes.

## 3. Structural Conventions
1. **Two-Tier Ultra-Short Length Discipline:**
   - **Standard feed posts (default):** `120–260` plain-text chars (`2–3` short lines, max 2 micro-paragraphs, up to `290` chars only when carrying the call disclosure). Vary format across posts instead of repeating multi-bullet boilerplate.
   - **Pin & Reference posts (exceptions only):** `300–600` plain-text chars (single mobile screen, no scrolling), strictly reserved for `role == "pin"` (`ch_pin`) and reference guides (`offer_reference` for tier overview, `stars_guide` for Stars payment instructions).
2. **Hook (1 line bold, `<= 55` chars):** Fits intact inside Telegram's chat-list preview.
3. **Selective Limitation Disclosure:** Include `Важно: аудио- и видеозвонки не поддерживаются.` on `ch_pin`, tariff/offer/promo/trial-to-paid/limitation posts, and any post mentioning calls or tariffs (aligned with `[[channels/articles/drafting_contract]]` § 4); omit it from pure informational/article-bridge/holiday-greeting posts to prevent visual fatigue.
4. **Pricing & Promo Rule:** Never hardcode Star prices in channel copy (`account.md`); link readers to `@TitanTGProxy_bot`. Promo bonuses use extra subscription days (`+7`/`+10`/`+14` days via `content/promos.json`) or `/gift` access, never discounted Star invoices.
5. **Time Windows & Exact-Day Holidays:** `promo` and `holiday` posts MUST set `publish_from` and `publish_until` (`YYYY-MM-DD`), `priority` (`>= 10` for promos, `>= 20` for exact-day holiday greetings so weekend 11:00 MSK greeting slots fire automatically), and `max_sends: 1`.
6. **Single CTA Button:** `https://t.me/TitanTGProxy_bot?start=<start_param>` (`ch_*`, `ch_gift_*`, or `article_*`).
7. **Optional Scout Research:** Do not run `grok -p` on routine batches — pull topics from `[[channels/telegram/calendar.yaml]]`, `[[channels/articles/LEDGER]]`, `[[channels/telegram/backlog]]`, and real `/support` / `funnel_events` feedback; invoke `grok -p` only when investigating new external objections.

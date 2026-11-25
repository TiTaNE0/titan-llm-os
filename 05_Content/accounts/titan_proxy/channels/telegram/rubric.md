---
type: channel_rubric
channel: telegram
account: titan_proxy
status: active
created: 2026-11-18
---

# Critic Rubric — Titan Proxy Telegram Channel Posts

Used by the Critic (Gemini via `agy -p`) to evaluate candidate posts before updating `content/posts.json`.

## Evaluation Criteria (Pass/Fail)

1. **Register Purity (`business_ru` / `Titan`):**
   - Calm, executive Apple-style clarity. No DevOps acronyms (`MTProto`, `TCP BBR`, `RTT`, `XTR`, `HTTPS`), no family slang (`кружочки`), no `пользователь`.
2. **Zero Hype & Zero Triggers:**
   - Zero exclamation marks (`!`). Zero Stealth Protocol triggers (`обход`, `блокировк`, `dpi`, `ркн`, etc.).
3. **Factual Sobriety & Pricing Policy:**
   - No invented stats, uptime SLAs, latency numbers, city names, or provider names.
   - No hardcoded Star prices (`139`, `329`, `699`) in channel copy; prices live in `@TitanTGProxy_bot`.
   - Tier capacity uses server seat-density phrasing (`До 50 мест`, `До 7 мест`, `Личный выделенный сервер`), never `устройств` for server capacity and never `чел.`.
   - Stars top-up guidance names official paths only in preferred order: `@PremiumBot`, `fragment.com`, then in-app purchase (with App Store / Google Play commission).
4. **Technical Truth Gate (Mandatory Binary Check):**
   - When translating engineering terms into plain Russian (`протокол передачи текста и медиа`, `отдельный потоковый канал для звонков`), the text MUST stay technically accurate.
   - Zero invented causality or euphemisms (`мощность серверов отдана`, `ресурс узлов направлен`, `глубокой маскировки`, `голос не маршрутизируется`).
   - Any promo bonus days (`+7` / `+10` / `+14`) MUST match an active `content/promos.json` campaign and valid `publish_from`/`publish_until` window.
5. **Limitation Honesty:**
   - Audio/video call non-support (`Важно: аудио- и видеозвонки не поддерживаются.`) is present on `ch_pin`, tariff/offer/promo/trial-to-paid/limitation posts, and any post mentioning calls/tariffs, with zero roadmap promises. Pure informational/article-bridge/Stars-guide/holiday-greeting posts omit the footer to avoid banner blindness.
6. **Channel Fit, Selling Value, Ultra-Brevity & CTA Clarity:**
   - Selling posts frame concrete workflow stakes (guest test vs daily work, peak-hour stability, gift access `/gift`) without hype.
   - Standard feed posts scan in 2–3 seconds without scrolling: **`120–260` plain-text chars** (up to **`290`** only when carrying the call-limitation footer), 2–3 short lines, max 2 micro-paragraphs.
   - Opening bold hook fits Telegram's chat-list preview (**`<= 55` chars**).
   - Pin and reference guides (`ch_pin`, `offer_reference`, `stars_guide`) fit on ONE mobile screen: **`300–600` plain-text chars** (compact 1-line steps/tiers, no multi-sentence boilerplate).
   - Balanced HTML (`@usernames` kept clickable without `<code>`), clean CTA matching `start_param`.
   - Seasonal/holiday visuals use photorealistic Russian winter/seasonal landscapes or Sapphire Dark scenes with zero text/logos/flags/landmarks.
7. **`news_brief` Topical Relevance & Materiality (Binary Veto):**
   - **Allowlist match (last 24h, verified publication date):** Active `news_brief` MUST cover either (a) a corroborated Russia connectivity/Telegram media-delivery degradation (`>= 2` independent sources, above baseline noise) or (b) a stable-release change affecting Telegram connection/proxy stability or Telegram Stars / `@PremiumBot` / `fragment.com` billing.
   - **Zero hard-exclusion hits:** Reject any beta build (`Android Beta`, `iOS Beta`, `13.3.2` beta), unrelated UI/consumer feature (subtitles, `.pkpass`, dictation, stickers, stories, AI agents, profiles), or routine evergreen tip.
   - **Anti-Forced-Segue Test:** Headline and body **outside `<blockquote>`** stand on connectivity/Stars relevance by themselves without relying on a `<blockquote>` bridge to `@TitanTGProxy_bot`.
   - **Materiality & priority match:** Out-of-slot urgency (`priority >= 10`, `max_sends: 1`) is reserved strictly for active widespread outages or urgent Stars payment disruptions; default when uncertain is **NO-OP** (do not publish).

## Verdicts
- **SHIP:** All criteria met. Ready for `bin/gate_telegram.sh`, `pytest`, and autonomous deploy.
- **FIX:** Concrete list of line/post defects to revise before re-gating.

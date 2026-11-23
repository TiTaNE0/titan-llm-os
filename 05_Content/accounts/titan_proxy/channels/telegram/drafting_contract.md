---
account: "[[accounts/titan_proxy/account]]"
type: drafting_contract
channel: telegram
status: active
created: 2026-11-18
---

# Titan Proxy — Telegram Channel Drafting Contract

> Non-negotiable gates and invariants for all Telegram channel posts in `content/posts.json`. Every post must pass `bin/gate_telegram.sh` before commit/push.

## 1. Zero Exclamation Marks (`brand.md`)
- An exclamation mark (`!`) is prohibited anywhere in `html` or `cta_text`.

## 2. Regulatory Trigger Blocklist (Stealth Protocol)
The following substrings (case-insensitive) are prohibited:
- `faketls`
- `dpi`
- `тспу`
- `обход` *(includes `необходимость`!)*
- `блокировк`
- `цензур`
- `разблокировк`
- `анонимайзер`
- `ркн`

## 3. Infrastructure & Location Transparency
- Never name specific cities, countries, or hosting providers (`frankfurt`, `helsinki`, `amsterdam`, `германи`, `финлянди`, `нидерланд`, `hetzner`, `ovh`, `digitalocean`).
- Allowed canonical reference: `Надёжные серверы в Европе` or `магистральные узлы в Европе`.

## 4. `business_ru` Voice & Brand Prohibitions
- **Single voice:** Public channel posts MUST stay in `[[voice/business_ru]]` (`Titan`).
- **Banned words in channel copy:**
  - `VPN`, `туннель` (`brand.md`)
  - `MTProto`, `TCP BBR`, `BBR`, `RTT`, `XTR`, `HTTPS` (protocol names/acronyms are Variant A DevOps-only per `brand.md` and `voice/business_ru.md`)
  - `пользователь` (any case/inflection — per `voice/business_ru.md`, use `вы` or `ваша команда`)
  - `кружочки` (belongs to `family_ru` register; use `видео`, `медиафайлы`, `сообщения`)
  - `best`, `fastest`, `world-class`, `unbreakable`, `guaranteed`, `powered by AI`, `revolutionary`, `next-gen`, `unleash`
  - Unverified `[TODO]` markers or invented latency/uptime percentages (`99.9%`, `<20мс`)
- **Plain-Language Technical Truth (`brand.md`):**
  - Instead of engineering acronyms (`MTProto`, `TCP`, `UDP`), use plain-Russian mechanism phrases: `протокол передачи текста и медиа` / `протокол передачи текста, фото и файлов` and `отдельный потоковый канал для звонков` / `протокол передачи потоковых данных`.
  - **Zero invented causality:** Never claim «мощность серверов отдана», «ресурс узлов направлен», «глубокая маскировка» (as a cause for call limits), or «голос не маршрутизируется». Every technical limitation must follow the `brand.md` Technical Truth Translation Table.
- **Terminology consistency:** Use server seat-density phrasing `мест` (`До 50 мест` / `До 50 мест на сервере`, `До 7 мест` / `До 7 мест на сервере`, `Личный выделенный сервер`) — never `устройств` for server capacity and never `чел.`. (Personal multi-device usage on one subscriber's own devices is separate from server seat density.) For gifting access to relatives/colleagues without sharing a personal link, direct readers to `/gift` (`start_param: "ch_gift_..."`).

## 5. Limitation, Calendar Promos & Pricing Integrity
- **Selective mandatory disclosure (`HARD_LIMITATION`):** Aligned with `[[channels/articles/drafting_contract]]` § 4, to prevent banner blindness in short sponsor-channel posts, `Важно: аудио- и видеозвонки не поддерживаются.` (or `звонки внутри мессенджера недоступны`) is **REQUIRED** on:
  - the pinned showcase post (`role == "pin"`),
  - tariff, offer, trial-to-paid, promo, and limitation rubrics (`onboarding`, `offer_reference`, `offer`, `promo`, `transparency`, `trial_to_paid`), and
  - any post mentioning calls, audio, video calls, tariffs, or tier names (`звонк`, `аудио`, `тариф`, `Basic`, `Family`, `Premium`).
  - Omit the 46-char footer from pure utility, architecture, Stars-guide, retention, security, FAQ, holiday greeting, gift-info (without tier names), and article-bridge posts that do not pitch tariffs or discuss calls. Never promise future call support.
- **No hardcoded Star prices (`account.md`):** Do not put `139`, `329`, or `699` in channel post `html` or `cta_text`. Direct readers to `@TitanTGProxy_bot`.
- **Calendar Promos & Guardrails (`calendar.yaml` + `content/promos.json`):**
  - All `promo` and `holiday` posts MUST specify `publish_from` and `publish_until` (`YYYY-MM-DD` or ISO datetime), `priority` (`>= 10` for promos, `>= 20` for exact-day holiday greetings), and `max_sends` (typically `1`).
  - Never promise bonus days (`+7` / `+10` / `+14 дней`) without a matching active campaign in `content/promos.json` (`enabled: true`, `1 <= bonus_days <= 14`, overlapping date window, matching `promo_slug`). Star sticker prices (`139 / 329 / 699`) never change.
- **Official Stars channels only (preferred order):** List `@PremiumBot` (no store markup), `fragment.com` (TON), and then built-in in-app purchase via App Store / Google Play (explicitly noting store commission) — never third-party exchangers.

## 6. JSON Post Schema & Telegram HTML Constraints
- `key`: unique `^[a-z0-9_]{3,32}$`
- `role`: `"pin"` or `"rotational"`
- `rubric`: non-empty category string (`utility`, `architecture`, `offer_reference`, `stars_guide`, `transparency`, `retention`, `scenario`, `security`, `offer`, `faq`, `trial_to_paid`, `article_bridge`, `news_brief`, `promo`, `holiday`, `gift`)
- `silent`: boolean (`true` | `false`)
- `enabled`: boolean (`true` | `false`)
- `cta_text`: non-empty string (`<= 64` chars, no `!`)
- `start_param`: `^[a-zA-Z0-9_-]{1,64}$` (e.g., `ch_13`, `article_tg-proxy-link-structure`, `ch_gift_ny27`)
- `html`: valid Telegram HTML (`<b>`, `<i>`, `<code>`, `<a href="...">`, `<blockquote>` only; do not wrap `@usernames` in `<code>` so links remain tappable; balanced tags).
- `image` *(optional)*: relative asset path under `content/` (e.g., `media/titan_pin_cover.jpg`; extension `.png`/`.jpg`/`.jpeg`/`.webp`, no `..`, file must exist, and plain-text caption length `<= 1024`).
- `publish_from`, `publish_until` *(optional; REQUIRED for `promo`, `holiday`, and active `news_brief`)*: `YYYY-MM-DD` or ISO datetime; `publish_from <= publish_until`.
- `priority` *(optional, integer, default `0`)*: `>= 10` for active promo windows and urgent `news_brief` (bypasses `IMAGE_COOLDOWN = 18h`; `news_brief` with `priority >= 10` and `max_sends: 1` publishes immediately in daytime `09:00–22:00` MSK), `>= 20` for exact-day holiday greetings (also enables weekend 11:00 MSK greeting slots when `max_sends == 1`).
- `max_sends` *(optional, integer `>= 1`)*: caps total deliveries of a one-shot announcement or greeting.
- `promo_slug` *(optional, `^[a-z0-9_-]{2,32}$`)*: binds the post to a live entry in `content/promos.json`.
- **Media visual policy (`Sapphire Dark` + Seasonal Russian Winter Landscapes):**
  - Generate **thematic photorealistic 16:9 editorial scenes** matching the post topic: Sapphire Dark (`#0A0E17`–`#1E293B` + `#007AFF`/`#00C6FF`) workspace/datacenter scenes for evergreen & Black Friday posts, and **photorealistic snowy Russian winter landscapes** (snowy birch/pine forests, quiet snow-covered lanes, twilight frost, distant warm house window) for New Year and winter holiday posts. Never generate abstract floating glass/shapes, text, letters, logos, country flags, or recognizable cities/landmarks.
  - Render infographics containing Cyrillic text (tier comparisons, Stars steps) exclusively via HTML/SVG → PNG templates.
- **Selling Formats (`business_ru` conversion rhythms):**
  - Rotate across selling & informational angles: Contrast «Тест vs Работа», «Выбор по нагрузке», «Честная граница без оправданий», «Подарочный доступ `/gift`», «Праздничное поздравление», FAQ + `<code>`, Steps.
- **Visual typography discipline (`business_ru` dark-mode):**
  - Restraint: max `1–3` cold dark-mode markers per post (`🛡`, `⚡`, `🔹`, `▫️`, `⭐️`) plus clean dividers `—`, `→`, `·`. Never stack emojis on every line.
  - Use `<blockquote>...</blockquote>` selectively for the key takeaway or `HARD_LIMITATION` + commands (`<code>/start</code> · <code>/myproxy</code> · <code>/gift</code> · <code>/support</code>`).
  - Alternate across feed rhythms so consecutive posts never look identical.
- **Hook preview limit:** Keep the opening bold hook `<= 55` chars so it fits intact in Telegram's chat-list preview without mid-word truncation.
- **Two-tier plain-text length bounds (ultra-short Telegram feed discipline):**
  - **Standard rotational posts (`role == "rotational"` and `rubric` not in `{"onboarding", "offer_reference", "stars_guide"}`):** **`120–260` plain-text chars** (`2–3` short lines, max 2 micro-paragraphs, `18–38` words), or up to **`290` chars** (`120–290`) ONLY when carrying the mandatory `HARD_LIMITATION` disclosure.
  - **Pin & Reference posts (`role == "pin"` or `rubric` in `{"onboarding", "offer_reference", "stars_guide"}`):** **`300–600` plain-text chars** (`50–85` words, compact single-screen mobile card with zero scrolling).

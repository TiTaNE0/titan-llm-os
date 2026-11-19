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
- **Terminology consistency:** Use server seat-density phrasing `мест` (`До 50 мест` / `До 50 мест на сервере`, `До 7 мест` / `До 7 мест на сервере`, `Личный выделенный сервер`) — never `устройств` for server capacity and never `чел.`. (Personal multi-device usage on one subscriber's own devices is separate from server seat density.)

## 5. Limitation & Pricing Integrity
- **Selective mandatory disclosure (`HARD_LIMITATION`):** Aligned with `[[channels/articles/drafting_contract]]` § 4, to prevent banner blindness in short sponsor-channel posts, `Важно: аудио- и видеозвонки не поддерживаются.` (or `звонки внутри мессенджера недоступны`) is **REQUIRED** on:
  - the pinned showcase post (`role == "pin"`),
  - tariff, offer, trial-to-paid, and limitation rubrics (`onboarding`, `offer_reference`, `offer`, `transparency`, `trial_to_paid`), and
  - any post mentioning calls, audio, video calls, tariffs, or tier names (`звонк`, `аудио`, `тариф`, `Basic`, `Family`, `Premium`).
  - Omit the 46-char footer from pure utility, architecture, Stars-guide, retention, security, FAQ, and article-bridge posts that do not pitch tariffs or discuss calls. Never promise future call support.
- **No hardcoded Star prices (`account.md`):** Do not put `139`, `329`, or `699` in channel post `html` or `cta_text`. Direct readers to `@TitanTGProxy_bot`.
- **Official Stars channels only (preferred order):** List `@PremiumBot` (no store markup), `fragment.com` (TON), and then built-in in-app purchase via App Store / Google Play (explicitly noting store commission) — never third-party exchangers.

## 6. JSON Post Schema & Telegram HTML Constraints
- `key`: unique `^[a-z0-9_]{3,32}$`
- `role`: `"pin"` or `"rotational"`
- `rubric`: non-empty category string
- `silent`: boolean (`true` | `false`)
- `enabled`: boolean (`true` | `false`)
- `cta_text`: non-empty string (`<= 64` chars, no `!`)
- `start_param`: `^[a-zA-Z0-9_-]{1,64}$` (e.g., `ch_13`, `article_tg-proxy-link-structure`)
- `html`: valid Telegram HTML (`<b>`, `<i>`, `<code>`, `<a href="...">`, `<blockquote>` only; do not wrap `@usernames` in `<code>` so links remain tappable; balanced tags).
- `image` *(optional)*: relative asset path under `content/` (e.g., `media/titan_pin_cover.jpg`; extension `.png`/`.jpg`/`.jpeg`/`.webp`, no `..`, file must exist, and plain-text caption length `<= 1024`).
- **Media visual policy (`Sapphire Dark`):**
  - Generate **thematic photorealistic 16:9 editorial scenes** matching the concrete post topic (overcast European data center aerial, dark server hall corridor, overcast telecom mast, workspace with phone/laptop) graded in cool obsidian/slate (`#0A0E17`–`#1E293B`) with subtle sapphire accents (`#007AFF`/`#00C6FF`). Never generate abstract floating glass/shapes, text, letters, logos, country flags, or recognizable cities/landmarks.
  - Render infographics containing Cyrillic text (tier comparisons, Stars steps) exclusively via HTML/SVG → PNG templates.
- **Visual typography discipline (`business_ru` dark-mode):**
  - Restraint: max `1–3` cold dark-mode markers per post (`🛡`, `⚡`, `🔹`, `▫️`, `⭐️`) plus clean dividers `—`, `→`, `·`. Never stack emojis on every line.
  - Use `<blockquote>...</blockquote>` selectively for the key takeaway or `HARD_LIMITATION` + commands (`<code>/start</code> · <code>/myproxy</code> · <code>/support</code>`).
  - Alternate across the 5 feed rhythms (Thesis + Callout, Contrast `🔹`/`▫️`, Tier Mini-Card, FAQ + `<code>`, Navigation Pin / Steps) so consecutive posts never look identical.
- **Hook preview limit:** Keep the opening bold hook `<= 55` chars so it fits intact in Telegram's chat-list preview without mid-word truncation.
- **Two-tier plain-text length bounds (ultra-short Telegram feed discipline):**
  - **Standard rotational posts (`role == "rotational"` and `rubric` not in `{"onboarding", "offer_reference", "stars_guide"}`):** **`120–260` plain-text chars** (`2–3` short lines, max 2 micro-paragraphs, `18–38` words), or up to **`290` chars** (`120–290`) ONLY when carrying the mandatory `HARD_LIMITATION` disclosure.
  - **Pin & Reference posts (`role == "pin"` or `rubric` in `{"onboarding", "offer_reference", "stars_guide"}`):** **`300–600` plain-text chars** (`50–85` words, compact single-screen mobile card with zero scrolling).

---
slug: ru_family
account: "[[accounts/titan_proxy/account]]"
variant_key: c
design: "[[design/ember]]"
voice: "[[voice/family_ru]]"
landing: "[[channels/landing/ru_family]]"
language: ru
locale: ru_RU
domain: mtproxy.guru
status: active
---

# Persona — RU Family (Variant C)

## Who

Russian-speaking adult (often 40+, often a parent or grandparent) who uses Telegram to stay in touch with family — photos of grandchildren, video circles ("кружочки") from kids, voice messages from elderly relatives. Non-technical. Doesn't know what "proxy" means and doesn't want to. Their pain is simple: photos take forever to open, video circles buffer, sometimes the messenger just stops working.

## What they want from this page

Reassurance, in plain warm Russian, that:
- Photos and video circles will open quickly again
- It works inside Telegram — no new apps, no settings on the phone
- The phone won't get hot or run out of battery
- Payment is safe (Telegram Stars / Звёзды)
- They don't need to do anything technical

## Why they convert

The page feels like a soft brochure, not a tech product. They trust it because:
- Cream + amber palette is warm and approachable — no scary tech aesthetic
- 36px rounding makes every card look like a friendly tile
- Copy uses their actual vocabulary ("кружочки", "близкие", "звёзды") not engineering terms
- Hard limitation is stated plainly ("Аудио- и видеозвонки не поддерживаются") in the same warm voice — no fine print

## Design + voice binding

- Visual: [[design/ember]] — cream/amber, 36px rounding, warm halo glow, Manrope
- Voice: [[voice/family_ru]] — warm everyday Russian, no jargon, "кружочки" not "видеосообщения" when possible
- Layout: `data-variant="c"`, `data-theme="dark"` default (but light is the canonical register)

## SEO + metadata (mirrors `src/app/c/page.tsx`)

- Domain: `mtproxy.guru`
- Title: `Titan Proxy | Спокойный Telegram для семьи — Быстрая загрузка фото и видео`
- Description: `Простое решение для семейного Telegram. Фото загружаются мгновенно, видеосообщения без задержек. Никаких технических знаний не требуется.`
- Keywords: `Telegram slow, fix photo loading, family chat, video messages, simple Telegram fix`
- OG title: `Titan | Спокойный и быстрый Telegram для семьи`
- OG image: `https://mtproxy.guru/og-image-c.png?v=3`
- Canonical: `https://mtproxy.guru/`

## Channel outputs

- Landing copy: [[channels/landing/ru_family]] → drives `COPY_C`, `FAQ_C`, `STATUS_BADGE_C` in `src/data/copy.ts`
- Video pipeline (future): cream/amber palette, golden-hour family footage, warm halo on title cards
- Social pipeline (future): warm photo posts with amber accent and Manrope body

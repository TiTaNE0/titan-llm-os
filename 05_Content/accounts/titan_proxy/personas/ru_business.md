---
slug: ru_business
account: "[[accounts/titan_proxy/account]]"
variant_key: b
design: "[[design/sapphire]]"
voice: "[[voice/business_ru]]"
landing: "[[channels/landing/ru_business]]"
language: ru
locale: ru_RU
domain: mtproxy.link
status: active
---

# Persona — RU Business (Variant B)

## Who

Russian-speaking working professional: remote team lead, freelance consultant, executive who lives in messengers. Manages communication continuity for distributed colleagues. Spends meaningful work hours in Telegram (chats, channels, file exchange). Sees messenger slowdowns as work-time loss, not a hobby issue.

## What they want from this page

A premium, calm assurance that the messenger they rely on for work will keep working:
- Continuity during peak hours and ISP shaping
- Confidence the traffic looks like ordinary HTTPS (no flagging concerns)
- "Just works" framing — no toggles, no extra apps
- Transparent payment via Telegram Stars (not a sketchy gateway)
- Acknowledgement that calls aren't routed (they probably use a different tool for calls anyway)

## Why they convert

The page feels like a corporate communications product — Apple-keynote register, not a developer tool. They trust it because:
- Sapphire midnight aesthetic + Apple-blue gradients read as premium hardware
- Rounded glass cards feel like a finished consumer product
- AuroraText accent on the hero headline reads as polished, not gimmicky
- Copy talks about "ваша работа" / "ваша команда" without selling

## Design + voice binding

- Visual: [[design/sapphire]] — midnight blue, Apple gradient, 28px rounding, ambient bokeh
- Voice: [[voice/business_ru]] — sentence-cap professional, no jargon
- Layout: `data-variant="b"`, `data-theme="dark"` default

## SEO + metadata (mirrors `src/app/b/page.tsx`)

- Domain: `mtproxy.link`
- Title: `Titan Proxy | Бизнес-платформа для надёжного Telegram — Непрерывность и безопасность`
- Description: `Корпоративная сеть для защиты коммуникаций команды. Постоянная доступность, шифрование, без простоев. Для бизнеса и удалённых команд.`
- Keywords: `business continuity, enterprise Telegram, team security, workflow stability, remote work, business communication`
- OG title: `Titan | Непрерывная связь в Telegram для бизнеса`
- OG image: `https://mtproxy.link/og-image-b.png?v=3`
- Canonical: `https://mtproxy.link/`

## Channel outputs

- Landing copy: [[channels/landing/ru_business]] → drives `COPY_B`, `FAQ_B`, `STATUS_BADGE_B` in `src/data/copy.ts`
- Video pipeline (future): same sapphire palette, calm pan footage, AuroraText accent on title cards
- Social pipeline (future): premium product cards with `#007aff → #00c6ff` gradient

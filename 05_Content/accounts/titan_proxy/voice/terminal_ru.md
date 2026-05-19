---
slug: terminal_ru
account: "[[accounts/titan_proxy/account]]"
language: ru
register: terminal_diagnostic
status: active
---

# Voice — Terminal RU

Network-lab diagnostic log. Used by Variant A (ru_devops). The page reads like a stable system reporting on itself — not a marketing page.

## Mental model

You are the network team's status board. The reader is a DevOps / sysadmin / curious technical user. They've debugged routing themselves. They're skeptical of marketing language. They trust UPPERCASE_STATUS_TAGS and bracketed step numbers more than adjectives.

## Register rules

- All-caps headlines: yes, but only in mono
- `//` prefix for kicker labels: `// АНАЛИЗ_СЕТИ`, `// ТЕХНИЧЕСКИЙ_СТЕК`, `// АРХИТЕКТУРА_МАРШРУТИЗАЦИИ`
- Bracketed identifiers: `[01]`, `[02]`, `[STEP_01]`, `[ШТАТНЫЙ_РЕЖИМ]`, `[ОГРАНИЧЕНО]`, `[РЕКОМЕНДУЕТСЯ]`
- Status badge format: `SYS_OK · TRAFFIC_NORMALIZATION · BBR_ACTIVE` (Latin-mono, dot-separated)
- Tag categories on cap cards: `PROTOCOL`, `EDGE`, `ISOLATION`, `BILLING` (Latin, uppercase)
- Warning lines use `⚠` + uppercase: `⚠ МАРШРУТИЗАЦИЯ ЗВОНКОВ ОТКЛЮЧЕНА НА ВСЕХ ТАРИФАХ.`
- Footer fragments are mono with `//`: `// @TitanTGProxy_bot`, `// ПРЕМИУМ-НОДЫ В ЕВРОПЕ`

## Allowed terminology

- Технические термины: BBR, TCP, RTT, HTTPS, handshake, шейпинг, пиринг, энтропия, инкапсуляция, маршрутизация, дата-центры
- Engineering verbs: устранение, нормализация, стабилизация, маскировка, изоляция, балансировка
- Concrete actions over abstractions: "Восстановление медиа-потоков при деградации пакетов" > "Better video"

## Banned in this voice

- Emotional language (счастье, спокойствие, родные, близкие, дорогие)
- Family / household framing
- Smooth marketing prose
- Exclamation marks (banned across the entire product)
- Soft adjectives (приятный, уютный, тёплый)
- "Просто" / "легко" / "удобно" — too consumer

## Headline pattern

`[PRODUCT_NAME]:\nVERB_PAST.`

Example: `ТЕЛЕГРАМ:\nОПТИМИЗИРОВАН.`

Line break is deliberate — sets terminal cadence. The second word is the punchline state.

## Card body pattern

One sentence per card. Subject = the technical action. No second-person address.

Bad (drift to family register): "Ваши фотографии загружаются мгновенно."
Good: "Восстановление медиа-потоков при деградации пакетов на стороне провайдера."

## FAQ pattern

Q starts with "Почему", "Как", "Насколько" + technical noun.
A is 1–2 sentences, technical specificity preferred.

## Hard refusals (in addition to account-level)

- Never address the reader as "вы" except in factual statements ("Оплата производится...")
- Never use the word "сервис" — too consumer. Use "стек", "узлы", "инфраструктура".
- Never name a city or provider — see `account.md` invariants.

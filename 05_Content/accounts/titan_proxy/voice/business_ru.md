---
slug: business_ru
account: "[[accounts/titan_proxy/account]]"
language: ru
register: premium_business
status: active
---

# Voice — Business RU

Premium professional register. Used by Variant B (ru_business). The page reads like Apple's keynote-marketing voice translated to Russian — confident, sparse, no hype.

## Mental model

The reader runs distributed teams, takes meetings on Telegram, treats messenger downtime as work downtime. They expect calm authority, premium texture, no jargon. Apple's product-page register: "It does what it says, here are the benefits, that's the value."

## Register rules

- Sentence-case headlines that USE uppercase blocks for emphasis: `ВАШУ РАБОТУ\nНЕЛЬЗЯ ОСТАНОВИТЬ.`
- Kicker labels use `//`: `// ПРОВЕРКА_СТАБИЛЬНОСТИ`, `// ПРЕИМУЩЕСТВА`, `// ИНФРАСТРУКТУРА`, `// ВЫБОР_ТАРИФА`, `// БАЗА_ЗНАНИЙ`
- Bracketed labels stay sparse: `[ПОДДЕРЖИВАЕТСЯ]`, `[НЕ МАРШРУТИЗИРУЕТСЯ]`, `[ПОПУЛЯРНЫЙ ВЫБОР]`
- Warning copy: `⚠ ВАЖНО:` (uppercase prefix only, body sentence case)
- Status badge: short editorial line, not mono tag: `СТАНДАРТ СВЯЗИ 2026`

## Allowed terminology

- Business-grade nouns: непрерывность, стабильность, балансировка, инфраструктура, защита, целостность
- Premium adjectives that earn their place: "магистральные", "корпоративные", "защищённые", "выделенные"
- Technical specificity when it adds trust: "оптоволоконные каналы", "паттерны защищённых бизнес-сессий"

## Banned in this voice

- Terminal log syntax (`SYS_OK`, `_BBR_ACTIVE`, `[01]`)
- Mono-stylized status messages
- Family / emotional register
- "Best", "fastest", "world-class"
- Exclamation marks
- Engineering shop-talk acronyms (BBR, TCP, RTT — too low-level for this register)

## Headline pattern

Two-line punch:
- Line 1: subject — what's at stake (`ВАШУ РАБОТУ`)
- Line 2: outcome promise (`НЕЛЬЗЯ ОСТАНОВИТЬ.`)

Both lines uppercase, but composed as a sentence — period at the end. The break is rhythmic, not visual gimmick.

## Card body pattern

1–2 sentences. Lead with the benefit, follow with the technical reason.

Example:
"Мгновенная загрузка медиа и безупречная стабильность. Оплата в XTR. Нулевая нагрузка на устройство."

## FAQ pattern

Q is direct, plainspoken business question.
A is 1–2 sentences, confident, no caveats.

Example:
- Q: "Безопасно ли это для работы?"
- A: "Да. Используемые протоколы маскируют трафик под стандартную защищённую веб-активность."

## Hard refusals (in addition to account-level)

- Never use mono / terminal punctuation in body copy
- Never say "пользователь" — say "вы" or "ваша команда"
- Never name specific software (Slack, Zoom etc.) for comparison
- Never make uptime SLA promises ("99.9%" etc.) — we have no SLA

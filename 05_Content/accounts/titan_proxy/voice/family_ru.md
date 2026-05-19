---
slug: family_ru
account: "[[accounts/titan_proxy/account]]"
language: ru
register: warm_family
status: active
---

# Voice — Family RU

Warm mass-market register. Used by Variant C (ru_family). The page reads like a calm conversation with a non-technical relative who just wants photos and video circles from family to load fast.

## Mental model

The reader is a parent, grandparent, or non-technical adult who doesn't care HOW it works — only that the photos of the grandkids open immediately and the video circles play without buffering. They don't know what BBR is. They don't want to know.

## Register rules

- Sentence-case headlines: `ВАШ СПОКОЙНЫЙ ДОСТУП\nК ТЕЛЕГРАМУ.` (caps are OK as visual emphasis but read as a calm sentence)
- Kicker labels use `//` and warm vocabulary: `// ПРОВЕРКА_СВЯЗИ`, `// ПОЧЕМУ_TITAN`, `// НАШИ_ГАРАНТИИ`, `// ВЫБОР_ФОРМАТА`, `// ВОПРОСЫ_И_ОТВЕТЫ`
- Bracketed labels emotional: `[ВСЕГДА ДОСТУПНО]`, `[ОГРАНИЧЕНИЕ]`, `[ВЫБОР ПОЛЬЗОВАТЕЛЕЙ]`
- Warning copy uses ⚠ with sentence case body: `⚠ ВАЖНО: АУДИО- И ВИДЕОЗВОНКИ НЕ ПОДДЕРЖИВАЮТСЯ.`
- Status badge: a calming editorial line, not a tag: `Связь готова к активации`

## Allowed terminology

- Warm everyday nouns: близкие, семья, родные, спокойствие, мост связи
- Concrete media: кружочки, фотографии, голосовые сообщения, видео в HD
- Gentle reassurance: "не перегревает", "не тратит заряд", "невидимая технология"
- Familiar nicknames: "кружочки" for video messages (the actual user term)

## Banned in this voice

- Engineering jargon: BBR, TCP, RTT, handshake, инкапсуляция, шейпинг — ALL banned
- Terminal punctuation: no `[01]`, `_`, no SYS_OK
- Business jargon: "непрерывность", "корпоративный", "ROI", "продуктивность"
- "Профессиональный" / "корпоративный" — wrong register
- Exclamation marks
- Anything that signals "this is technical"

## Headline pattern

Two-line, calm cadence:
- Line 1: scenario / promise (`ВАШ СПОКОЙНЫЙ ДОСТУП`)
- Line 2: object — what they want (`К ТЕЛЕГРАМУ.`)

The period anchors it as a complete thought, not a hype slogan.

## Card body pattern

1–2 sentences. Lead with the emotional outcome ("больше не нужно ждать"), follow with the simple benefit. Address the reader as "вы" warmly.

Examples (from current C copy):
- "Больше не нужно ждать загрузки «кружочков». Смотрите видео от семьи сразу."
- "Фотографии внуков и друзей открываются в высоком качестве без задержек."

## FAQ pattern

Q is a plain everyday concern.
A is 1–2 sentences, reassuring, no technical detail.

Examples:
- Q: "Сложно ли это подключить?" → A: "Это занимает 10 секунд. Просто нажмите на одну ссылку в боте, и вы снова на связи."
- Q: "Это безопасно для телефона?" → A: "Да. Это стандартная сетевая настройка, которая не тратит заряд и не имеет доступа к данным."

## Hard refusals (in addition to account-level)

- Never use technical acronyms in body copy
- Never say "оптимизация сетевого стека" — too engineering. Say "быстрая загрузка" / "связь без задержек"
- Never imply complexity — even when describing technology
- Never use the word "трафик" — use "связь" / "загрузка"

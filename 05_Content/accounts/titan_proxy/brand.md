---
account: "[[accounts/titan_proxy/account]]"
type: brand
status: active
---

# Titan Proxy — Brand Invariants

Product-level facts that hold across every variant. Voice rendering changes per persona; these don't.

## Naming

| Context | Form |
|---------|------|
| Terminal / DevOps register (Variant A) | `TITAN_PROXY` (uppercase, underscore) |
| Premium / business register (Variant B) | `Titan` (bare) |
| Mass / family register (Variant C) | `Titan Proxy` (two words, title case) |
| Bot reference everywhere | `@TitanTGProxy_bot` |

## Core claim (single sentence — variant rewrites tone, not substance)

Telegram-native network optimization billed in XTR, no third-party app, calls explicitly out-of-scope.

## Always-true product attributes

- Backbone nodes in Europe (no city / provider naming)
- TCP BBR congestion control on the edge nodes
- Payment in Telegram Stars (XTR) — atomic, no external gateways
- Runs inside Telegram — no background process, no battery drain
- HTTPS-shaped traffic (handshake normalization)
- Per-session isolated keys on Premium tier
- 30-day access period

## Banned phrases (across every variant)

- "best", "fastest", "world-class", "unbreakable", "guaranteed"
- "powered by AI", "revolutionary", "next-gen", "unleash"
- "VPN" — this is not a VPN, never call it one
- "tunnel" — implies VPN
- specific latency numbers ("<50ms" etc.) unless wired to a real source
- specific bandwidth numbers unless wired to tariffs.ts
- city / country names for infrastructure
- exclamation marks

## Allowed in technical variants (A) ONLY

- Protocol names (TCP BBR, HTTPS, MTProto)
- Acronyms (RTT, BBR, XTR)
- Bracketed tags `[STEP_01]`, `[01]`, `[ШТАТНЫЙ_РЕЖИМ]`
- Status-line copy with `//` and `_` separators

## Tariff data (canonical reference)

All copy that mentions tier capacity must match `src/data/tariffs.ts` exactly (server seat density, NOT a per-user device limit — one personal link works on all of a single subscriber's own devices without sharing it externally):

- Basic — До 50 мест на сервере (`До 50 мест`) — Идеально для чтения новостных лент. Совместный, но стабильно быстрый мост связи.
- Family — До 7 мест на сервере (`До 7 мест`) — Быстрый сервер с минимумом соседей: высокий запас скорости для видео и тяжёлых файлов. (recommended)
- Premium — Личный выделенный сервер — Вся пропускная способность сервера принадлежит только вам. Абсолютный комфорт без компромиссов.

## Hard limitation (canonical reference)

- Short: `Важно: аудио- и видеозвонки не поддерживаются.`

## Technical Truth Translation Table (Plain Language, Zero BS)

Never explain technical boundaries with invented causality ("мощность серверов отдана", "ресурс узлов направлен", "глубокая маскировка"). When avoiding DevOps acronyms (`MTProto`, `TCP`, `UDP`, `RTT`, `XTR`), translate the **actual mechanism** into plain Russian:

| Engineering fact | Plain-language `business_ru` phrasing | Banned BS / invented causality |
|---|---|---|
| Telegram built-in proxy uses TCP-only messaging/media transport; calls use separate UDP/WebRTC streaming channel | «Встроенное подключение работает по протоколу передачи текста, фото и файлов. Аудио- и видеозвонки используют отдельный потоковый канал, поэтому через прокси не передаются и идут в Telegram напрямую.» | «Мы направили всю мощность серверов на чаты», «ресурс узлов отдан», «из-за глубокой маскировки связи», «голос не маршрутизируется» |
| Server seat density (`До 50 мест` / `До 7 мест` / `Личный выделенный сервер`) + edge congestion control | «Фиксированное число мест на сервере: меньше соседей на канале — ровная скорость загрузки документов и видео в часы пик.» | «Безлимитная полоса», «<20 мс», «99.9% SLA», «До 50 устройств» |
| Traffic isolation & end-to-end / client-server encryption | «Подключение работает строго внутри Telegram, не затрагивая почту и банковские приложения. Прокси передаёт уже зашифрованные данные и не видит содержимое переписки.» | «Анонимный VPN-туннель», «шифрует весь телефон» |
| Gift voucher (`/gift`) | «Отдельный подарочный доступ на 30 дней с собственной персональной ссылкой для получателя — передавать свой личный ключ не нужно.» | «Раздача одной ссылки друзьям» |

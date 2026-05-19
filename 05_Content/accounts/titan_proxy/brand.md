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

All copy that mentions tier capacity must match `src/data/tariffs.ts` exactly:

- Basic — До 50 устройств — Идеально для чтения новостных лент. Совместный, но стабильно быстрый мост связи.
- Family — До 7 устройств — Личный канал для вас и ваших близких. Никто посторонний не замедлит вашу связь. (recommended)
- Premium — Личный выделенный сервер — Вся пропускная способность сервера принадлежит только вам. Абсолютный комфорт без компромиссов.

## Hard limitation (canonical reference)

- Short: `Важно: аудио- и видеозвонки не поддерживаются.`
- Long: `Мы направили всю мощность серверов на мгновенную загрузку фото, видео и кружочков. Из-за особенностей глубокой маскировки связи, звонки внутри мессенджера недоступны.`

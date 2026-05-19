---
account_handle: titan_proxy
type: product
platform_handles:
  telegram_bot: "@TitanTGProxy_bot"
domains:
  variant_a: "titanproxy.tech"
  variant_b: "mtproxy.link"
  variant_c: "mtproxy.guru"
status: active
created: 2026-05-19
---

# titan_proxy — Product Account

## Who this product is

Titan Proxy — Telegram network-stack optimizer billed in Telegram Stars (XTR). Backbone nodes in Europe with TCP BBR. Runs inside Telegram, no third-party app. Three audience-specific landing variants share the same product, bot, and tariff structure.

## Audience segments

One variant per persona — never collapse them into one page:
- **ru_devops** → Variant A — DevOps / network-aware technical users. Register: terminal log.
- **ru_business** → Variant B — Professionals, remote teams, business communicators. Register: premium / continuity.
- **ru_family** → Variant C — Mass-market / family users seeking calm reliable access. Register: warm / emotional.

## Product invariants (apply to every variant)

- Pricing lives in `@TitanTGProxy_bot`. Never hardcode Star prices in copy.
- Tariffs are canonical in `src/data/tariffs.ts` (Basic / Family / Premium). Capacity strings and pitches MUST match that file character-for-character — copy never paraphrases tariff data.
- `HARD_LIMITATION`: audio + video calls are not routed on ANY tier. Surface this on every variant.
- `LOCATION_LABEL`: "Надёжные серверы в Европе" — never name a city, country, or provider.
- `BILLING_PERIOD`: 30 дней доступа.
- One CTA per page → `@TitanTGProxy_bot` (or `tg://proxy?...` for real users via server-injected trial link).

## What it must never do

Hard refusals — applied as a final filter on every draft:

- **Never invent stats, capacity numbers, latency claims, or prices.** Tariffs come from `tariffs.ts`. Anything else must be marked `[TODO: verify]`.
- **Never name specific infrastructure.** No "Tel Aviv", "Frankfurt", "Hetzner", etc. → use [[brand]]'s "Premium European edge" / "магистральные узлы в Европе".
- **Never claim call support.** Calls are out-of-scope by design — surface the limitation, don't hide it.
- **Never promise call support is coming.** No roadmap promises.
- **Never use exclamation marks.**
- **Never mix variant registers.** Terminal log voice in family copy = drift. Warm emotional copy in DevOps voice = drift.

## Files

| File | Purpose |
|------|---------|
| `account.md` | This file — product identity + invariants |
| `brand.md` | Product brand attributes (name, claim, banned phrases) |
| `personas/<persona>.md` | One per audience segment — references one design + one voice |
| `design/<design>.md` | Visual systems: tokens, fonts, effects (consumed by code generator + video pipeline) |
| `voice/<voice>.md` | Tone / register per persona |
| `channels/landing/<persona>.md` | Landing copy — drives `src/data/copy.ts` + `src/app/<variant>/page.tsx` |

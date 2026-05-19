---
slug: ru_devops
account: "[[accounts/titan_proxy/account]]"
variant_key: a
design: "[[design/cyber_overdrive]]"
voice: "[[voice/terminal_ru]]"
landing: "[[channels/landing/ru_devops]]"
language: ru
locale: ru_RU
domain: titanproxy.tech
status: active
---

# Persona — RU DevOps (Variant A)

## Who

Russian-speaking technical reader: DevOps engineer, sysadmin, network-aware indie developer, junior backend dev curious about routing. Has debugged at least one TCP/UDP issue themselves. Reads `mtr` output without help. Skeptical of marketing language; trusts diagnostic registers (status pages, packet captures, log tails).

## What they want from this page

Confirmation that Titan does at the network level what they've been trying to fix in their app stack. Specifically:
- Packet-loss recovery during ISP-side degradation
- RTT stabilization for media (the "круги" loading slowly)
- Session continuity during peak hours (no forced disconnects)
- A clear "this is not a VPN, this is in-protocol normalization" framing
- Honest disclosure that calls are out-of-scope (don't sell what doesn't ship)

## Why they convert

The page reads like a status board reporting on a working system. They trust it because:
- Cyan-on-black terminal aesthetic matches their tools
- Technical specificity (TCP BBR, HTTPS handshake normalization, BGP-style routing language) signals the team knows what it's doing
- Bracketed step IDs and `//` kickers feel like documentation, not marketing
- The hard limitation is on the page above the fold — no hidden gotchas

## Design + voice binding

- Visual: [[design/cyber_overdrive]] — black/cyan terminal, no rounding, scanline + grid
- Voice: [[voice/terminal_ru]] — diagnostic register, `//` kickers, `[XX]` IDs
- Layout: `data-variant="a"`, `data-theme="dark"` default

## SEO + metadata (mirrors `src/app/a/page.tsx`)

- Domain: `titanproxy.tech`
- Title: `Titan Proxy | TCP BBR Optimization для Telegram — Снижение пинга и потерь`
- Description: `Специализированная сеть для восстановления скорости Telegram при потерях пакетов. RTT <50ms, BBR включен. Для техсообщества и DevOps.`
- Keywords: `Telegram proxy, packet loss, TCP BBR, latency reduction, RTT optimization, network diagnostics`
- OG title: `Titan | TCP BBR-оптимизация Telegram`
- OG image: `https://titanproxy.tech/og-image-a.png?v=3`
- Canonical: `https://titanproxy.tech/`

## Channel outputs

- Landing copy: [[channels/landing/ru_devops]] → drives `COPY_A`, `FAQ_A`, `STATUS_BADGE_A` in `src/data/copy.ts`
- Video pipeline (future): same design tokens, same voice — terminal scrub-bar product demos
- Social pipeline (future): cyan-on-black single-line status posts

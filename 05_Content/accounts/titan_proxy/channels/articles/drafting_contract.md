---
account: "[[accounts/titan_proxy/account]]"
type: drafting_contract
channel: articles
status: active
created: 2026-11-11
---

# Titan Proxy — Article Drafting Contract

> Non-negotiable gates and invariants for all generated articles. Every article must pass `bin/gate_article.sh` before entering human review.

## 1. Zero Exclamation Marks (Brand Rule #43)
- An exclamation mark (`!`) is prohibited anywhere in the article (frontmatter, headings, body, code comments).
- Reason: Editorial calm. Hype punctuation destroys authority across all three personas.

## 2. Regulatory Trigger Blocklist (Stealth Protocol)
The following terms (and their morphological variants) are prohibited (case-insensitive):
- `faketls`
- `dpi`
- `тспу`
- `обход`
- `блокировк`
- `цензур`
- `разблокировк`
- `анонимайзер`
- `ркн`

*Framing rule:* Frame benefits around **network stability**, **latency reduction**, **packet loss prevention**, and **direct media delivery**.

## 3. Infrastructure & Location Transparency
- Never name specific cities, countries, or hosting providers (e.g. Frankfurt, Helsinki, Germany, Hetzner, OVH).
- Allowed canonical reference: `Надёжные серверы в Европе` or `магистральные узлы в Европе`.

## 4. Limitation Transparency (`HARD_LIMITATION`)
- Audio and video calls are not routed over MTProto proxy by design.
- If an article touches upon calls, audio, or service limitations, it must include the canonical limitation text:
  `Важно: аудио- и видеозвонки не поддерживаются.`
- Never promise or hint that call support is coming.

## 5. Tariffs & Metrics Integrity
- Never invent metrics, bandwidth caps, or Star prices.
- If tariffs are mentioned, capacities and pitches must match `src/data/tariffs.ts` exactly.
- Do not publish articles containing unresolved `[TODO: verify]` markers or speculative numbers (e.g. "<20мс").

## 6. Frontmatter & Schema Constraints
- Title: 20–100 characters.
- Description: 50–200 characters.
- Frontmatter values must NEVER contain `<` characters (prevents broken JSON-LD tag termination).
- `slug` must match filename (`<slug>.md`) in lowercase kebab-case.
- `publishAt` must be a valid ISO date (`YYYY-MM-DD`).

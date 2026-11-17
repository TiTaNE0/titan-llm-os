---
account: "[[accounts/titan_proxy/account]]"
type: channel_strategy
channel: articles
status: active
created: 2026-11-11
---

# Titan Proxy — SEO Article Channel Strategy

## 1. Mission & Scope
The article channel drives organic search traffic (Google & Yandex) across all three Titan Proxy apex domains without crossing stealth or brand invariants. Each domain serves a distinct audience persona and section prefix:

| Variant | Apex Domain | Section | Target Persona | Voice Register |
|---|---|---|---|---|
| **A** | `titanproxy.tech` | `/docs/` | `ru_devops` | `terminal_ru` (technical, protocols, benchmarks) |
| **B** | `bestproxy.deals` | `/compare/` | `ru_business` | `business_ru` (comparisons, ROI, continuity, security) |
| **C** | `mtproxy.guru` | `/help/` | `ru_family` | `family_ru` (warm, accessible, step-by-step, zero-jargon) |

## 2. Publication Cadence
- **Phase 1 (Weeks 1–4):** 3 articles per week (1 article per variant per week) to establish topical authority and accelerate crawler discovery.
- **Phase 2 (Ongoing):** 1 article per variant every 2 weeks (3 articles every fortnight).
- **Batch Processing:** Articles are researched, drafted, and verified in weekly 3-article batches.

## 3. Structural Conventions
Every article adheres to the following layout:
1. **Direct Answer:** The core question or problem must be answered directly in the first 2–3 sentences.
2. **Analysis / Step-by-Step:** Structured sections with clear headings (`h2`), lists, or code snippets.
3. **FAQ Section:** 2–4 concise Q&A pairs (rendered into `FAQPage` JSON-LD schema automatically).
4. **Related Articles:** Contextual links to 1–3 sibling articles via frontmatter `related: [slug1, slug2]`.
5. **Single CTA:** Exactly one conversion button at the bottom of the article (`<CTA variant={variant} />`) linking to `@TitanTGProxy_bot` through server-side trial claim.
6. **Hub & Home Links:** Breadcrumb and back-links to `/<section>` and `/`.

## 4. Cross-Domain Integrity
- **No Content Cannibalization:** Never translate or rewrite the same topic across variants. Each domain maintains its own exclusive keyword set.
- **Stealth Protocol:** All content must comply with `drafting_contract.md`. No regulatory trigger words, no exclamation marks, no infrastructure leaks.

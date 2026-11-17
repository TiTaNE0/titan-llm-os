---
type: channel_rubric
channel: articles
account: titan_proxy
status: active
created: 2026-11-11
---

# Critic Rubric — Titan Proxy Articles

Used by the Critic (Gemini via `agy -p`) to evaluate candidate drafts before human review.

## Evaluation Criteria (Pass/Fail)

1. **Persona & Voice Fidelity:**
   - Variant A (`ru_devops`): Terminal tone, technical precision, protocols, network parameters.
   - Variant B (`ru_business`): Business continuity, device impact, comparison rigor, clear checklist.
   - Variant C (`ru_family`): Everyday language, warmth, "кружочки", zero intimidating tech jargon.
2. **Immediate Utility:**
   - The article directly answers the primary search intent within the first 2–3 sentences. No fluff intros ("В современном мире...").
3. **Factual Sobriety:**
   - Zero hallucinated numbers, speeds, or latency claims.
   - Zero claims of external partnerships, specific datacenters, or city names.
4. **Limitation Honesty:**
   - Audio and video calls clearly marked as unsupported if relevant to the topic.
5. **Stealth Compliance:**
   - Complete absence of regulatory/bypass framing. Focus strictly on network performance, stability, and packet routing.

## Verdicts
- **SHIP:** All criteria met. No revisions required.
- **FIX:** Specific, actionable feedback explaining which lines violate criteria and how to rewrite them.

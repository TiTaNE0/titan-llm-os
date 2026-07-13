---
type: pipeline-design
artifact: compose-pipeline-design
status: design-first
prd_ref: "Reply_Pipeline_PRD_v3.0_Agentic.md §v3.1"
created: 2026-06-20
---

# Compose Pipeline — Design Roadmap (quote-tweets + original posts)

> DESIGN-FIRST — awaiting operator decision. NO build is in scope. This document is the deliverable. No role-spec, schema, gate rule, or orchestrator code is created/modified by this task. Build begins only after the operator picks an option below.

## 1. Why — conversion is the bottleneck, not reply quality
Per the cross-model review (Claude #5): reply QUALITY was never the binding constraint. CONVERSION is — turning thread readers into profile visits and follows. Replies are the lowest-ceiling format: buried in others' threads, the host gets a sliver of attention, a great reply mostly rewards the OP. The strongest vault takes (e.g. the rauchg runner-swappability point) are wasted as replies; they belong in formats that build the account's own presence. This pipeline retargets the same proven engine at presence, not participation.

## 2. Two output formats
- Quote-tweet — quote a high-signal thread where Evgeny has a grounded take (a project_authority.md entry honestly supports the angle). Keeps the OP's tweet as context; the quote adds the builder's distinct take above it.
- Original post — standalone, distilled from the strongest vault entries + the proven angles already in runs/_analytics/wins.md. No external thread; pure supply from the vault + what the audience already rewarded.

## 3. Engine REUSE map (from v3.1)
| Engine piece | Reuse? | Note |
|---|---|---|
| Vault_Scout -> search_vectors.json | REUSE | same vectors; compose samples them for post topics, not X-thread matching |
| project_authority.md grounding (grounds_with) | REUSE unchanged | same source-honesty; every draft binds a real entry id |
| Evgeny-B voice / reply_register.md | REUSE | register may relax slightly for originals (no thread to mirror) |
| bin/gate.sh | REUSE | word-count/no-!/concrete-signal/anti-repeat still apply; length band may differ for originals |
| Cross-family Critic | REUSE | load-bearing veto stays; rubric re-weighted, not replaced |
| Drafter/Producer/Asset/Wins-logger | REUSE | Producer assembles a compose review file; Wins-logger reads conversion, not reply engagement |

## 4. What is DIFFERENT from the reply pipeline
- No live-thread-fit for originals -> the Critic's thread_fit criterion is DROPPED for originals (no thread).
- Quote-tweets KEEP thread_fit + OP context (critic opens the quoted thread live).
- positioning_alignment weighs MORE — with no thread anchoring relevance, "reads like an active builder of agentic systems" becomes the primary hard gate for originals.
- Cadence + self-promo-ratio guard — compose writes to Evgeny's OWN feed, so flooding is a real risk; add a rate cap + a cap on consecutive/self-referential posts per window (values operator-set at build).
- Originals seed from wins.md — proven reply angles get promoted into original-post seeds.

## 5. SUCCESS METRIC — conversion
Success is CONVERSION: profile visits and follows attributable to compose posts, explicitly DISTINCT from reply engagement (likes/replies on someone else's thread). Wins-logger reads profile-visit/follow/quote signal from:ogrizkov for compose posts. Reply-engagement metrics are NOT the target and must not be substituted.

## 6. Implementation options (sketch only — do not build)
- Option A — new role-spec + compose_draft schema (format-tagged), parallel to reply role-specs. Pro: clean separation, format-specific rubric/gate. Con: duplicated orchestration.
- Option B — a `format` parameter (reply|quote-tweet|original) threaded through the existing chain; gate + critic branch on it. Pro: one engine, max reuse. Con: conditionals in gate/critic, coupling risk.
Recommendation: Option B, behind a feature flag so compose can't destabilize the proven reply chain — it maximizes v3.1 reuse (the whole point). Promote to A only if per-format branching grows unwieldy.

## 7. Status & next step
DESIGN-FIRST. Awaiting operator decision on Option A vs B + the cadence/self-promo-ratio numbers. No build until that decision is recorded.

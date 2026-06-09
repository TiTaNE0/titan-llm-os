---
type: pipeline-artifact
artifact: reply-role-critic
tier: 2
model: "non-Claude — grok -p (gpt-5.5 = future swap; its CLI pattern does not exist in this vault)"
prd_ref: "§4.4"
locked: 2026-06-10
---

# Critic — cross-family veto

Refute drafts against Rubric v1. Ships only what survives every criterion.

Mandate: REFUTE, don't grade gently. The drafter is a pathological optimist about its own output. Per-criterion verdict, not one vibe score.

Why non-Claude: a model grading its own family's output is a blind spot. The cross-family veto is load-bearing (PRD §10, §11); what's load-bearing is independent context + refute mandate.

## Contract

Reads (isolated per draft):
- The draft
- The target tweet text
- The bound entry's claim only (NOT full `project_authority.md`)
- Rubric v1 (below)

## Must-not-see

Full `../../../../voice.md`, `../../reply_register.md`, full `../../project_authority.md`, other drafts in the batch, gate internals. Judges output against the rubric, not the process.

Writes: each draft's verdict appended to `runs/<batch>/03_review.json` — fenced JSON: `{url, critic_verdict: "SHIP"|"FIX:<one line naming the failed criterion>", critic: "grok"|"claude-stub"}`.

## Rubric v1

Five individually-gradeable criteria. A draft ships only if it passes ALL five:

1. **voice_fit** — flat opener, no hype/hooks/engagement-bait, lands flat. Fails if the opener performs excitement or begs for a like.
2. **specificity_present** — ≥1 concrete signal (number / named tool / proper noun) tied to the bound entry. Fails if the reply could have been written without reading the entry.
3. **no_fabrication** — every concrete claim traces to the bound entry's substance. Target's numbers not claimed as his. No personal-life or employment details invented. Fails on any untraced claim.
4. **not_generic** — a take only the builder of these specific projects could give. Fails if a random developer could post the same reply.
5. **length_register_sane** — short norm; register imperfection (lowercase opener, dropped period) is minority and never touches the concrete signal. Fails if the reply is padded or register chaos drowns the point.

## Phase-1 stub

Phase 1: every draft gets `critic_verdict: "SHIP"`, `critic: "claude-stub"`. The orchestrator emits loud "no cross-family veto this run" to stdout AND `03_review.json`. Phase 2 swaps in real `grok -p` judging against Rubric v1.

## Hard boundaries

- Scores; never rewrites.
- Output is fenced JSON only — no prose wrap around it.
- Cross-family is the mechanism: keep this role on a non-Claude model (Phase 2+).

---
type: pipeline-artifact
artifact: reply-role-matcher
tier: 2
model: "claude-sonnet-4-6"
prd_ref: "§4.2"
locked: 2026-06-10
---

# Matcher — liveness gate + 1:1 grounding

Liveness filter then bind one distinct `project_authority` entry per surviving target. Grounds; never writes replies.

Why Sonnet not Haiku: grounding is judgment, not extraction. A wrong bind poisons every downstream draft of that target (PRD §7 rationale).

## Contract

Reads:
- `runs/<batch>/00_candidates.json`
- `runs/<batch>/00b_threads.json`
- `../../project_authority.md` ONLY

Writes: `runs/<batch>/01_anchored.json` — `{url, author, engagement, pillar, ground_with, why_live, entry_substance, contribution, thread_gist, post_type}` per surviving target.

## Must-not-see

`../../../../voice.md`, `../../reply_register.md`, search internals, any other role's reasoning, drafts, asset templates.

## Hard boundaries

- Apply liveness gate (corpse-drop, velocity, fresh-by-reach, English) before any matching.
- Replyability gate (distinct from groundability): after liveness, DROP any target whose `post_type` is poll, meme, or promo UNLESS its `00b_threads.json` entry shows a real technical discussion the bound entry can substantively join. Groundable ≠ replyable: an authority entry semantically touching the snippet is NOT sufficient — there must be a live conversation to add signal to. When in doubt, drop; a thin window beats an irrelevant reply.
- Bind 1:1: one DISTINCT `project_authority` entry per survivor; no entry reused within a batch; respect entry cooldowns. Bind against `thread_gist`, not the snippet. Write `thread_gist` and `post_type` into each survivor's `01_anchored.json` entry.
- Contributability gate (the bind condition — 2026-06-10a lesson: topically-groundable ≠ genuinely-contributable): for each candidate bind, write the `contribution` sentence from the THREAD's perspective — what this reply adds to THIS thread (answers the ask / extends the point / corroborates with specific experience), supportable by `entry_substance`. If the honest sentence requires redirecting the thread toward the entry's topic, the bind is a pivot — DROP the target. The test: would the thread's author and readers find the reply additive?
- Tag each: `pillar`, `touches`, `ground_with`.
- Floor: ≥8 replyable+groundable survivors; if below floor, orchestrator may trigger AT MOST 1 re-scout, then re-match; proceed with ≥1.
- A wrong bind poisons the target's whole downstream chain — no speculative or partial-fit binds.

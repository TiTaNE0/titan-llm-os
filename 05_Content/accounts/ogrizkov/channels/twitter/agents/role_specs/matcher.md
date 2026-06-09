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
- `../../project_authority.md` ONLY

Writes: `runs/<batch>/01_anchored.json` — `{url, author, engagement, pillar, ground_with, why_live, entry_substance, entry_angle}` per surviving target.

## Must-not-see

`../../../../voice.md`, `../../reply_register.md`, search internals, any other role's reasoning, drafts, asset templates.

## Hard boundaries

- Apply liveness gate (corpse-drop, velocity, fresh-by-reach, English) before any matching.
- Bind 1:1: one DISTINCT `project_authority` entry per survivor; no entry reused within a batch; respect entry cooldowns.
- Tag each: `pillar`, `touches`, `ground_with`.
- Floor: ≥8 groundable survivors; if below floor, orchestrator may trigger AT MOST 1 re-scout, then re-match; proceed with ≥1.
- A wrong bind poisons the target's whole downstream chain — no speculative or partial-fit binds.

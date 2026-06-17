---
type: pipeline-artifact
artifact: reply-role-wins
tier: 2
model: "Grok — grok -p"
prd_ref: "§4.8, §v3.1.5"
locked: 2026-06-16
---

# Wins-logger — engagement capture + append

Pull real engagement for the posted batch; append winners to `wins.md`. Append-only; never rewrites.

Behavior source: `../../skill/twitter-reply-log-wins.md`.

## Contract

Reads:
- `../../runs/_analytics/wins.md` — schema + existing entries (dedup check).
- The posted batch's `../../runs/<batch>/replies_to_post.md` — what was posted, with `ground_with`, `content_pillar`, and `project_pillar` per reply.

Work: `grok -p` `from:ogrizkov` over the window since posting → pull each reply's real engagement.

Writes: `../../runs/_analytics/wins.md` (append only).

Schema per winner:
```
- <date> · <thread topic / @author> · content_pillar:<build|apply|results> · project_pillar:<development|agentic|marketing> · ground_with:<entry id> · angle: <the angle that worked> · engagement: <views / likes / replies / follows> · link:<url>
```
If nothing cleared the bar: `- <date> · no wins this window`.

Then the orchestrator (the Orchestrator host (claude-opus-4-8 primary; claude-fable-5 if available), same session — never a small model) appends ONE distilled rule per winner: opener type, register, pillar, length. The chain is fail → investigate → verify → distill → consult. Scout consults rules, not raw logs.

## Must-not-see

Drafts for other batches, asset templates, gate internals, `../../../../voice.md`, `../../reply_register.md`.

## Hard boundaries

- Real engagement only: every number from a live `grok -p` return. Never invent or estimate.
- Append, never rewrite. `wins.md` is append-only memory.
- Writes only `wins.md`. No drafting, no posting, no other files.
- Distillation (one rule per winner) stays on the Fable 5 orchestrator host — not delegated to Wins-logger.

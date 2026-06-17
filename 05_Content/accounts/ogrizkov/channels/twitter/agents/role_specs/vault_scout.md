---
type: pipeline-artifact
artifact: reply-role-vault-scout
tier: 2
model: "claude-sonnet-4-6"
prd_ref: "§7, §v3.1.2"
locked: 2026-06-16
---

# Vault Scout — project authority indexer

Parse `project_authority.md` into agentic search vectors. Runs before X discovery; result is cached and reused across runs.

Why Sonnet: indexing the vault into search vectors is extraction + intent-shaping, not deep judgment. It runs only when the vault changes or the 7-day TTL expires. Haiku stays on the mechanical roles (Asset, Producer).

## Contract

Reads:
- `../../project_authority.md` ONLY

Writes: `../../runs/_index/search_vectors.json` — cached, shared across batches.

Re-run conditions: vault change (project_authority.md hash changed) OR 7-day TTL elapsed since `generated_at`. The Orchestrator owns the re-run decision — the Scout is stateless and never tracks whether it last ran.

## Vector rule

Every vector is AI/agentic — either an agentic-systems topic itself, or "how an agent reasoned/implemented X". Bare dev topics without an agent angle are rejected.

Good examples: "agents reasoning about offline-first PWA cache invalidation", "agent retry loops and context-window limits", "multi-agent content pipelines".
Rejected: "Redis Geo consensus" with no agent angle.

Each vector carries:
- `content_pillar` — one of build|apply|results (the reply content bucket this vector serves)
- `grounds_with` — array of real `project_authority.md` entry ids that can honestly ground a reply on this topic
- `query_seeds` — a pool of synonyms/phrasings; the Orchestrator rotates/samples a different subset per run, not the Scout

## Anti-staleness

The 7-day TTL is concrete: compare `generated_at` (ISO timestamp in `search_vectors.json`) to the current date. If the difference exceeds 7 days, the cache is stale and must be regenerated.

`query_seeds` is a POOL. Rotation across runs is done by the Orchestrator, not the Scout. The Scout emits the full pool; the Orchestrator samples a different subset each run so the same queries do not fire every 24-48h.

## Must-not-see

- `../../../../voice.md`
- `../../reply_register.md`
- Any drafts
- Any live X data
- Any `runs/<batch>/` artifact (batch artifacts are downstream; the Scout is upstream)

## Hard boundaries

- Every vector must be agentic — reject any vector that does not fit "agentic-systems topic" or "how an agent reasoned/implemented X".
- Each vector carries exactly one `content_pillar` (build, apply, or results).
- `grounds_with` must contain real entry ids from `project_authority.md` — no invented or inferred ids.
- Stateless: no rotation state, no run history, no memory of prior fetches. The Orchestrator holds that state.
- Output is a single `search_vectors.json` write; no other files touched.

## Telemetry

One `bin/trace.sh` line per run:

```
bin/trace.sh --role vault_scout --model claude-sonnet-4-6 --provider anthropic --outcome generated|cached-skip
```

`cached-skip` when the Orchestrator determines TTL has not elapsed and skips the Scout invocation entirely.

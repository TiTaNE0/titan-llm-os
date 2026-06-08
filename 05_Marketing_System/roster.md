---
type: pipeline-artifact
artifact: slim-roster
prd_ref: "§3.1, §12.4"
locked: 2026-06-01
---

# Slim roster — Phase 1 (6 agents)

The §4 flow runs these six roles. Each pipeline step carries its own model explicitly (`-m <id> --provider <p>`) — there is no static per-agent map in Hermes (§12.2). Model IDs rotate ~monthly; **this table is the single swap point.**

| # | Agent | Model | Provider | Spec file |
|---|-------|-------|----------|-----------|
| 1 | **Scout** | `grok-4.3` (X/web) + `clockworks/tiktok-scraper` (TikTok; actors volatile — verify, see SKILL Step 1) | `xai-oauth` / `apify` MCP | `schemas/scout_schema.md` |
| 2 | **Strategist** | `anthropic/claude-opus-4.8` | `openrouter` | `role_specs/strategist.md` |
| 3 | **Creator** | `anthropic/claude-opus-4.8` → `claude-sonnet-4.6` | `openrouter` | `role_specs/creator.md` |
| 4 | **Viability Gatekeeper** | `anthropic/claude-haiku-4.5` | `openrouter` | `rubrics/gatekeeper_rubric.md` |
| 5 | **Critic + Judge** | `gpt-5.5` (cross-family) | `openai-codex` | `role_specs/critic_judge.md` |
| 6 | **Producer** | `anthropic/claude-haiku-4.5` | `openrouter` | `schemas/producer_profiles.md` |

## Rules
- Voice tuning lives in **Creator output**; the Judge only *scores* voice (§3.1). No Brand Voice Guardian.
- Cross-family veto is load-bearing: keep Critic/Judge on a **non-Claude** model (§8.1).
- **Cheap-test tier (current):** route all roles to free/cheap models for plumbing tests; swap to the production IDs above for the real run.
- **Anthropic note:** Claude routes via OpenRouter, NOT the direct Anthropic OAuth (blocked for third-party — see [[project_marketing_profile]]).
- Not built (named-only, Phase 2): Scriptwriter split from Creator, standalone Voice Pass, separated Critic/Judge.

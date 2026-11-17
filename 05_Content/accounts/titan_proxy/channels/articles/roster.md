---
type: channel_roster
channel: articles
account: titan_proxy
status: active
created: 2026-11-11
---

# Article Pipeline Roster — Titan Proxy

Single swap point for agent roles and model bindings in the article generation pipeline.

| # | Role | Model / Tool | Execution Mode | Responsibilities |
|---|---|---|---|---|
| 1 | **Scout** | Grok (`grok -p`) | Live query / CLI | Searches live user queries, forum discussions, Telegram chat FAQs for real questions without making up facts. |
| 2 | **Strategist** | Claude Opus | Subagent | Selects backlog topics per variant, cross-checks `LEDGER.md` to prevent cannibalization, defines keyword targets. |
| 3 | **Writer** | Claude Sonnet | Subagent | Drafts article text conforming to `voice/*_ru.md` and `drafting_contract.md`. |
| 4 | **Critic** | Gemini 3.1 Pro (High) | `agy -p` (cross-family) | Evaluates draft against `rubric.md`. Holds independent veto power (SHIP / FIX). |
| 5 | **Gate** | Deterministic shell | `bin/gate_article.sh` | Enforces zero `!`, stop-words regex, frontmatter schema, length checks, and `HARD_LIMITATION`. |
| 6 | **Producer** | Claude Haiku | Subagent | Formats final markdown into `content/articles/{a,b,c}/<slug>.md`, creates branch, prepares PR. |
| 7 | **Wins-logger** | Grok + Orchestrator | Periodic | Ingests GSC and Webmaster impression/click metrics into `LEDGER.md` once a month. |

## Roster Rules
- **Cross-Family Veto:** The Critic role must run on a non-Claude model (Gemini) to ensure adversarial verification.
- **Deterministic Gate:** The Gate script has authority over any LLM. If `bin/gate_article.sh` fails, the draft is rejected regardless of Critic score.

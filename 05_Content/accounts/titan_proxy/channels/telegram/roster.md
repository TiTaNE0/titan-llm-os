---
type: channel_roster
channel: telegram
account: titan_proxy
status: active
created: 2026-11-18
---

# Telegram Channel Pipeline Roster — Titan Proxy

Single swap point for agent roles and tool bindings in the Telegram channel content pipeline.

| # | Role | Model / Tool | Execution Mode | Responsibilities |
|---|---|---|---|---|
| 1 | **Scout** | `/support` logs + `funnel_events` + `grok -p` *(optional)* | Local / CLI *(on demand)* | Primary inputs are bot `/support` objections, `funnel_events` drop-offs, and `[[channels/articles/LEDGER]]`. Use `grok -p` only when researching brand-new external changes (e.g. Telegram Stars payment shifts), not on routine batches. |
| 2 | **Strategist** | Coordinator / Subagent | Vault read | Evaluates `[[channels/telegram/calendar.yaml]]` (autonomously promoting upcoming events within `lead_days` inside `promo_guardrails`), picks 1–3 topics from `[[channels/telegram/backlog]]` and unpromoted `live` articles from `[[channels/articles/LEDGER]]`, cross-checking `[[channels/telegram/LEDGER]]` to prevent duplicates. |
| 3 | **Writer** | Subagent | Draft | Drafts ultra-short, varied Telegram HTML posts (`120–260` chars default, `<= 290` with call disclosure; pin/reference `300–600`) strictly in `[[voice/business_ru]]` (`Titan`) using `brand.md` plain-language translations and complying with `[[channels/telegram/drafting_contract]]`. |
| 4 | **Tech-Fact Critic** | Specialist Subagent / `agy -p` | Adversarial check | Verifies Technical Truth Gate against `brand.md` (zero invented causality, accurate plain-language explanation, promo terms match `content/promos.json`). Holds independent veto (`SHIP` / `FIX`). |
| 5 | **Growth & Calendar Critic** | Specialist Subagent / `agy -p` | Adversarial check | Evaluates candidate posts against `[[channels/telegram/rubric]]` (selling conversion hook, calendar alignment, seasonal Russian landscape visual fit). Holds autonomous approval/veto (`SHIP` / `FIX`) with zero human bottleneck. |
| 6 | **Gate** | Deterministic shell | `bin/gate_telegram.sh` | Enforces valid JSON schema, zero `!`, Stealth Protocol stop-words, banned technical-BS phrases, zero geo/infra leaks, zero `business_ru` banned terms, date windows for `promo`/`holiday`, `promos.json` cross-validation, two-tier length bounds, and selective `HARD_LIMITATION`. |
| 7 | **Producer** | Subagent / Automation | Git & Deploy | Updates `content/posts.json`, `content/promos.json`, `docs/CONTENT_PLAN.md`, `[[channels/telegram/LEDGER]]`, and `[[channels/telegram/calendar.yaml]]`, runs `pytest`, commits, pushes, and deploys to VPS. |

## Roster Rules
- **Autonomous Agent-Council Approval:** No human approval step is needed when events fit `calendar.yaml` `promo_guardrails` (`5..14` bonus days, no Star price changes). Both Critics must return `SHIP`.
- **Deterministic Gate:** `bin/gate_telegram.sh` overrides any LLM verdict. Any `GATE FAIL` blocks commit/push.

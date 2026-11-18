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
| 2 | **Strategist** | Coordinator / Subagent | Vault read | Picks 1–3 topics from `[[channels/telegram/backlog]]` and unpromoted `live` articles from `[[channels/articles/LEDGER]]`, cross-checking `[[channels/telegram/LEDGER]]` to prevent duplicates. |
| 3 | **Writer** | Subagent | Draft | Drafts ultra-short, varied Telegram HTML posts (`120–260` chars default, `<= 290` with call disclosure; pin/reference `300–600`) strictly in `[[voice/business_ru]]` (`Titan`) complying with `[[channels/telegram/drafting_contract]]`. |
| 4 | **Critic** | Gemini (`agy -p`, cross-family) | `agy -p` | Evaluates candidate JSON post entries against `[[channels/telegram/rubric]]`. Holds independent veto power (`SHIP` / `FIX`). |
| 5 | **Gate** | Deterministic shell | `bin/gate_telegram.sh` | Enforces valid JSON schema, zero `!`, Stealth Protocol stop-words, zero geo/infra leaks, zero `business_ru` banned terms (`VPN`, `туннель`, `MTProto`, `пользователь`, hardcoded Star prices), two-tier length bounds (`[120, 260]`/`[120, 290]` standard, `[300, 600]` pin/reference), and selective `HARD_LIMITATION`. |
| 6 | **Producer** | Subagent / Automation | Git | Appends validated posts to `/Users/titane0/Programming/titan-proxy-bot/content/posts.json`, updates `[[channels/telegram/LEDGER]]`, commits and pushes to `origin main`. |

## Roster Rules
- **Cross-Family Veto:** Critic must evaluate independently against `rubric.md`.
- **Deterministic Gate:** `bin/gate_telegram.sh` overrides any LLM verdict. Any `GATE FAIL` blocks commit/push.

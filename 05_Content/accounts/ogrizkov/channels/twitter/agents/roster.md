---
type: pipeline-artifact
artifact: reply-roster
prd_ref: "§7, §12"
locked: 2026-06-10
---

# Reply pipeline roster — single swap point; model IDs rotate monthly

| # | Role | Model | Invocation | Spec file |
|---|------|-------|-----------|-----------|
| 0 | Orchestrator | `claude-fable-5` (fallback `claude-opus-4-8`) | host Claude Code session | `../skill/twitter-reply-orchestrate.md` |
| 1 | Scout | Grok (X access) | `grok -p` (fenced-JSON capture) | `role_specs/scout.md` |
| 2 | Matcher | `claude-sonnet-4-6` | Claude sub-agent | `role_specs/matcher.md` |
| 3 | Drafter | `claude-sonnet-4-6` | Claude sub-agent | `role_specs/drafter.md` |
| 4 | Critic | non-Claude: `grok -p` (`gpt-5.5` = future swap) | `grok -p` (cross-family veto) | `role_specs/critic.md` |
| 5 | Gatekeeper | — (shell) | `bin/gate.sh` via bash≥4 | (frozen; rules live in `bin/gate.sh`) |
| 6 | Asset | `claude-haiku-4-5` | sub-agent + `bin/render_asset.sh` | `role_specs/asset.md` |
| 7 | Producer | `claude-haiku-4-5` | sub-agent | `role_specs/producer.md` |
| 8 | Wins-logger | Grok | `grok -p` | `role_specs/wins.md` |

## Rules

- Cross-family veto is load-bearing (PRD §11): Critic stays non-Claude. What's load-bearing is independent context + refute mandate, not merely the family boundary.
- Phase-1 Critic is a Claude stub with a loud "no cross-family veto this run" flag emitted to stdout AND `03_review.json`. Phase 2 swaps in real `grok -p` judging against Rubric v1.
- `bin/gate.sh` SOURCE is authoritative over any prose paraphrase of its rules. Run via `/opt/homebrew/bin/bash`; exit 2 = config error = abort, never retry.

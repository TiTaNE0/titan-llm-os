---
type: pipeline-artifact
artifact: reply-roster
prd_ref: "§7, §12, §v3.1"
locked: 2026-06-16
---

# Reply pipeline roster — single swap point; model IDs rotate monthly

| # | Role | Model | Invocation | Spec file |
|---|------|-------|-----------|-----------|
| 0 | Orchestrator | `claude-opus-4-8` (host; `claude-fable-5` if available) | host Claude Code session | `../skill/twitter-reply-orchestrate.md` |
| 0b | Vault_Scout | `claude-sonnet-4-6` (Opus on major vault change) | Claude sub-agent | `role_specs/vault_scout.md` |
| 1 | Scout | Grok (X access) | `grok -p` (fenced-JSON capture) | `role_specs/scout.md` |
| 2 | Matcher | `claude-opus-4-8` | Claude sub-agent | `role_specs/matcher.md` |
| 3 | Drafter | `claude-sonnet-4-6` | Claude sub-agent | `role_specs/drafter.md` |
| 4 | Critic | non-Claude: Gemini 3.1 Pro (High) via `agy -p` | `agy -p "<prompt>" --model "Gemini 3.1 Pro (High)" --print-timeout 10m --dangerously-skip-permissions` (cross-family veto, snapshot-read) | `role_specs/critic.md` |
| 5 | Gatekeeper | — (shell) | `bin/gate.sh` via bash≥4 | (frozen; rules live in `bin/gate.sh`) |
| 6 | Asset | `claude-haiku-4-5` | sub-agent + `bin/render_asset.sh` | `role_specs/asset.md` |
| 7 | Producer | `claude-haiku-4-5` | sub-agent | `role_specs/producer.md` |
| 8 | Wins-logger | Grok | `grok -p` | `role_specs/wins.md` |

## Rules

- Cross-family veto is load-bearing (PRD §11): Critic stays non-Claude (Gemini ≠ Claude). Independence = non-Claude family + judging from the persisted snapshot, not live browsing.
- Phase-1 stub is scaffold-test-only and forces `held: true`; a missing Phase-2 critic ABORTS the batch, never falls back to the stub. The stub emits a loud "no cross-family veto this run" flag to stdout AND `03_review.json`.
- `bin/gate.sh` SOURCE is authoritative over any prose paraphrase of its rules. Run via `/opt/homebrew/bin/bash`; exit 2 = config error = abort, never retry.
- Global grok budget per run: MAX_GROK_CALLS default 40 (named, tunable); with per-vector MAX_FETCH_PER_VECTOR default 3, these are the hard stop conditions. The Critic (agy/Gemini) is NOT a grok call — MAX_GROK_CALLS bounds Scout + Wins-logger only.
- Quarantine: a target that fails after its draft-retry cap and one replacement is quarantined — recorded with its reject history, never silently dropped, never allowed to halt the run.

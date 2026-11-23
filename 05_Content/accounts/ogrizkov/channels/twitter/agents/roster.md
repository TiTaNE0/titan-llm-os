---
type: pipeline-artifact
artifact: reply-roster
prd_ref: "§7, §12, §v3.1, v3.2"
locked: 2026-11-23
---

# Reply pipeline roster — single swap point; model IDs rotate monthly

| # | Role | Model | Invocation | Spec file |
|---|------|-------|-----------|-----------|
| 0 | Orchestrator | `claude-opus-4-8` (host; `claude-fable-5` if available) | host Claude Code session | `../skill/twitter-reply-orchestrate.md` |
| 0b | Vault_Scout | `claude-sonnet-4-6` (Opus on major vault change) | Claude sub-agent | `role_specs/vault_scout.md` |
| 1 | Scout | Grok (X access) — discovery search only | `grok -p` (fenced-JSON capture), at most 2 calls a run plus the reserve | `role_specs/scout.md` |
| 1b | Post reader | — (script) | `bin/fetch_posts.py` over the public endpoint: thread snapshots, his reply count, readings, author answers, pattern refresh; grok only as the fallback | (rules live in the script) |
| 2 | Matcher | `claude-opus-4-8` | Claude sub-agent | `role_specs/matcher.md` |
| 3 | Drafter | `claude-sonnet-4-6` | Claude sub-agent | `role_specs/drafter.md` |
| 4 | Critic | non-Claude: the first answering rung of `critic_ladder.json`; the model of the run is `../runs/_index/critic_model.json` | `agy -p "<prompt>" --model "<cli_name>" --print-timeout 10m` (cross-family veto, snapshot-read) | `role_specs/critic.md` |
| 4b | Interest reviewer (rule 11) | `claude-opus-4-8`, fresh context per draft | Claude sub-agent, in parallel with the Critic | `role_specs/critic.md` § Interest review |
| 5 | Gatekeeper | — (shell) | `bin/gate.sh` via bash≥4 (text gate) and `bin/target_filter.py` (rule 10 limits, ranking, hook and item checks) | (rules live in the scripts) |
| 6 | Asset | `claude-haiku-4-5` | sub-agent + `bin/render_asset.sh` (interactive runs only) | `role_specs/asset.md` |
| 7 | Producer | — (script) | `bin/produce.py` | `role_specs/producer.md` |
| 8 | Wins-logger | — (script) for reads, Grok only as the fallback | `bin/fetch_posts.py my-reply` + `bin/measure.py`; `grok -p from:ogrizkov` fallback | `role_specs/wins.md` |

## Scripts

| Script | Owns |
|---|---|
| `bin/preflight.sh` | live probes, run lock, branch guard, Mail readiness, critic rung of the run |
| `bin/slot_state.py` | slot id, ledger, delivery cap, posting recommendation, stages, pause, slot log, alarms, `STATUS.md` |
| `bin/fetch_posts.py` | reads of known posts through the public endpoint |
| `bin/target_filter.py` | rule 10 limits, ranking, the large-account lane, zones, hook sheet, item checks |
| `bin/produce.py` | `replies_to_post.md` and the recommended/review marks |
| `bin/email_replies.py` | the mail (delivery mode B), verified delivery, feedback reading |
| `bin/measure.py` | per-reply log, marks, tripwire, agreement, export import, period report |
| `bin/qualify_critic.sh` | probe choice, probe evaluation, critic qualification |

## Rules

- Cross-family veto is load-bearing (PRD §11): the Critic stays non-Claude and non-GPT. Independence = non-Claude family + judging from the persisted snapshot, not live browsing. `critic_ladder.json` is the only file that names a critic model.
- Phase-1 stub is scaffold-test-only and forces `held: true`; a missing Phase-2 critic ABORTS the batch (unattended: next rung), never falls back to the stub. The stub emits a loud "no cross-family veto this run" flag to stdout AND `03_review.json`.
- `bin/gate.sh` SOURCE is authoritative over any prose paraphrase of its rules, and its word and n-gram limits stay as constants there. Run via `/opt/homebrew/bin/bash`; exit 2 = config error = abort, never retry.
- Grok budget: `cost.max_grok_calls` in `params.json` per run (discovery only), `cost.maintenance_grok_calls` in maintenance (fallback only). Every other number a script reads lives in `params.json`. The Critic (agy) is NOT a grok call.
- Quarantine: a target that fails after its retry budget is quarantined — recorded with its reject history, never silently dropped, never allowed to halt the run.

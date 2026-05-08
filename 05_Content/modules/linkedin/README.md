# LinkedIn Module

**Status:** active
**Channel:** LinkedIn (Solutions Architect-facing)
**Owner:** Evgeny Ogryzkov
**Phase:** E (Vault-Driven Posts) — bot pulls drafts from `05_Content/03_Drafts/` autonomously

## Scope

Long-form professional posts on LinkedIn. Single-post format (no thread chains — LinkedIn doesn't have native threading). This module is the channel layer; voice/tone comes from the personalization add-on (currently `voice_evgeny.md`).

## Files

| File | Purpose |
|------|---------|
| `README.md` | This file — module manifest |
| `strategy.md` | Tactical playbook: cadence, audience, post format, time slots |
| `failure_log.md` | Append-only record of AI-drift incidents (user-maintained) |
| `templates/Post_Template.md` | LinkedIn post skeleton + frontmatter schema |

## How it's loaded

The LinkedIn anchor workflow (`local_skills/workflows/anchor_workflow.py`) scans `05_Content/03_Drafts/` for files with `module: linkedin` AND `status: ready` in frontmatter. The bot picks the FIFO-oldest ready draft, runs full pre-flight (lock, pause, IP, schedule, stealth budget, browser auth), and publishes.

**Frontmatter status IS the HITL approval signal.** The user authors and approves a post by writing it in Obsidian and setting `status: ready`. No Telegram round-trip required.

## Drafting flow (manual until `/post` macro lands)

1. Copy `templates/Post_Template.md` to `05_Content/03_Drafts/<title>.md`
2. Fill in body and frontmatter
3. Set `status: ready` when finished
4. Bot publishes on next anchor run (or via `/run anchor` from Telegram)
5. On success: bot moves file to `05_Content/04_Published/`, sets frontmatter `status: published` + `urn` + `published_at`

## Switching off

`/disable_module linkedin` removes it from `active_modules` in `modules.yaml`. Anchor workflow then skips vault scan and falls through to the legacy `pipeline_state.json` (`/draft_post` Telegram flow).

## Related skills

- [[.agent/skills/linkedin-automation/content-publishing.md]] — publish flow internals
- [[.agent/skills/linkedin-automation/circuit-breaker-protocol.md]] — pre-flight gate
- [[.agent/skills/linkedin-automation/playwright-stealth-fingerprinting.md]] — pre-flight gate
- [[.agent/skills/linkedin-automation/manual-sync-protocol.md]] — captcha/cookie refresh

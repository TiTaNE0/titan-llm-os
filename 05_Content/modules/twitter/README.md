# Twitter Module

**Status:** active (default)
**Channel:** X / Twitter (@ogrizkov)
**Owner:** Evgeny Ogryzkov

## Scope

Single-tweet replies, threads (5–25 tweets), and X Articles. This module is the channel layer; voice/tone comes from the personalization add-on (currently `voice_evgeny.md`).

## Files

| File | Purpose |
|------|---------|
| `README.md` | This file — module manifest |
| `strategy.md` | Tactical playbook: cadence, audience, time slots, format rules |
| `failure_log.md` | Append-only record of AI-drift incidents (user-maintained) |
| `templates/Thread_Template.md` | Default thread draft skeleton |

## How it's loaded

Macros (`/new_thread`, `/refactor_thread`, etc.) check `05_Content/modules.yaml` for the active module. When `twitter` is active, they:
1. Read `templates/Thread_Template.md` for structure
2. Read `strategy.md` for tactical context
3. Read the active voice file from `05_Content/personalization/` for tone
4. Compose a draft and HALT for user review

## Switching off

`/disable_module twitter` removes it from `active_modules` in `modules.yaml`. Drafting macros that target this module will then refuse to run until re-enabled.

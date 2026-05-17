# TikTok Module

**Status:** inactive
**Channel:** TikTok (@ogrizkov — pending setup)
**Prefix:** `tiktok_`
**Owner:** Evgeny Ogrizkov

## Scope

Short-form vertical video scripts (30–90s). Hook-first format — single idea per clip. Voice comes from `personalization/voice_evgeny.md`; this module adds channel-specific scene structure only.

## Files

| File | Purpose |
|------|---------|
| `README.md` | This file — module manifest |
| `strategy.md` | Channel playbook: format, hook rules, pacing |
| `failure_log.md` | Append-only drift incidents (user-maintained) |
| `templates/Script_Template.md` | Default script skeleton |

## How it's loaded

When activated, macros will:
1. Read `templates/Script_Template.md` for structure
2. Read `strategy.md` for format and pacing rules
3. Read active voice file from `05_Content/personalization/` for tone
4. Generate a script draft and HALT for user review

## Activation

1. Set `active: true` in `05_Content/modules.yaml` under `inactive_modules` → move to `active_modules`
2. Run `/enable_module tiktok`
3. Implement the `/new_tiktok` macro in `03_Brain/System_Agents.md` (currently a stub)

## Inactive Guard

Any macro that checks `modules.yaml` and finds `tiktok` absent from `active_modules` must halt immediately:
> "tiktok module inactive — enable in modules.yaml before running."

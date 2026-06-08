# TikTok Module

**Status:** inactive
**Channel:** TikTok (@ogrizkov — pending setup)
**Prefix:** `tiktok_`
**Owner:** Evgeny Ogrizkov

## Scope

Short-form vertical video scripts (30–90s). Hook-first format — single idea per clip. Voice comes from `accounts/<account>/voice.md` (default account: `ogrizkov`); this module adds channel-specific scene structure only.

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
3. Read `accounts/<account>/voice.md` for tone + `_shared/voice_pass.md` for application procedure
4. Generate a script draft and HALT for user review

## Build Artifacts

Each `/new_tiktok` run creates a build folder at `05_Content/modules/tiktok/build/[slug]/`:

| File | Purpose |
|------|---------|
| `tts_input.txt` | VO lines only, plain UTF-8, one sentence per line. Feed directly to Qwen3-TTS or ElevenLabs. |
| `captions.srt` | Estimated caption timing @2.7 words/sec. Re-align post-audio via Whisper. |
| `remotion_prompt.md` | Per-scene visual brief: scene / duration / screen content / VO / design notes. Input for Phase 3 Remotion renderer. |

The script draft itself lives in `05_Content/03_Drafts/tiktok_[slug].md`.

## Prerequisites Before Running

The macro halts if either of these is missing for the source project:
- `01_Projects/[[Source_Project]]/DESIGN.md` — copy from `05_Content/00_Content_Templates/DESIGN_Template.md`
- `01_Projects/[[Source_Project]]/VOICE.md` — copy from `05_Content/00_Content_Templates/VOICE_Template.md` *(optional but recommended)*

## Activation Status

Module is **active** as of 2026-05-17. `/new_tiktok` macro is fully implemented in `03_Brain/System_Agents.md`.

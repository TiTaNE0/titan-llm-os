# 05_Content/personalization/

Add-on layer that injects user-specific tone, audience, and brand context into any drafting macro across any module.

## Active Voice

Resolved from `05_Content/modules.yaml` → `voice.active`. Currently: `voice_evgeny`.

The active voice file is loaded silently by `/new_thread`, `/refactor_thread`, and any future drafting macros. Agents apply the voice's `<voice_fingerprint>` and `<writing_laws>` per its `<final_instruction>` — never narrate the rules in output.

## Files

| File | Purpose |
|------|---------|
| `voice_evgeny.md` | Voice spec for @ogrizkov (canonical). Edited separately; AI never modifies it. |

## Conventions

- **Filename has no version number.** When the user has a new voice version, they overwrite the file in place. References elsewhere stay valid.
- **Voice files are read-only for agents.** Modifications happen only via direct user edit.
- **Switching voices:** edit `modules.yaml` directly, or run `/set_voice <voice_name>`.
- **Disabling personalization entirely:** set `voice.active: none` in `modules.yaml`. Drafting macros then fall back to module-default tone (currently undefined; macros will refuse to draft until either voice is set or user supplies inline instructions).

## Future Add-Ons

This folder is also the home for future personalization assets that aren't voice files — e.g., `audience.md` (target reader profiles), `brand_assets.md` (logos, color codes, signature lines). Place them at this level, register in `modules.yaml` if macros need them.

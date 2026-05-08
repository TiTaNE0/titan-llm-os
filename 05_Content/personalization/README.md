# 05_Content/personalization/

Add-on layer that injects user-specific tone, audience, and brand context into any drafting macro across any module.

## ⚠ Voice Application Contract (HARD RULE)

Any drafting path — *any* module, *any* macro, present or future — that loads the active voice file from this folder MUST also load `voice_pass_protocol.md` and execute its two-pass procedure. The voice file alone is incomplete. They are an inseparable pair.

The voice file describes **what the voice is**. The protocol describes **how to apply it during drafting**. Loading one without the other produces voice-drift (see `05_Content/modules/<channel>/failure_log.md` for examples).

This rule is enforced at the personalization layer so it inherits to every channel module without duplication. Twitter, linkedin (Phase E), video, article, and anything added later all consult the same protocol.

## Active Voice

Resolved from `05_Content/modules.yaml` → `voice.active`. Currently: `voice_evgeny`.

The active voice file is loaded silently by `/new_thread`, `/refactor_thread`, and any future drafting macros — together with `voice_pass_protocol.md` per the contract above. Agents apply the voice's `<voice_fingerprint>` and `<writing_laws>` per its `<final_instruction>` — never narrate the rules in output.

## Files

| File | Purpose |
|------|---------|
| `voice_evgeny.md` | Voice spec for @ogrizkov (canonical). Edited separately; AI never modifies it. |
| `voice_pass_protocol.md` | Cross-module application procedure. Two-pass rule, banned assistant-vocab register, final checklist. Inseparable from any voice file. |

## Conventions

- **Filename has no version number.** When the user has a new voice version, they overwrite the file in place. References elsewhere stay valid.
- **Voice files are read-only for agents.** Modifications happen only via direct user edit.
- **Switching voices:** edit `modules.yaml` directly, or run `/set_voice <voice_name>`.
- **Disabling personalization entirely:** set `voice.active: none` in `modules.yaml`. Drafting macros then fall back to module-default tone (currently undefined; macros will refuse to draft until either voice is set or user supplies inline instructions).

## Future Add-Ons

This folder is also the home for future personalization assets that aren't voice files — e.g., `audience.md` (target reader profiles), `brand_assets.md` (logos, color codes, signature lines). Place them at this level, register in `modules.yaml` if macros need them.

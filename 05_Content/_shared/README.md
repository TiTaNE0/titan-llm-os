# `05_Content/_shared/` — Cross-Cut Drafting Procedure

This folder holds procedure that is **channel-agnostic and account-agnostic** — universal mechanics for how the content pipeline drafts, regardless of who is speaking or which medium it is going to.

## Why this exists

The original `voice_pass_protocol.md` explicitly forbade per-channel duplication: *"No per-channel duplication. No per-channel override."* When the pipeline restructured into the two-axis model (identity in `accounts/`, mechanics in `modules/`), that universal procedure no longer fit cleanly into either axis — channel mechanics are *per channel*, account identity is *per account*, but voice-pass is *per neither*.

`_shared/` is the third axis: vault-wide procedure, single-source, referenced by every module.

## What lives here

| File | Purpose |
|---|---|
| [[_shared/voice_pass]] | The two-pass drafting rule, banned assistant-vocab register, hallway-engineer test, final checklist. Applied on top of the active account's voice file. |

## Rules

1. **Single source.** Files here are never duplicated into modules. If a future channel needs to diverge from a shared procedure, add a sibling file here (e.g. `voice_pass_video.md`) — do not edit the universal file to special-case channels.
2. **Read by every drafting macro.** Step 5 of the resolution chain in [[accounts/README]] — `_shared/voice_pass` runs against every draft, every channel, every account.
3. **Account-blind, channel-blind.** Anything here that references a specific account or channel is a bug.

## See also

- [[accounts/README]] — identity axis
- [[modules/twitter/README]] — channel mechanics example
- [[00_AGENT_GUIDE]] — full drafting operating procedure

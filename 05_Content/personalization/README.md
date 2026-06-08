# 05_Content/personalization/ — DEPRECATED FOR VOICE

> Voice and voice-pass content moved out of this folder on 2026-05-18 as part of the account-segregation refactor. This folder is retained for the audience/brand-assets roadmap items described below; it no longer holds voice content.

## Where things went

| Was here | Now lives at |
|---|---|
| `voice_evgeny.md` | [[accounts/ogrizkov/voice]] (voice is per-account, single source) |
| `voice_pass_protocol.md` | [[_shared/voice_pass]] (universal cross-channel procedure) |
| Voice Application Contract (in this README) | [[00_AGENT_GUIDE]] § 6 |

## Why it moved

The original personalization/ folder mixed two things: account identity (the voice file) and a universal application procedure (voice_pass_protocol.md). The account-segregation refactor split them:

- **Identity is per account.** Each account has its own `voice.md` under `accounts/<account>/`. Selecting voice == selecting account.
- **Application is universal.** The two-pass procedure, banned-vocab register, and hallway test are channel-agnostic and account-agnostic. They live at `_shared/voice_pass.md`, referenced by every module.

See [[accounts/README]] for the full two-axis model.

## Future use of this folder

The original roadmap left room here for personalization assets that are *not* voice: target reader profiles, brand assets (logos, color codes, signature lines). When those land, they should be evaluated against the same two-axis question: is this **per account** (move to `accounts/<account>/`) or **universal** (move to `_shared/`)?

If neither fits — i.e., truly a *meta-personalization-config* that's not voice and not per-account — drop it here. Until then the folder is empty.

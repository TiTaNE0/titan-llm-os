# `05_Content/accounts/` — Identity Axis

This folder holds the **identity axis** of the content pipeline. Every account that publishes from this vault has exactly one subfolder here.

## The two-axis model

| Axis | Lives in | Holds | Per | Rule |
|------|----------|-------|-----|------|
| **Identity** | `accounts/<account>/` | `account.md`, `voice.md`, `channels/<channel>/strategy.md`, `channels/<channel>/analysis/` | account | The account *is* this folder. Voice belongs to the account. |
| **Mechanics** | `modules/<channel>/` | `drafting_partner.md`, `templates/`, `failure_log.md`, `README.md` | channel | Account-agnostic. Written once. Consumed with an `account` parameter. |
| **Cross-cut** | `_shared/` | `voice_pass.md` | vault | Channel-agnostic and account-agnostic. Single source of truth for cross-channel drafting procedure. |

## Core rules

1. **Mechanics live in `modules/`. Identity lives here. No file is duplicated across the two axes.**
2. **Voice is per account, single-source.** One `voice.md` per account. Every channel of that account reads the same file. There is no global "active voice" — there is the active account, whose voice file *is* the voice.
3. **Channels reference, never copy.** `accounts/<account>/channels/<channel>/strategy.md` carries account-specific tactics for that channel (cadence, posting window, follower posture). It never duplicates anything from `modules/<channel>/`.
4. **Templates are scaffolds, not real accounts.** `_account_template/` and `_channel_template/` are copy-from skeletons. Do not point macros at them.

## Resolution chain (what a drafting macro reads, in order)

1. `accounts/<account>/account.md` — identity + never-do list
2. `accounts/<account>/voice.md` — the voice (canonical, per account)
3. `[[_shared/voice_pass]]` — how to apply voice during drafting (universal procedure)
4. `[[modules/<channel>/drafting_partner]]` — channel mechanics (account-agnostic)
5. `accounts/<account>/channels/<channel>/strategy.md` — account-channel tactics
6. `[[modules/<channel>/templates/<Template>]]` — body skeleton

## Adding a new account

1. Copy `_account_template/` to `accounts/<new_handle>/`.
2. Fill in `account.md` (handle, platform handles, status, who/audience/never-do).
3. Fill in `voice.md` (canonical voice for all of this account's channels — written by the account owner, not the AI).
4. For each channel this account publishes on: copy `channels/_channel_template/` to `channels/<channel>/` and fill in `strategy.md`.
5. To make it the default account: edit `05_Content/modules.yaml` → `accounts.default: <new_handle>`.

## Current accounts

- [[accounts/ogrizkov/account|ogrizkov]] — active. Twitter only today.

## See also

- [[modules/twitter/README]] — channel mechanics for Twitter
- [[_shared/README]] — cross-channel drafting procedure
- [[00_AGENT_GUIDE]] — full operating procedure for drafting macros

# Content Pipeline — Agent Operating Guide

> Read this before any content drafting action. It is the single source of truth for how to operate the pipeline. The macros in `03_Brain/System_Agents.md` define individual commands; this guide defines the decision flow, contracts, and error handling an agent needs to execute them correctly.

---

## § 1. Quick Start — Three Questions Before You Write Anything

**1. What channel?**
Determines the `type:` value, the module to load, and the file prefix. See the channel table in § 4.

**2. Is the channel active?**
Read `05_Content/modules.yaml`. Check `active_modules`. If the target channel is not listed there, halt immediately — do not draft. See § 7.

**3. Which account, and is voice loaded?**
Resolve `account`:
- Explicit `for [[Account]]` argument on the macro call → that account.
- Otherwise → `modules.yaml → accounts.default` (= `ogrizkov` today).

Then load **all three** identity+procedure files before writing a single word of content:
- `accounts/<account>/voice.md` — the canonical voice for this account
- `_shared/voice_pass.md` — universal application procedure (two-pass, banned-vocab, hallway test)
- `accounts/<account>/account.md` — identity + never-do list

Skipping any of these causes voice drift. See § 6.

If all three checks pass: proceed to § 3.

---

## § 2. Pipeline Architecture

| File / Path | Purpose |
|---|---|
| `modules.yaml` | Registry: which channels are active, which account is the default for drafting |
| `00_Content_Templates/content_template.md` | Universal frontmatter schema — use for all new drafts |
| `accounts/<account>/account.md` | Identity manifest: who the account is, audience, hard never-do list |
| `accounts/<account>/voice.md` | Canonical voice for the account. Single source. Shared across every channel this account publishes on. |
| `accounts/<account>/channels/<channel>/strategy.md` | Account-channel tactics: cadence, posture, posting windows, goals |
| `accounts/<account>/channels/<channel>/drafting_contract.md` *(optional)* | Account-channel agent contract: binds the drafting partner to this account's voice and gates |
| `accounts/<account>/channels/<channel>/analysis/` | Performance reviews, voice-drift audits, account snapshots for this channel |
| `_shared/voice_pass.md` | Cross-channel drafting procedure (two-pass rule, banned vocab, final checklist). One file, referenced by every module. |
| `modules/<channel>/README.md` | Channel mechanics module manifest |
| `modules/<channel>/drafting_partner.md` | Account-agnostic drafting playbook for the channel (one-round rule, never-fork, output format, workflow) |
| `modules/<channel>/strategy.md` *(legacy)* | DEPRECATED for accounts that have migrated. Account-channel tactics now live in `accounts/<account>/channels/<channel>/strategy.md`. |
| `modules/<channel>/templates/*.md` | Body skeleton for that channel — voice/strategy paths are parameterized by `{{account}}` |
| `03_Drafts/` | All draft output. Flat folder. Prefix-named files. |
| `Content_Board.md` (vault root) | Kanban tracking board. Update Drafting column after every new draft. |

---

## § 3. Step-by-Step: Creating a Draft

1. Identify the channel, topic, and (optionally) account from the user request. If no account specified, use `modules.yaml → accounts.default`.
2. Read `05_Content/modules.yaml`. Verify the channel is in `active_modules`. If not → halt (§ 7).
3. Read `accounts/<account>/account.md` — identity + never-do list.
4. Read `accounts/<account>/voice.md` (the canonical voice).
5. Read `_shared/voice_pass.md` (universal application procedure). These three files together form the inseparable voice contract.
6. Read `modules/<channel>/drafting_partner.md` — channel-mechanics drafting playbook.
7. Read `accounts/<account>/channels/<channel>/strategy.md` — account-channel tactics.
8. If `accounts/<account>/channels/<channel>/drafting_contract.md` exists, read it too (account-channel agent contract).
9. Read the channel body template: `modules/<channel>/templates/*.md`.
10. Read source context from the project and research files referenced in the request.
11. **Pass 1 (internal):** Technical scratch draft. Not emitted. Not shown.
12. **Pass 2:** Rewrite using the account's voice file as generative source. Apply all writing laws. Run the banned-vocab filter from `_shared/voice_pass.md`. Apply the hallway engineer test. Apply gates from the drafting contract (if any).
13. **Emit only Pass 2.**
14. Write the draft to `05_Content/03_Drafts/<prefix>_<kebab-topic>.md` with full universal frontmatter (see § 4).
15. Append `[[[<filename-without-extension>]]]` to the **Drafting** column in `Content_Board.md`.
16. **Halt.** Surface the draft path to the user. Do NOT set `status: ready` — that is user action only.

---

## § 4. File Naming + Frontmatter Schema

### Naming formula
`<prefix>_<kebab-topic>.md`

### Channel table

| Channel | `type:` value | File prefix | Status |
|---------|--------------|-------------|--------|
| X / Twitter | `twitter` | `x_` | active |
| LinkedIn | `linkedin` | `linkedin_` | active |
| TikTok | `tiktok` | `tiktok_` | active |
| Landing page | `landing` | `landing_` | inactive |
| Article | `article` | `article_` | inactive |

**Indexing rule:** `type:` is the absolute source of truth for channel routing. The file prefix is a human visual fallback only. Never derive the channel from the filename. Always read frontmatter.

**Token note:** Use `type: twitter` — matches the module registry key in `modules.yaml`. The file prefix `x_` is a human brand shorthand for the platform name; it is not a data token. Machines read `type:`, not the filename.

### Universal frontmatter block (required on every new draft)

```yaml
---
project: "[Project Name]"
account: "[account_handle]"             # NEW — explicit attribution to the drafting account
type: "[twitter | linkedin | tiktok | landing | article]"
status: "draft"
category: "[feature_or_module_context]"
persona: "[target_audience_segment]"
slug: "[kebab-case-id]"
created: YYYY-MM-DD
---
```

The `account:` field is the explicit attribution — it is the account on whose behalf this draft was written. Downstream publishers read this to route correctly.

**LinkedIn compat note:** LinkedIn drafts must also include `module: linkedin` alongside `type: linkedin`. The anchor workflow (`local_skills/workflows/anchor_workflow.py`) reads `module: linkedin` + `status: ready` to pick up drafts for posting. Do not remove this field from LinkedIn files until the workflow is updated.

---

## § 5. Status Lifecycle

The agent only controls `draft`. Everything beyond that is user or bot territory.

| Status | Who sets it | Meaning |
|--------|------------|---------|
| `draft` | Agent (on creation) | WIP — no automation touches this |
| `ready` | User (explicit action) | Approved for publish workflow |
| `scheduled` | Bot (auto-set) | Locked for posting — do not edit |
| `published` | Bot (on success) | File moved to `04_Published/`; gets `urn` + `published_at` |
| `rejected` | Bot (3 failed attempts) | Needs user investigation |

The agent never sets `ready`, `scheduled`, or `published`. After writing a draft, halt and surface for user review.

---

## § 6. Voice Application Contract (non-negotiable)

**Three files, always loaded together:**
- `accounts/<account>/account.md` — identity + hard never-do list
- `accounts/<account>/voice.md` — what the voice is: fingerprint, rhythm, register, writing laws (per account)
- `_shared/voice_pass.md` — how to apply it: universal two-pass procedure, banned-vocab register, hallway test, final checklist

Voice is per account, single-source. There is no global "active voice" — there is the active account, whose voice file *is* the voice.

**Two-pass drafting:**
- Pass 1: Internal technical scratch. Not shown.
- Pass 2: Full rewrite using the account's voice file as generative source. This is what gets written to disk.

**Before emitting, verify against `_shared/voice_pass.md` § Final Checklist:**
- [ ] No hype hooks or engagement-bait closes
- [ ] Banned vocab filter passed (list in `_shared/voice_pass.md`)
- [ ] ≥ 3 concrete details (filenames, commands, numbers, error strings)
- [ ] ≥ 2 short cutting lines (flat landing)
- [ ] Sounds like builder reporting from floor, not tutorial narrator
- [ ] Hallway engineer test passes
- [ ] Account never-do list (from `account.md`) not violated

If any check fails: rewrite. Do not emit a draft that fails the checklist.

---

## § 7. Inactive Module Guard

If the target channel is in `inactive_modules` (or absent from `active_modules`), halt immediately before touching any file:

> "[channel] module inactive — enable in modules.yaml before running."

Never attempt to draft for an inactive module.
Never silently fall back to a different active channel.
The guard fires even if templates exist — templates are draft infrastructure, not an activation signal.

To activate a module:
1. Move it from `inactive_modules` to `active_modules` in `modules.yaml`
2. Ensure the macro for that channel is fully implemented in `03_Brain/System_Agents.md` (not a TODO stub)

---

## § 8. Channel-Specific Notes

### twitter (X)
- Thread length is scope-driven: big story → 18–25 tweets; specific lesson → 8–12; quick tip → 3–6
- Hook: flat, curiosity-creating, no emojis, no "🚨 thread:"
- Last tweet: long threads end with Article link + flat close; short threads just land flat
- Frontmatter: `type: twitter` — matches the module registry key; file prefix `x_` is separate (human shorthand)
- Channel mechanics: [[modules/twitter/drafting_partner]]

### linkedin
- Keep `module: linkedin` field alongside `type: linkedin` for anchor workflow compat
- Format: no H1 headers, line-break-heavy, 1200–1800 chars, one clear CTA
- Anchor workflow picks up on `module: linkedin` + `status: ready` — do not set ready without user instruction

### tiktok
- Script template: `modules/tiktok/templates/Script_Template.md`
- Hook must land in first 2 seconds. One idea per clip.
- Guard fires if `tiktok` not in `active_modules`

### landing (inactive)
- Copy template: `modules/landing/templates/Landing_Template.md`
- One CTA. Hero block must work standalone without scrolling.
- Guard fires if `landing` not in `active_modules`

### article (inactive)
- No template yet. Guard fires unconditionally until template and macro exist.

---

## § 9. Error Cases

| Situation | Response |
|-----------|---------|
| Channel not in `active_modules` | Halt. Emit inactive guard message. Do not create any file. |
| `accounts/<account>/voice.md` or `_shared/voice_pass.md` not found | Halt. Report missing path. Do not draft without voice. |
| `accounts/<account>/` directory not found for requested account | Halt with E3 (account unknown). Do not silently fall back to default. |
| Draft file already exists at target path | Halt. Do not overwrite. Surface conflict to user. |
| Visual assets required but none in `05_Content/05_Assets/` | Surface warning. Request user provide assets before finalizing. |
| `Content_Board.md` Drafting column parse fails | Log the failure. Manually note the draft path in your response. Do not silently skip the board update. |

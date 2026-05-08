# 05_Content/03_Drafts — Canonical Drafts Folder

> Single location for all content drafts across all modules. Frontmatter `module:` field = machine read. Filename prefix = human read. No per-module `drafts/` subdirectories.

## Why one folder

The LinkedIn anchor workflow already pulls drafts from this folder by reading frontmatter (`module: linkedin` + `status: ready`). Future automations for video, twitter, and article will follow the same pattern. One folder, one rule, scannable on sight, machine-queryable by frontmatter.

The published artifacts move to `05_Content/04_Published/` on success.

## Filename convention

Pattern: `<ModulePrefix>_<kebab-or-snake-name>.md`

**The prefix MUST be at the start of the filename.** Suffix-based naming (e.g., `MyTopic_LinkedIn.md`) is a violation — it sorts wrong, scans wrong, and breaks the visual cluster.

| Module | Prefix | Example |
|---|---|---|
| Twitter / X | `X_` | `X_kimi-recommendation.md` |
| LinkedIn (post) | `LinkedIn_` | `LinkedIn_Stealth_Tripod.md`, `LinkedIn_OpenRouter_Voxtral_404.md` |
| LinkedIn (visual card content) | `Card_Asset_` | `Card_Asset_QA_Automation_Failure.md` |
| Video | `Video_` | `Video_telegram-menu-one-tap.md` |
| Article (future) | `Article_` | `Article_local-first-thesis.md` |

### ❌ Common mistakes (do NOT do this)

| Wrong | Right | Why |
|---|---|---|
| `OpenRouter_Voxtral_404_LinkedIn.md` | `LinkedIn_OpenRouter_Voxtral_404.md` | Prefix-first; suffix breaks alphabetical clustering |
| `MyTopic_X.md` | `X_MyTopic.md` | Same — prefix-first |
| `LinkedIn_OpenRouter_Voxtral_404_v2.md` | use `slug: openrouter-voxtral-404-v2` in frontmatter | Don't encode versions in filename; that's the slug field |

When you adapt a Twitter draft into a LinkedIn post (or vice versa), DON'T tack `_LinkedIn` on. Create a new file with the right prefix, copy the body, set `module:` correctly, link the source via Wiki-Link in frontmatter (e.g., `adapted_from: [[X_OpenRouter_Voxtral_404]]`).

The prefix is **for humans** — it makes the folder scannable when you have 30+ drafts in flight. Machines read frontmatter.

## YAML frontmatter (required)

Every new draft MUST include at minimum:

```yaml
---
module: linkedin           # required: which module owns this draft
status: drafting           # required: drafting | ready | scheduled | published | rejected
slug: stealth-tripod       # required: short kebab-case id
created: 2026-05-08
target_platforms: [linkedin]   # optional list; useful for cross-posting
---
```

Module-specific fields (e.g., LinkedIn's `urn`, `published_at`, `publish_attempts`, `publish_error`) are added by the channel's publish workflow and documented in that module's `templates/`.

## Status lifecycle

Mirroring LinkedIn's canonical states (`05_Content/modules/linkedin/templates/Post_Template.md`):

- `drafting` — work in progress; no automation touches this
- `ready` — user has approved; eligible for module's publish workflow
- `scheduled` — bot has locked the draft (auto-set; don't edit by hand)
- `published` — moved to `04_Published/` after success; gets `urn` + `published_at`
- `rejected` — repeated publish failures; needs user investigation

For LinkedIn this is wired today via `local_skills/workflows/anchor_workflow.py`. For other modules the lifecycle is documented intent — automations are pending (Video drafting pipeline in Backlog; Twitter not yet).

## Legacy files (untouched)

Files that predate this convention coexist alongside new ones. They are NOT renamed because:

- Renames break Wiki-Link references in tasks, logs, archives
- Some are already published or in flight
- The `module:` frontmatter field can be added in-place when the file is next touched

Legacy files include `iCloud_Sync_Implementation_Story.md`, `OpenRouter_Voxtral_404.md`, `Smallest_AI_V31_As_Onboarding_Engine.md`, `close_task_macro.md`. These are Twitter/X drafts by content; treat them as such until they're naturally retired.

## Templates

Each module ships its own template under `05_Content/modules/<channel>/templates/`. Copy the template into this folder under the right prefix-name when starting a new draft. Don't author drafts directly inside `templates/`.

## See also

- `05_Content/personalization/voice_evgeny.md` + `voice_pass_protocol.md` — voice contract every draft inherits (per `personalization/README.md` ⚠ Voice Application Contract)
- `05_Content/modules/<channel>/strategy.md` — channel-specific tactics (length, cadence, format)
- `05_Content/modules/<channel>/failure_log.md` — drift incidents per channel
- `05_Content/modules.yaml` — registry: which modules are active, which voice is loaded

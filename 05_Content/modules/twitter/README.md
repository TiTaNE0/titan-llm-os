---
module: twitter
created: 2026-05-18
---

# Twitter / X Module

## Purpose
Lightweight, high-signal tweet & thread drafting pipeline using the `05_Content` vault system.

## Voice Guidelines
- Short, clear, slightly technical
- Build-in-public + show real gaps/failures
- Prefer concrete examples over hype
- Use natural phrasing (avoid AI smoothing)

## Posting Cadence
- 3–5 tweets per week
- 1 thread every 10–14 days
- Best times: 9:00–11:00 and 16:00–18:00 (UTC+3)

## Frontmatter Rules
- `status`: `draft` → `ready` → `scheduled` → `published`
- `thread`: `true` / `false`
- `scheduled_for`: ISO datetime when known

## Workflow
1. Idea → `01_Content_Ideas.md`
2. Draft → copy template into `03_Drafts/`
3. Refine in Obsidian
4. Set `status: ready`
5. Agent/cron picks it up and posts
6. Move to `04_Published/` with link + metrics

## Related
- [[05_Content/01_Content_Ideas]]
- [[05_Content/02_Content_Calendar]]
- [[modules/twitter/templates/Tweet_Template]]

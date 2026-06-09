---
type: pipeline-artifact
artifact: reply-role-asset
tier: 2
model: "claude-haiku-4-5"
prd_ref: "§4.6"
locked: 2026-06-10
---

# Asset — aurora-frost fill + render

Fill the aurora-frost template for the top 1–2 SHIP drafts; render PNG. Template fill and render only.

## Contract

Reads (ONLY):
- The top 1–2 asset-worthy `{draft + bound entry}` passed by the orchestrator (deterministic selection: top 2 by `engagement.views` from `01_anchored.json` among SHIP drafts — orchestrator selects, Asset does not re-rank).
- Template: `../../../../../../_shared/asset_partners/aurora-frost/insight.html` (default) or `stats.html` if the bound entry has real numbers.

Template tokens:
- `insight.html`: `{{HANDLE}}` `{{TITLE_PLAIN}}` `{{LEAD_LINE}}` `{{QUOTE_LEAD}}` `{{QUOTE_ACCENT}}` `{{QUOTE_TAIL}}` `{{CONTEXT_PARAGRAPH}}` `{{CHIP_1}}` `{{CHIP_2}}` `{{CHIP_3}}` `{{SESSION_NUM}}`
- `stats.html`: `{{HANDLE}}` `{{TITLE_PLAIN}}` `{{SESSION_NUM}}` `{{HERO_VALUE}}` `{{HERO_LABEL}}` `{{STAT_1..4_VALUE/SUFFIX/LABEL/DELTA}}` `{{TITLE_LEAD/ACCENT/TAIL}}` `{{PERIOD}}` `{{PERIOD_NOTE}}`
- `{{HANDLE}}` = `ogrizkov` (the public handle, never the first name).

Writes:
- HTML to `05_Content/05_Assets/reply-<YYYYMMDD>-<batch>-t<N>-<format>.html` (must be that directory — `aurora-frost.css` + `avatar.png` resolve relatively there; matches existing `reply-20260609-*.html` pattern).
- Then the orchestrator runs `../../bin/render_asset.sh <html> <png> 1200x1500`. Exit 3 = non-fatal: keep HTML, note "open + screenshot", continue.

## Must-not-see

Search internals, other targets beyond the top 1–2 passed in, gate internals, `../../../../voice.md`, `../../reply_register.md`.

## Hard boundaries

- Never alter the "Built with Claude" footer or brand DNA.
- Does not re-rank; orchestrator selects which targets arrive.
- `stats.html` only when the bound entry has real numbers (hero + 4 cells). Default is `insight.html`.
- Render failure (exit 3) is non-fatal — HTML is the deliverable; PNG is best-effort.

---
type: pipeline-artifact
artifact: reply-role-producer
tier: 2
model: "claude-haiku-4-5"
prd_ref: "§4.7"
locked: 2026-06-10
---

# Producer — review queue assembly

Assemble `runs/<batch>/replies_to_post.md` from the batch artifacts. Assembles only; never posts.

## Contract

Reads:
- `runs/<batch>/01_anchored.json`
- `runs/<batch>/02_drafts.json`
- `runs/<batch>/03_review.json`

Writes: `runs/<batch>/replies_to_post.md`

Per SHIPPED target — target link, `bound:` label (matching v2 `replies_to_post.md` format; `ground_with` is the JSON field name in `02_drafts.json` — the assembled markdown uses `bound:`), the DRAFT reply, `[VERIFY]` flags, asset html + png paths (or "open + screenshot" if render failed). Per skipped target — target link + `skip_reason` (never silently dropped). All entries marked DRAFT. Shape matches existing v2 `replies_to_post.md` examples in `runs/`.

## Must-not-see

Search internals, `../../../../voice.md`, `../../reply_register.md`, `../../project_authority.md`, asset templates, gate internals.

## Hard boundaries

- Assembles only; NEVER posts.
- `replies_to_post.md` is the single human-review gate — all DRAFT, no exceptions.
- Skipped targets appear with `skip_reason`; nothing is silently dropped.

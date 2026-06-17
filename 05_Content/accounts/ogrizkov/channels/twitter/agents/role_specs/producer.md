---
type: pipeline-artifact
artifact: reply-role-producer
tier: 2
model: "claude-haiku-4-5"
prd_ref: "§4.7, §v3.1.4"
locked: 2026-06-16
---

# Producer — review queue assembly

Assemble `runs/<batch>/replies_to_post.md` from the batch artifacts. Assembles only; never posts.

## Contract

Reads:
- `runs/<batch>/01_anchored.json`
- `runs/<batch>/02_drafts.json`
- `runs/<batch>/03_review.json`

Writes: `runs/<batch>/replies_to_post.md`

Per SHIPPED target — target link, `bound:` label (matching v2 `replies_to_post.md` format; `ground_with` is the JSON field name in `02_drafts.json` — the assembled markdown uses `bound:`), `content_pillar` + `project_pillar` (from `01_anchored.json`), the DRAFT reply, `[VERIFY]` flags, asset html + png paths (or "open + screenshot" if render failed). Per skipped target — target link + `skip_reason`. Per QUARANTINED target — target link + reject history, in a section distinct from skipped (`status: quarantined` in `03_review.json`); quarantined targets are surfaced, never silently dropped. All entries marked DRAFT. Shape matches existing v2 `replies_to_post.md` examples in `runs/`.

## Must-not-see

Search internals, `../../../../voice.md`, `../../reply_register.md`, `../../project_authority.md`, asset templates, gate internals.

## Hard boundaries

- Assembles only; NEVER posts.
- `replies_to_post.md` is the single human-review gate — all DRAFT, no exceptions.
- Skipped targets appear with `skip_reason`; quarantined targets appear with their reject history in a distinct section; nothing is silently dropped.

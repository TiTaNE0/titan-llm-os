---
type: pipeline-artifact
artifact: reply-role-producer
tier: 2
model: "none — bin/produce.py (deterministic script, E13)"
prd_ref: "§4.7, §v3.1.4, v3.2"
locked: 2026-11-23
---

# Producer — review queue assembly and marks (`bin/produce.py`)

The Producer is the script `bin/produce.py`, not a sub-agent: a three-file JSON join removes format drift (R-14) and the false typo flags a model added. Assembles only; never posts.

Command: `python3 bin/produce.py runs/<batch> --budget <budget.json>` (the budget is the JSON of `bin/slot_state.py budget`). Exit 0, or 2 on bad input.

## Contract

Reads:
- `runs/<batch>/01_anchored.json`
- `runs/<batch>/02_drafts.json`
- `runs/<batch>/03_review.json`
- The budget JSON, and the hook short names from the pattern sheet (`reply_patterns.md`, read-only)

Writes: `runs/<batch>/replies_to_post.md` in the v3.2 format of `../schemas.md`: header lines `slot:`, `mode:`, `stage:`, `post_today:` (the number marked recommended), `post_reason:`, `post_short:` (why that is below the budget's `post_today`), `today_more:`, `stage_note:`, `items:`, `critic:`, `calibration:`, `status_line:` (and `status: HELD - DO NOT POST` when held); per delivered item under `### N. URL` the fields `author`, `followers`, `tier`, `mark`, `lane` (large-account items), `type`, `claim`, `bound`, `views`, `posted_at`, `age_min`, `HOOK`, `OPEN`, `QUOTE`, `POINT`, `DRAFT`, optional `YOURS`, `SOURCE` + `BASIS` for a public-source claim, optional `VERIFY`; then `## Skipped` and `## Quarantined`.

## Marks and delivery

- Marks: walks the passed items in rank order and marks an item `recommended` while fewer than `post_today` are marked and the item breaks no posting rule against the items already recommended today and in this mail: one per author a day, `deep_per_day` Deep a day, the stage's `large_per_day` under large accounts. When a large-account item passed, the day's large place is unused and `post_today` is above 0, the best large item is marked first, so the lane is measured. Every other item is `review`.
- Delivery: recommended items first, then review items, each group best first, up to `deliver_cap` items, at most `tiers.large.per_run` large-account items, and each hook id at most once per mail (of two items with one hook the lower-ranked one is left out). Items beyond these caps go to `## Skipped` with `skip_reason: over cap`. Dropped, skipped and quarantined targets are listed with their reasons; nothing is silently dropped.

## Must-not-see

Search internals, `../../../../voice.md`, `../../reply_register.md`, `../../project_authority.md`, asset templates, gate internals.

## Hard boundaries

- Assembles only; NEVER posts.
- Copies `draft`, `answers`, `point`, `hook.instruction` and `yours` byte for byte. Never corrects, annotates or flags draft text; never flags `;` (a `;` inside a contraction is not an encoding artifact). `[VERIFY]` lines come only from `verify_flags`.
- `replies_to_post.md` is the single human-review file; the mail is built from it by `bin/email_replies.py`.

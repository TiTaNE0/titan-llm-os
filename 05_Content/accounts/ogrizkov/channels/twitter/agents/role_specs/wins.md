---
type: pipeline-artifact
artifact: reply-role-wins
tier: 2
model: "none for reads (bin/fetch_posts.py over the public endpoint); Grok — grok -p only as the fallback"
prd_ref: "§4.8, §v3.1.5, v3.2 (DECISION section 3 as amended)"
locked: 2026-11-23
---

# Wins-logger — readings, per-reply log, winners, pattern refresh

Read how his posted replies performed, log them, append winners to `wins.md`. Never drafts, never posts, never emails.

Behavior source: `../../skill/twitter-reply-log-wins.md`.

## Contract

Reads (endpoint first):
- Before delivery: his reply count today comes from `bin/fetch_posts.py reply-count --handle ogrizkov` (no grok call).
- After delivery (maintenance): `bin/measure.py due` names the items that need a 24 h or 48 h reading; `bin/fetch_posts.py my-reply --parent <url> --handle ogrizkov` reads his reply under each (text, counts, the parent's views, the author's answer, his follow-up).
- Fallback only: `grok -p` `from:ogrizkov`, 10 per call, at most `measure.wins_pages_max` pages, within `cost.maintenance_grok_calls`. It is also the only way to collect the `own` arm (his replies outside delivered threads), which is off at launch (`cost.grok_own_arm` false). When neither works, the readings wait for the next maintenance and the reason is logged.
- `../../runs/_analytics/wins.md` — schema + existing entries (dedup check).

Writes: `../../runs/_analytics/reply_log.jsonl` through `bin/measure.py merge`, and `../../runs/_analytics/wins.md` (append only).

## Per-reply log

`bin/measure.py merge --pages <readings.json>` writes one row per reading of a reply he posted (`24h`, `48h`): hook, move, tier, views at capture and the recommended mark copied from the ledger; `parent_views`; `author_answered`; `author_only_corrected` (set by the orchestrator host from the answer text); `followed_up` (he replied again after the author answered; the follow-up is its own row, arm `follow_up`); `added_experience` (his text has a first-person experience phrase the starter did not have); `own_words`, `form`, `replies_that_day`. A delivered item he did not post gets no row. A posted trial item adds a `would_post` mark. Then `bin/measure.py tripwire`. Fields: `../schemas.md` and the spec's D3.

Winners schema in `wins.md` (unchanged):
```
- <date> · <thread topic / @author> · content_pillar:<build|apply|results> · project_pillar:<development|agentic|marketing> · ground_with:<entry id> · angle: <the angle that worked> · engagement: <views / likes / replies / follows> · link:<url>
```
If nothing cleared the bar: `- <date> · no wins this window`.

Then the orchestrator host (same session — never a small model) appends ONE distilled rule per winner: opener type, hook, register, length. The chain is fail → investigate → verify → distill → consult.

## Pattern refresh

When `bin/measure.py due` says `patterns_refresh_due` (every `measure.patterns_refresh_days`, 14), `bin/fetch_posts.py thread --url <u> --all-replies` reads the threads the runs captured in the last 14 days and yields up to `measure.patterns_sample` (40) winners (the author answered, or views far above the other replies in the thread) and 40 controls (replies in the same threads that got little), each with URL, text, views and whether the author answered. The orchestrator host then writes `runs/_analytics/patterns_proposal_YYYY-MM-DD.md`: which hooks of the sheet the winners and controls used, with counts, and any new pattern seen, with examples and URLs. No grok call unless the endpoint fails. The pattern sheet itself is never changed by a run: only the main session changes it, with the operator's knowledge.

## Must-not-see

Drafts for other batches, asset templates, gate internals, `../../../../voice.md`, `../../reply_register.md`.

## Hard boundaries

- Real engagement only: every number from a live endpoint answer or a live grok return. Never invent or estimate; a missing metric stays empty.
- Append, never rewrite, `wins.md` and `reply_log.jsonl`.
- No drafting, no posting, no email.

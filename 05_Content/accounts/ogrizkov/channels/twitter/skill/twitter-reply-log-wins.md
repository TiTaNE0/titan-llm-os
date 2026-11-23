# Skill: twitter-reply-log-wins (maintenance — close the learn-loop)

Runs in MAINTENANCE, after delivery (runbook step 9), or as a separate run by the main session. Reads how his posted replies actually performed, logs every reading in `runs/_analytics/reply_log.jsonl` and appends the real winners to `runs/_analytics/wins.md`. Never drafts, never posts, never emails. Role contract: `../agents/role_specs/wins.md`.

## When to run
Every maintenance. `bin/measure.py due` decides which delivered items need a 24 h or a 48 h reading; running minutes after posting tells you nothing (the 30-min mistake on 2026-06-08).

## Tools (endpoint first; grok only as the fallback)
- Before delivery, for the budget: `python3 bin/fetch_posts.py reply-count --handle ogrizkov` (his replies today; a profile difference, else a partial count).
- `python3 bin/measure.py due` → the items to read.
- `python3 bin/fetch_posts.py my-reply --parent <item url> --handle ogrizkov` per due item → his reply, its counts, the parent's views, the author's answer and his follow-up. Add `"reading": "24h"|"48h"` and, from the answer text, `author_only_corrected` (the host decides; true when the author only corrected him).
- Fallback, only when the endpoint fails: `grok -p` `from:ogrizkov` (10 per call, at most `measure.wins_pages_max` pages, within `cost.maintenance_grok_calls`), shaped like the `my-reply` answers. When neither works, wait for the next maintenance and log the reason.

## Steps
1. `python3 bin/measure.py due`.
2. Read each due item with `fetch_posts.py my-reply`; collect the answers in one JSON list.
3. `python3 bin/measure.py merge --pages <that file>` (dedup by reply URL and reading; no row for an item he did not post).
4. `python3 bin/measure.py tripwire`.
5. For each real win (meaningfully above this account's baseline, not 0–2 views / 0 likes), **append** one line to `runs/_analytics/wins.md` in the file's schema, with pillar, `ground_with` and hook from the ledger. If nothing cleared the bar, append nothing (or one dated `- <date> · no wins this window` line).
6. When `due` says `patterns_refresh_due`: the pattern refresh of `../agents/role_specs/wins.md`.

## Hard rules
- **Real engagement only.** Every number comes from a live endpoint answer or a live grok return; never invent or estimate. If a metric isn't returned, leave it out.
- **Append, never rewrite.** `wins.md` and `reply_log.jsonl` are append-only memory.
- The pattern sheet `reply_patterns.md` is never changed by a run.
- Scripts that need bash run under `/opt/homebrew/bin/bash` (bash ≥ 4).

---
type: pipeline-artifact
artifact: reply-role-scout
tier: 2
model: "Grok (X access) — grok -p"
prd_ref: "§4.1, v3.2 (PENDING_SPEC_REVISION section B: grok only when necessary)"
locked: 2026-11-23
---

# Scout — discovery search only

Live X search → `00_candidates.json`. The Scout does the discovery search only, in at most two grok calls per run (call A: authors; call B: vectors), plus the reserve call for the single widen pass. Every read of a known post (thread snapshots, readings, reply counts) goes through `bin/fetch_posts.py`, not the Scout. Raw retrieval only; no drafting, no ranking prose.

Behavior source: `../../skill/twitter-reply-scout.md` (moves, source honesty), as amended here.

## Contract

Reads:
- Call A: the `authors` list of `../watchlist.json` (small answering authors), and as a second list in the same prompt the `large` list (labs and builders first) for posts under `tiers.large.max_age_min` minutes old.
- Call B: the `scout_vectors_per_run` vector queries from `../../runs/_index/search_vectors.json` in one prompt, topic vectors before project vectors (vectors carry the authority zones from `runs/_index/authority_zones.json`).
- The exclude list from `bin/slot_state.py history --urls` (already delivered).
- English-only.

Writes: `runs/<batch>/00_candidates.json` — array of `{url, author, author_followers, posted_at, views, likes, replies, lang, text_snippet, matched_quote, source, source_tag, post_type}`. Schema: `../schemas.md`. `source` is `watchlist`, `large` or the vector id. `views` on every candidate feeds the momentum signal; `posted_at` (ISO-8601 UTC) and `author_followers` are required: `target_filter.py prefilter` cuts a candidate without them.

Invocation: the orchestrator calls `grok -p` with a brief demanding a SINGLE fenced ` ```json ` block, through `bin/run_traced.sh --timeout`. Every prompt asks for posts no older than its age limit, newest first, with their view counts. The grok budget is `cost.max_grok_calls` in `../params.json` (3 per run).

## Target limits (rule 10)

Applied deterministically by `bin/target_filter.py prefilter` after the Scout returns; the Scout asks for posts inside them so the calls are not wasted:
- Age: under `capture.fresh_min` (90) minutes preferred; 91 to `capture.max_age_min` (210) minutes only when the fresh band yields no passing item; nothing older, and the limit is never widened inside a run.
- Replies: up to `capture.max_replies` (40).
- Tiers: tier 1 authors of 1,000 to 20,000 followers first, tier 2 of 20,000 to 125,000. Under `capture.min_followers` is cut.
- Large-account lane: accounts above 125,000 followers, only posts under `tiers.large.max_age_min` (60) minutes old at capture, no reply-count limit, up to `tiers.large.per_run` delivered items per run.
- Discussion only. Tag promo, listicle, giveaway, "let's connect" (`connect`) and growth-tool sellers (`growth_tool`) honestly in `post_type`; they are cut.

## Thread-context fetch

`bin/fetch_posts.py thread --url U` reads each thread through the public endpoint, in parallel, for the top `cost.thread_fetch_max` survivors, and writes the `00b_threads.json` entries (`opening_post`, `top_replies` with URLs, `engagement`, `captured_at`, `op_replies_in_thread`, `author_followers`, `posted_at`). Only when the endpoint fails and the reserve call is unused does the Scout fetch them: ONE `grok -p` call over all unread URLs → a SINGLE fenced ` ```json ` block in the same shape. Otherwise unread survivors are cut `thread_unreadable`.

This artifact (`00b_threads.json`) IS the Critic's judging snapshot. The Critic never opens a URL; it judges from this snapshot at `captured_at`.

## Must-not-see

`../../../../voice.md`, `../../reply_register.md`, `../../project_authority.md` grounding entries, any drafts, asset templates, `runs/<batch>/01_anchored.json` or later artifacts.

## Hard boundaries

- Raw retrieval + source honesty only (`[X-live]` vs `[hypothesis]`).
- No drafting, no ranking prose, no match judgments.
- Tag `post_type` at retrieval from what the post visibly is; prefer genuine discussion (`discussion` / `question`).
- English-only: drop non-English posts before output.
- Widen: exactly one widen pass per run (`thin_run.widen_passes`), only when fewer than min(`thin_run.widen_below`, `deliver_cap`) items passed after all bound candidates, time remains before the send cut-off and the reserve call is unused: one discovery call with unused query seeds and the `target_filter.py authors` list; same limits, same gates.
- A failed grok call is not repeated beyond the budget. "402 ... balance exhausted" stops the run (`grok_balance`).

# Skill: twitter-reply-scout (Run 1 — daily feed)

Grok Build runbook. **Run 1 of 2.** One cheap `search_x` pass that produces the daily
reply-target **feed** + an analytics read. Writes one readable file, then **exits**. It
never drafts and never posts. (Reconciled 2026-06-08 to match the flow actually in use —
analytics + scout combined into a single feed; the earlier "01_candidates.json + human
anchor field" design is retired.)

## Tools
- `search_x` (live X retrieval + can read own-account post metrics)
- `search_web` (optional enrichment)

## Read first (context)
- `../strategy.md` — niches + positioning
- `../../voice.md` — account-level voice (`accounts/ogrizkov/voice.md`)
- newest file in `../analysis/` — what has converted historically

## Steps
1. **Analytics.** `search_x` for `from:ogrizkov` over ~30 days; read public engagement
   (likes/views/replies). Note which topics/angles convert. Don't invent numbers — if a
   metric isn't returned, say so and fall back to the `analysis/` file.
2. **Scout (recent only).** `search_x` the niches (agentic workflows, Claude Code / Grok
   Build, agent memory, local-first LLMs, builder experience), constrained to the **last
   24–48h**. Use the recency filter if the tool has one.
3. **Recency gate + rank.** Drop anything older than 48h by real post timestamp (not
   snowflake ID alone). Rank survivors by: niche relevance (NOT follower count) + recency +
   **reply-opportunity** (down-weight huge broadcast accounts where a reply drowns; favor
   mid/small conversational accounts that reply back) + fit to the converting angles from
   step 1. Drop spam/bots.
4. **Write the feed** to `runs/<YYYY-MM-DD>_batch/reply_feed.md` (readable markdown):
   - **Analytics notes** — converting angles to favor.
   - **Top 8–12 targets** — each: URL, author, post age, one-line "why reply here", one-line
     suggested angle in my lane. (Targets only — do NOT write the reply.)
   - **Reject list** — what was filtered and why (stale / broadcast / off-niche / spam) so I
     see what NOT to reply to.
5. **Exit.** Print the path. No drafting, no posting, no waiting.

## Hard rules
- **Recency is mandatory:** only threads from ~the last 24–48h. A stale thread is a dead
  reply target — drop it no matter how relevant.
- `relevance_score` / ranking reflects topical signal + reply-opportunity, never follower count.
- Terminate after writing the feed. Stateless. No drafts, no replies, no posting.

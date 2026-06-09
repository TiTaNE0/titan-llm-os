# Skill: twitter-reply-log-wins (Run 3 — close the learn-loop)

Grok Build runbook. **Run 3 of 3 (optional, after posting).** Reads how the recently-posted replies
actually performed and appends the real winners to `runs/_analytics/wins.md` — the LEARN source that
Run 1 (Scout, Move 3) reads. This is the half that makes learning real instead of guessing from
prior feeds. Writes only `wins.md`; never drafts, never posts.

## When to run
A day or more after a batch is posted — engagement needs time to accrue. Running it minutes after
posting tells you nothing (that was the 30-min mistake on 2026-06-08).

## Tools
- `search_x` — read `from:ogrizkov` recent replies + their public engagement (views/likes/replies/
  follows where visible).

## Read first
- `../runs/_analytics/wins.md` — the schema + what's already logged (don't duplicate a line).
- the relevant `../runs/<date>_batch/replies_to_post.md` — what was actually posted, with each
  reply's bound `project_authority` entry (`ground_with`) and pillar, so a win is tagged correctly.

## Steps
1. `search_x` `from:ogrizkov` over the window since the batch posted; pull each posted reply's real
   engagement.
2. Keep only the ones that **actually performed** — meaningfully above this account's baseline
   (not 0–2 views / 0 likes). A reply that flatlined is not a win; log nothing for it.
3. For each real win, **append** one line to `runs/_analytics/wins.md` in the file's schema:
   `- <date> · <thread topic / @author> · pillar:<...> · ground_with:<entry id> · angle: <what
   worked> · engagement: <views/likes/replies/follows> · link:<url>`. Pull pillar + `ground_with`
   from the batch's `replies_to_post.md` so the win is attributed to the right project entry.
4. If nothing cleared the bar this window, append nothing (or one dated `- <date> · no wins this
   window` line). Honest emptiness beats a fake win.

## Hard rules
- **Real engagement only.** Every number comes from a live `search_x` return; never invent or
  estimate. If a metric isn't returned, leave it out.
- **Append, never rewrite.** `wins.md` is an append-only memory; don't edit or delete prior lines.
- Only writes `runs/_analytics/wins.md`. No drafting, no posting, no other files.
- `gate.sh` requires bash ≥ 4 — not used here, but the same modern-bash rule applies to any helper.

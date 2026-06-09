# Skill: twitter-reply-scout (Run 1 — daily feed)

Grok Build runbook. **Run 1 of 2.** Produces the daily reply-target **feed**, then exits.
Stateless: read inputs, do the three moves, write one file, exit. (Never drafts, never posts.)

## The deal — what the Scout is for (three moves, in order)

1. **DISCOVER** — find what is hot on X right now.
2. **MATCH** — match those hot threads to our own vault experience (`project_authority.md`, 3 pillars).
3. **LEARN** — consult our history (past feeds + the logged analytics of what actually performed)
   and bias toward what works for us.

Output = a ranked feed of **live, groundable** threads. That's the whole job.

## What we need as OUTPUT (the contract — everything else serves this)

Write `runs/<YYYY-MM-DD>_batch/reply_feed.md`:

- **Header** — date, tools used.
- **Analytics summary** — what is converting for us, drawn ONLY from `runs/_analytics/wins.md` +
  genuinely-engaged own posts + `analysis/`. **If `wins.md` is empty, keep this summary SHORT — a
  few lines, not a wall:** state plainly that what converts is unknown (no performance data yet),
  give the bias in one line (pick live + groundable + varied; log results to `wins.md`), and at most
  one line of historical signal from `analysis/`. **Do NOT reproduce the long per-pattern
  "converting angles" list** — with no wins logged it is just prior-feed vocabulary masquerading as
  guidance. When `wins.md` HAS entries, drive the summary from those real outcomes instead.
- **Targets — aim 8–12 (reached by widening Discover, see Move 1 — NOT by padding), ranked** — return
  the live + groundable survivors; reach 8–12 by searching harder, never by padding with dead posts;
  fewer only if the window is genuinely exhausted after real widening (say so). Each carries:
  - `url` · `author` · `age`
  - `engagement` — views / likes / replies + **velocity**: the rate over time since the post
    (climbing vs flat). The rate, not the absolute count, is the liveness evidence.
  - `found_via:` hot-discovery | domain-match | history-pattern
  - `pillar:` dev | agentic | marketing · `touches:<project>` · `ground_with:<project_authority entry id>`
  - `why_live` (one line) · `suggested_angle` (one line, our lane)
- **Reject notes** — brief: what we passed over + the one-word reason (stale / dead / drowned / off-niche / ungroundable).

## Inputs to read first

- `../project_authority.md` — our vault experience across 3 pillars (Development / Agentic /
  Marketing). This is the MATCH source; its entry IDs go in `ground_with`.
- `../runs/_analytics/wins.md` — logged best-performing threads/angles. The LEARN source, filled by
  the `twitter-reply-log-wins` step (Run 3) after posting.
- prior `../runs/*/reply_feed.md` — what we already searched and targeted (learn the patterns,
  skip exact repeats).
- newest `../analysis/` — historical account review.
- `../strategy.md`, `../../voice.md` — positioning + voice. Ground only in the projects' technical
  substance.

## Move 1 — Discover what's hot (live, last 24–48h) — LOOP until 8–12, English only

Read the live frontier broadly via `search_x`. Surface high-velocity threads across all of AI —
**any lab, model, tool, release, or debate that is genuinely hot today, discovered live** (the
frontier moves weekly; find it, don't match a fixed list). In the same pass, search the domains we
build in, using the per-pillar vocabulary in `project_authority.md`:
- dev: Java / Spring / microservices, Next.js / PWA / offline-first, iOS / Swift, API-contract drift, TTS / local inference.
- agentic: agent-agnostic orchestration, AGENTS.md / CLAUDE.md, MCP, Claude Code / OpenCode / Codex / Grok Build, context injection, agent memory, error recovery, sub-agents, plan-first, brain/runner split.
- marketing: multi-agent content pipeline, AI influencers, faceless + UGC / AI-character / AI-avatar content, growth automation, stealth / anti-detection, cross-family eval, short-form craft.

We want threads with momentum and an audience.

**English only.** Target posts must be in English (use `lang:en` and/or check the candidate). An
English reply under a Turkish / Japanese / Spanish thread reads out of place — drop non-English posts.

**This is a LOOP, not one pass.** The goal is **8–12 live + groundable targets**. If a pass yields
fewer after the Liveness gate, **widen and go again**: more `search_x` queries on the pillar vocab,
then adjacent AI topics we can still ground on (the broad agent / LLM / dev frontier), then deeper
paging — and keep going until you have 8–12. There is no real scarcity of in-niche threads in 24–48h;
~4 means you under-searched, not that the field is empty. **Volume comes from searching harder, never
from lowering the bar** — the Liveness floor stays intact and you never pad with corpses. Settle for
fewer only if the window is genuinely exhausted after real widening, and then say so explicitly
("widened N times, only M live this window").

**Then filter the pool through the Liveness gate (below) BEFORE matching** — only live survivors proceed.

## Move 2 — Match to vault experience

For each live thread, find the `project_authority.md` entry that lets us make a **real, specific
contribution** — a take only the builder of these projects could give. Tag each with `pillar`,
`touches`, and the `ground_with` entry ID. Groundability **ranks the live survivors** — it never
rescues a dead thread. A perfectly groundable corpse is still a corpse: it does not enter the feed.

## Move 3 — Learn from our history (two sources, never conflate them)

- **`wins.md` + `analysis/` = what converts.** These carry real engagement outcomes. Bias toward the
  topics/angles/thread-shapes logged here. **If `wins.md` is empty, what converts is unknown — say so
  and do not substitute a guess.**
- **Prior `reply_feed.md` files = memory of what we already touched.** Use them ONLY to avoid
  re-targeting the same posts and to see which topics we've already covered. They are **not** a
  source of "converting angles" — a thread appearing in past feeds means we *targeted* it, not that
  it *worked*. Never lift recurring prior-feed vocabulary and present it as proven.

## Liveness gate (HARD — runs on the discovered pool BEFORE matching/ranking)

A good target is a live thread with momentum. Apply this as a hard filter, not a tiebreaker:
- **Reject corpses outright.** A thread older than ~2h with near-zero reach (<~50 views, 0 replies,
  0 likes) is dropped — no matter how groundable. Groundability does not rescue a dead thread.
- **Fresh ≠ live (tightened).** A minutes-old low-view post qualifies ONLY with a concrete reason:
  the author has **real reach** (followers / typical engagement) OR the post is demonstrably on a
  **hot wave**. "Zero competition" or a bare "builder bio" is **not enough** on its own — without
  real reach or wave heat, a fresh low-view post is a guess, not a target.
- **Keep** threads with **velocity** (views/replies climbing over time), ideally an active
  back-and-forth, in the middle band — seen, not drowned in a mega-thread.
- **Rank by velocity + reply-opportunity.** A smaller thread that's climbing outranks a larger flat
  one. And a thread where the **OP replies back** / there's a live back-and-forth ranks above a
  same-size thread with 0 replies — for a small account the conversation and thread-climb are the
  value, not raw impressions.

## Source honesty (output quality)

Every signal carries where it came from: `[X-live]` (a real returned post) or `[hypothesis]` (your
inference). Engagement numbers go only on `[X-live]`. A search that returns nothing is reported as
such, so the feed shows what was measured vs. inferred.

## Finish (self-audit, then write)

Before writing, re-check every kept target against the Liveness gate and **drop any corpse that
slipped through** (>2h old with <~50 views / 0 replies / 0 likes fails — remove it, even if it's
groundable). Confirm you did not pad the list to hit a count. Then write the feed, print its path, exit.

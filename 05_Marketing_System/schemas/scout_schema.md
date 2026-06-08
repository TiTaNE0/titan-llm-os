---
type: pipeline-artifact
artifact: scout-output-schema
prd_ref: "§9, §8.3, §8.6, §12.5-Tier3"
locked: 2026-06-01
---

# Scout Output Schema + tool rules

The Scout writes ONE structured file per run into the run folder (`runs/<date>_run<NN>/00_scout.md`). **Field-based, not prose** — the structure IS the tone-firewall (§8.6): there is no tone to leak, only data. A chatty Scout poisons downstream voice.

## Sources — one tool per walled platform (§8.3)
- **X / web → Grok** (`grok-4.3`, provider `xai-oauth`): native X/web read. Mandatory; nothing else sees the X wall.
- **TikTok → Apify** (`clockworks/tiktok-scraper` search/hashtag via the `apify` MCP `call-actor`): trending videos, hashtags, engagement, competitors. Primary trend source for this TikTok-first campaign. **Apify TikTok actors are volatile — any `clockworks/tiktok-*` can be deprecated or break at any time (e.g. `tiktok-trends-scraper` died when TikTok killed the Trends page); verify the actor works before trusting its output, and try a maintained alternative if it fails (SKILL Step 1).**
  - **Fallback (§8.3):** if scrape cost runs hot or the actor fails/returns 0, operator pastes TikTok Creative Center / FYP trends into the findings — same manual pattern as analytics. A failed scrape is **FLAGGED, never silently skipped** (TikTok signals then carry the unavailability line + `[hypothesis]` tags; `validate_scout_schema.sh` enforces this, exit 4).
- The Scout **normalizes both sources into the one schema below**, regardless of which tool produced a signal.

## Output schema (the contract)

```markdown
# Scout Findings — Intuiscale — [Date]

## Trend verdict vs CANON
- verdict: ALIGNED | DRIFT | BREAK
- basis: [what the verdict rests on — e.g. "X-live + hypothesis; TikTok unmeasured this run"]
- reasoning: [1–2 lines]

## Top trending signals (per channel)
- channel: [TikTok|X|...]
  - source: [TikTok-scraped | X-live | hypothesis]   # MANDATORY on every signal
  - signal: [short]
  - engagement: [metric/number — ONLY if source is TikTok-scraped or X-live; for hypothesis write "no live data"]
  - example: [link — real for scraped/live; "none — inferred" for hypothesis]

## Winning format + voice per (channel × audience)
- audience: [segment — from CANON]
  channel: [channel]
  format: [what wins now]
  voice: [tone that performs — DERIVED, not the operator's]

## Winning visual pattern (abstracted across MANY niche winners — NEVER any single creator's image)
> The asset look LEADS with this native grammar (a promotional asset must feel native to win; a brand-polished look reads as an ad and loses). Pattern abstracted across many winners — reproducing one specific post's actual image / unique framing is FORBIDDEN. Source-tag like every signal.
- source: [TikTok-scraped | X-live | hypothesis]   # format/text evidence is usually scraped; exact color/light grade is often hypothesis
- mode: [real-photo phone-shot / illustrated / 3D — what the winners actually use]
- composition: [framing tendency — e.g. first-person POV, handheld, close, off-center, real-life clutter]
- lighting: [e.g. available natural daylight, unstyled, soft]
- color_temperature: [e.g. warm natural / cool / high-contrast]
- text_treatment: [on-image text density + style — e.g. minimal lowercase native captions, sparse, emoji-ok]
- aesthetic: [one-line feel — e.g. lived-in, "filmed on a phone", anti-polished]

## Audience pain points → hook angles
- pain: [..] → hook: [..]

## Competitor insights
- [who] does [what] well/poorly

## Recommended content directions (3–5)
1. [title] — why it fits — channel — format
```

## Source honesty (MANDATORY — every signal is sourced, no untagged claims)
Every signal MUST carry a `source:` tag. The tag is the difference between a measured finding and a guess:
- **`[TikTok-scraped]`** — from a live Apify result.
- **`[X-live]`** — from Grok's live X/web tools.
- **`[hypothesis]`** — inferred from general knowledge / cross-channel reasoning, with **NO live source**.

Hard rules:
- **Engagement numbers (views, likes, saves, …) may appear ONLY on `[TikTok-scraped]` or `[X-live]` signals.** A `[hypothesis]` signal states the hypothesized angle and writes **"no live data"** — it must NOT carry invented metrics ("millions of views"). Fabricating numbers on a hypothesis is a violation.
- **When the Apify scrape returns 0 / is unavailable**, the Scout writes one explicit line above the TikTok signals: *"TikTok scrape unavailable (<reason>) — TikTok signals below are `[hypothesis]`, not measured,"* and tags every TikTok signal `[hypothesis]`. **Never present inferred TikTok trends as observed ones.**
- **The verdict's `basis:` states what it rests on.** If TikTok is hypothesis-only, the verdict reflects `[X-live]` + `[hypothesis]`, not measured TikTok signal.

This does not reduce Grok's value — real `[X-live]` scans read as facts and stay trusted downstream. It only stops unsourced TikTok guesses from being dressed as measured trends. Once Apify is funded, `[TikTok-scraped]` signals slot in under the same tagging.

## Rules
- `audience` values come from CANON (operator-set); the Scout derives *voice/format/hook*, never the audience itself.
- `verdict`: ALIGNED → continue; DRIFT → adapt execution (hero/manifest hold); **BREAK → HALT + notify operator** (human gate #1).
- Every signal carries a `source:` tag (above) AND, for `[TikTok-scraped]`/`[X-live]`, a real `example` link; `[hypothesis]` signals carry `example: none — inferred`. A failed/0-result scrape is FLAGGED, never silently skipped.
- Output is data for the Strategist; no recommendations beyond the 3–5 directions.

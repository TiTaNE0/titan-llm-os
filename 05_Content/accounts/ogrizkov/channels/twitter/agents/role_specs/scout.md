---
type: pipeline-artifact
artifact: reply-role-scout
tier: 2
model: "Grok (X access) — grok -p"
prd_ref: "§4.1"
locked: 2026-06-10
---

# Scout — raw X retrieval

Live X search → `00_candidates.json`. Raw retrieval only; no drafting, no ranking prose.

Behavior source: `../../skill/twitter-reply-scout.md` (3 moves, liveness gate, source honesty, widen loop).

## Contract

Reads:
- Search topics: broad hot AI + the 3-pillar domain vocab from `../../project_authority.md` (vocab only — NOT the grounding entries themselves, not voice/register).
- 24–48h window, English-only.
- `../../runs/_analytics/wins.md` — LEARN signal (what converted).
- Prior `../../runs/*/replies_to_post.md` — dedup (what we already targeted).

Writes: `runs/<batch>/00_candidates.json` — array of `{url, author, age, views, likes, replies, lang, hot|domain, text_snippet, source_tag, post_type}`. Schema: `../schemas.md`.

Invocation: orchestrator calls `grok -p` with a brief demanding a SINGLE fenced ` ```json ` block. Widen-loop cap = 3 passes, then proceed with however many survived; emit loud "widened N times, only M live this window".

## Thread-context fetch (batched, post-shortlist)

When the orchestrator passes the Matcher's liveness-survivor URL list, fetch thread context for ALL
survivors in ONE `grok -p` call → a SINGLE fenced ` ```json ` block → `runs/<batch>/00b_threads.json`.
Read the opening post in full (not the 280-char snippet) plus the highest-signal replies (the
reveal / answer / punchline). Raw retrieval only — no drafting, no match judgment. Set `replyable: false`
for polls/memes/promos with no substantive discussion to join.

## Must-not-see

`../../../../voice.md`, `../../reply_register.md`, `../../project_authority.md` grounding entries, any drafts, asset templates, `runs/<batch>/01_anchored.json` or later artifacts.

## Hard boundaries

- Raw retrieval + source honesty only (`[X-live]` vs `[hypothesis]`).
- No drafting, no ranking prose, no match judgments.
- Tag `post_type` at retrieval from what the post visibly is.
- English-only: drop non-English posts before output.
- Widen loop: if survivors <8 and passes <3, widen and re-scout. Cap at 3 passes then proceed.

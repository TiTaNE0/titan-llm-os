---
type: pipeline-artifact
artifact: reply-role-critic
tier: 2
model: "non-Claude — grok -p (gpt-5.5 = future swap; its CLI pattern does not exist in this vault)"
prd_ref: "§4.4"
locked: 2026-06-10
---

# Critic — cross-family veto (live-read)

Refute drafts against Rubric v1.1, judged against the CURRENT live thread. Ships only what survives every criterion.

Mandate: REFUTE, don't grade gently. The drafter is a pathological optimist about its own output. Per-criterion verdict, not one vibe score.

Why non-Claude: a model grading its own family's output is a blind spot. The cross-family veto is load-bearing (PRD §10, §11); what's load-bearing is independent context + refute mandate.

Live-read, not gist-read: the judging basis is the post as it is NOW, opened from its URL — not the stored gist. The gist that may have misled the writer is never the artifact that clears the writer.

## Contract

Model/invocation: unchanged — non-Claude `grok -p`, one call per draft or one batched call over the surviving set (mirroring `../../runs/2026-06-10_batch/critic_prompt.txt`).

Reads (isolated per draft):
- The draft
- The target URL — which the Critic OPENS and reads LIVE; the live thread is the judging basis
- `thread_gist` — passed ONLY as "what the drafter believed" cross-reference, never the judging basis
- The bound entry's claim as `grounded_claim` (NOT full `project_authority.md`)
- Rubric v1.1 (below)

## Invocation prompt template

Following `../../runs/2026-06-10_batch/critic_prompt.txt`: a hostile critic with live X access. For each
draft: OPEN the post URL, read the live thread, catch where the stored gist misled or went stale, refute
(don't grade gently), never rewrite. Output ONE fenced ` ```json ` block only, no prose outside it.

Inputs per draft: `url`, `snippet_the_writer_saw` (the stored gist — NOT the judging basis), `grounded_claim`, `claimed_contribution` (the Matcher's thread-perspective contribution sentence — thread_fit also fails if the draft does not deliver it), `DRAFT`.

Output per draft: `{n, url, post_actually_about (from the LIVE read), voice_fit, specificity_present, no_fabrication, not_generic, length_register_sane, thread_fit, verdict: "SHIP" | "FIX:<failed criterion>"}`.

## Must-not-see

Full `../../../../voice.md`, `../../reply_register.md`, full `../../project_authority.md`, other drafts in the batch, gate internals. Judges output against the rubric, not the process.

Writes: each draft's verdict appended to `runs/<batch>/03_review.json` — fenced JSON: `{url, post_actually_about, critic_verdict: "SHIP"|"FIX:<one line naming the failed criterion>", critic: "grok"}`. `post_actually_about` MUST come from the live read — it is the audit trail that the URL was opened.

## Rubric v1.1

Six individually-gradeable criteria, judged against the LIVE thread. A draft ships only if it passes ALL SIX:

1. **voice_fit** — flat opener, no hype/hooks/engagement-bait, lands flat. Fails if the opener performs excitement or begs for a like.
2. **specificity_present** — ≥1 concrete signal (number / named tool / proper noun) tied to the bound entry. Fails if the reply could have been written without reading the entry.
3. **no_fabrication** — every concrete claim traces to `grounded_claim`. Fails if it distorts that claim or claims the author's numbers/experience as the replier's. No personal-life or employment details invented. Fails on any untraced claim.
4. **not_generic** — a take only the builder of these specific projects could give. Fails if a random developer could post the same reply.
5. **length_register_sane** — short norm; register imperfection (lowercase opener, dropped period) is minority and never touches the concrete signal. Fails if the reply is padded or register chaos drowns the point.
6. **thread_fit** — judged against the LIVE thread. Fails if the reply's substance could have been written without reading the live thread — answers only the snippet, ignores the thread's real ask/reveal, or pivots toward the author's own projects (2026-06-10 t13: the reveal was in the replies, not the opening post). Sub-clauses, all part of thread_fit (not a 7th criterion):
   - **still_alive** — post exists, public, not deleted/locked, and the moment has not passed.
   - **redundancy** — FIX if the same point already sits in the live replies.
   - **drift** — the thread may have evolved since the 3.5 fetch; judge against the thread as it is NOW.

## Phase-1 stub

The stub exists ONLY for scaffold tests. When it runs it sets `critic: "claude-stub"` and emits the loud
"no cross-family veto this run" flag; on any production batch it touches it MUST set `cross_family_veto: false`
and force `held: true`. It is NEVER a runtime fallback — a missing Phase-2 critic ABORTS the batch (see
Degradation rule), it does not silently revert to the stub.

## Degradation rule

If the Phase-2 grok critic cannot be invoked mid-run, ABORT: all results `status: "held"`,
`critic: "UNAVAILABLE"`, and emit a loud held-line. No silent stub revert. (2026-06-10: the stub
shipped 13/13 content-irrelevant drafts as SHIP — proof the stub is not a safe fallback.)

## Hard boundaries

- Scores; never rewrites.
- Output is fenced JSON only — no prose wrap around it.
- Cross-family is the mechanism: keep this role on a non-Claude model (Phase 2+).

---
type: pipeline-artifact
artifact: reply-role-critic
tier: 2
model: "non-Claude — grok -p (gpt-5.5 = future swap; its CLI pattern does not exist in this vault)"
prd_ref: "§4.4, §v3.1.4"
locked: 2026-06-16
---

# Critic — cross-family veto (live-read)

Judge drafts against Rubric v1.3, against the CURRENT live thread. Ships what a sharp builder would actually post.

Mandate (v1.3 — recalibrated): be a FAIR judge, not a reflexive refuter. SHIP a reply that genuinely
engages the thread and is grounded, even if it is not perfect. Fail a criterion ONLY on a **material**
problem — off-topic, fabrication, could-be-posted-by-anyone, performs hype — never on a stylistic
preference or a nitpick. Per-criterion verdict, not one vibe score. (History: the prior pure-refute
mandate rejected acceptable drafts and invented a NEW objection on every re-judge — that drift is the
miscalibration this version fixes. The 2026-06-10 stub failure is the opposite ditch; this rubric is the
fair middle: two real hard gates, the rest advisory.)

Cross-pass stability: when re-judging a revised draft, judge it FRESH and FAIRLY — do not hunt for a new
reason to fail a draft that fixed the reason you gave last time. If the named fix landed, say so.

Why non-Claude: a model grading its own family's output is a blind spot. The cross-family veto is load-bearing (PRD §10, §11); what's load-bearing is independent context + a fair-but-real bar.

Live-read, not gist-read: the judging basis is the post as it is NOW, opened from its URL — not the stored gist. The gist that may have misled the writer is never the artifact that clears the writer.

## Contract

Model/invocation: unchanged — non-Claude `grok -p`, one call per draft or one batched call over the surviving set (mirroring `../../runs/2026-06-10_batch/critic_prompt.txt`).

Reads (isolated per draft):
- The draft
- The target URL — which the Critic OPENS and reads LIVE; the live thread is the judging basis
- `thread_gist` — passed ONLY as "what the drafter believed" cross-reference, never the judging basis
- The bound entry's claim as `grounded_claim` (NOT full `project_authority.md`)
- The target's `content_pillar`
- Rubric v1.3 (below)

## Invocation prompt template

A FAIR cross-family judge with live X access (v1.3). For each draft: OPEN the post URL, read the live
thread, catch where the stored gist misled or went stale, judge against the v1.3 bar (ship what a sharp
builder would post; fail only material problems; confidence-gate per the rubric), never rewrite. Output
ONE fenced ` ```json ` block only, no prose outside it.

Inputs per draft: `url`, `content_pillar`, `snippet_the_writer_saw` (the stored gist — NOT the judging basis), `grounded_claim`, `claimed_contribution` (the Matcher's thread-perspective contribution sentence — thread_fit fails only if the draft adds nothing additive to the live thread), `DRAFT`.

Output per draft written to `runs/<batch>/03_review.json`:

```
{
  "url": "<url>",
  "post_actually_about": "<from the LIVE read>",
  "criteria": [
    {"criterion": "voice_fit", "verdict": "pass", "confidence": 0.9, "reason": "<one line>"},
    {"criterion": "specificity_present", "verdict": "pass", "confidence": 0.85, "reason": "<one line>"},
    {"criterion": "no_fabrication", "verdict": "pass", "confidence": 0.95, "reason": "<one line>"},
    {"criterion": "not_generic", "verdict": "pass", "confidence": 0.8, "reason": "<one line>"},
    {"criterion": "length_register_sane", "verdict": "pass", "confidence": 0.9, "reason": "<one line>"},
    {"criterion": "thread_fit", "verdict": "pass", "confidence": 0.85, "reason": "<one line>"},
    {"criterion": "positioning_alignment", "verdict": "pass", "confidence": 0.8, "reason": "<one line>"}
  ],
  "critic_verdict": "SHIP",
  "critic": "grok"
}
```

`critic_verdict` is `"SHIP"` or `"FIX:<criterion>"` naming the first failed hard gate, or the failed criterion if soft.

Confidence is ORDINAL — a triage/sort signal (which reject is it least sure about → quarantine vs escalate routing), NEVER overrides a hard gate; the criterion verdict governs ship/no-ship.

`post_actually_about` MUST come from the live read — it is the audit trail that the URL was opened.

## Must-not-see

Full `../../../../voice.md`, `../../reply_register.md`, full `../../project_authority.md`, other drafts in the batch, gate internals. Judges output against the rubric, not the process.

## Rubric v1.3

Seven criteria in two tiers, judged against the LIVE thread. **Confidence-gate:** a criterion only
counts as failed when you are genuinely confident (confidence ≥ 0.65); a low-confidence misgiving is a
`pass` with a noted reservation, never a kill. Verdict logic:

- **SHIP** when no HARD gate fails (≥0.65) AND no ADVISORY criterion fails egregiously (≥0.80).
- **FIX:<criterion>** otherwise, naming the single most important failed criterion.

### HARD gates (these two genuinely block a SHIP)
- **no_fabrication** — every concrete claim traces to `grounded_claim`. Fails if it distorts that claim, claims the author's numbers/experience as the replier's, invents personal/employment detail, or makes an untraced factual claim. (This is the one that protects credibility — keep it strict.)
- **thread_fit** — the reply engages what THIS live post is actually about, AND the post is a genuine **discussion/question** (not a launch/promo). It PASSES if, on a discussion/question thread, the reply adds ONE genuine builder data point, a grounded take, or a sharp on-topic question — even if the topic overlaps the post, and even if it references the replier's own experience as evidence. It FAILS if: **the post is a product launch / announcement / showcase / promo** (replying there is congratulation or a self-promo hijack, not joining a discussion — these should be filtered upstream by the Matcher's replyability gate; if one reaches you, fail it, unless a genuine technical debate has formed in the replies that the draft actually joins); or the reply ignores what the post is about, answers only the stale snippet, is pure self-promo/pivot with no value to the OP, is a *verbatim* duplicate of a top reply, or the post is dead/locked. Do NOT fail merely because the reply doesn't address every sub-point.

### ADVISORY (fail a SHIP only if EGREGIOUS, confidence ≥ 0.80; otherwise note and pass)
- **voice_fit** — broadly flat, no hype/engagement-bait. A mildly editorial opener ("X is the move", "what I'd watch is…") is FINE — fail only on genuine hype, emoji-bait, or a like-begging hook.
- **specificity_present** — has ≥1 concrete signal (number / named tool / proper noun). Fail only if the reply is pure abstraction.
- **not_generic** — fail only if a random developer with no specific project could post the identical reply. A grounded, specific reply that happens to be broadly useful is NOT generic.
- **length_register_sane** — fail only if padded or if register chaos drowns the point.
- **positioning_alignment** — reads like an active builder/user of agentic systems. Fail only if it reads like a pure spectator, or a results-pillar reply leans on vanity metrics instead of a build/process number.

The drafter gets ONE chance to fix an advisory miss (it routes back as a style fix, not a kill — see orchestrate §v3.1.4); only the two HARD gates drive bind-bad/quarantine.

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

## Telemetry

One line per draft via `bin/run_traced.sh`:

```
bin/run_traced.sh --role critic --model grok --provider xai
```

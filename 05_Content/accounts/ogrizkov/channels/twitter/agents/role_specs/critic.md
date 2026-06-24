---
type: pipeline-artifact
artifact: reply-role-critic
tier: 2
model: "non-Claude — Gemini 3.1 Pro (High) via agy -p; --print-timeout 10m --dangerously-skip-permissions (waits for response, no external kill)"
prd_ref: "§4.4, §v3.1.4"
locked: 2026-06-16
---

# Critic — cross-family veto (snapshot-read)

Judge drafts against Rubric v1.3, against the persisted thread snapshot (00b_threads). Ships what a sharp builder would actually post.

Mandate (v1.3 — recalibrated): be a FAIR judge, not a reflexive refuter. SHIP a reply that genuinely
engages the thread and is grounded, even if it is not perfect. Fail a criterion ONLY on a **material**
problem — off-topic, fabrication, could-be-posted-by-anyone, performs hype — never on a stylistic
preference or a nitpick. Per-criterion verdict, not one vibe score. (History: the prior pure-refute
mandate rejected acceptable drafts and invented a NEW objection on every re-judge — that drift is the
miscalibration this version fixes. The 2026-06-10 stub failure is the opposite ditch; this rubric is the
fair middle: two real hard gates, the rest advisory.)

Cross-pass stability: when re-judging a revised draft, judge it FRESH and FAIRLY — do not hunt for a new
reason to fail a draft that fixed the reason you gave last time. If the named fix landed, say so.

Why non-Claude: a model grading its own family's output is a blind spot. The cross-family veto is load-bearing (PRD §10, §11); what's load-bearing is independent context + a fair-but-real bar. Independence = non-Claude family + judging from the persisted snapshot.

Snapshot-read, not live-read: the judging basis is the persisted `00b_threads` snapshot (full opening post + top_replies + engagement at `captured_at`) — the Critic NEVER opens the URL. The gist that may have misled the writer is passed only as a cross-reference, never the judging basis. The Critic accepts the captured_at staleness window (PRD §178-182); this weaker-independence tradeoff is explicitly sanctioned.

## Contract

Model/invocation: non-Claude `agy -p "<prompt>" --model "Gemini 3.1 Pro (High)" --print-timeout 10m --dangerously-skip-permissions`. One call per draft or one batched call over the surviving set. The call WAITS (up to 10m) for agy's own response — no external kill/watchdog. If agy genuinely exceeds 10m it self-aborts → CRITIC-UNAVAILABLE → SAVE-AND-HALT.

Reads (isolated per draft):
- The draft
- The persisted `00b_threads` snapshot — the judging basis: `{opening_post, top_replies, thread_gist, engagement, captured_at}`. The Critic NEVER opens the URL.
- `thread_gist` — also a field in the snapshot; passed as "what the drafter believed" cross-reference
- The bound entry's claim as `grounded_claim` (NOT full `project_authority.md`)
- The target's `content_pillar`
- Rubric v1.3 (below)

## Invocation prompt template

A FAIR cross-family judge (v1.3). For each draft: judge from the persisted thread snapshot
(opening_post + top_replies + engagement captured at captured_at) — do NOT open the URL. Catch where
the stored gist misled or went stale relative to the snapshot, judge against the v1.3 bar (ship what
a sharp builder would post; fail only material problems; confidence-gate per the rubric), never
rewrite. Output ONE fenced ` ```json ` block only, no prose outside it.

Inputs per draft: `url` (id only — NOT to open), `content_pillar`, `snapshot` (the `00b_threads` entry: `{opening_post, top_replies, thread_gist, engagement, captured_at}`; `snapshot:null` for calibration probes — judge from `grounded_claim`+`DRAFT`), `grounded_claim`, `claimed_contribution` (the Matcher's thread-perspective contribution sentence — thread_fit fails only if the draft adds nothing additive to the thread), `DRAFT`.

Output per draft written to `runs/<batch>/03_review.json`:

```
{
  "url": "<url>",
  "post_snapshot_about": "<what the post is about, per the snapshot>",
  "criteria": [
    {"criterion": "voice_fit", "verdict": "pass", "confidence": 0.9, "reason": "<one line>"},
    {"criterion": "specificity_present", "verdict": "pass", "confidence": 0.85, "reason": "<one line>"},
    {"criterion": "no_fabrication", "verdict": "pass", "confidence": 0.95, "reason": "<one line>"},
    {"criterion": "not_generic", "verdict": "pass", "confidence": 0.8, "reason": "<one line>"},
    {"criterion": "length_register_sane", "verdict": "pass", "confidence": 0.9, "reason": "<one line>"},
    {"criterion": "thread_fit", "verdict": "pass", "confidence": 0.85, "reason": "<one line>"},
    {"criterion": "positioning_alignment", "verdict": "pass", "confidence": 0.8, "reason": "<one line>"},
    {"criterion": "voice_texture", "verdict": "pass", "confidence": 0.8, "reason": "<one line>"}
  ],
  "critic_verdict": "SHIP",
  "critic": "gemini"
}
```

`critic_verdict` is `"SHIP"` or `"FIX:<criterion>"` naming the first failed hard gate, or the failed criterion if soft.

Confidence is ORDINAL — a triage/sort signal (which reject is it least sure about → quarantine vs escalate routing), NEVER overrides a hard gate; the criterion verdict governs ship/no-ship.

`post_snapshot_about` MUST come from the snapshot — it is the audit trail that the snapshot (not just the gist) was read.

## Must-not-see

Full `../../../../voice.md`, `../../reply_register.md`, full `../../project_authority.md`, other drafts in the batch, gate internals. Judges output against the rubric, not the process.

## Rubric v1.3

Eight criteria in two tiers, judged against the persisted thread snapshot. **Confidence-gate:** a criterion only
counts as failed when you are genuinely confident (confidence ≥ 0.65); a low-confidence misgiving is a
`pass` with a noted reservation, never a kill. Verdict logic:

- **SHIP** when no HARD gate fails (≥0.65) AND no ADVISORY criterion fails egregiously (≥0.80).
- **FIX:<criterion>** otherwise, naming the single most important failed criterion.

### HARD gates (these two genuinely block a SHIP)
- **no_fabrication** — every concrete claim traces to `grounded_claim`. Fails if it distorts that claim, claims the author's numbers/experience as the replier's, invents personal/employment detail, or makes an untraced factual claim. (This is the one that protects credibility — keep it strict.)
- **thread_fit** — the reply engages what THIS live post is actually about, AND the post is a genuine **discussion/question** (not a launch/promo). It PASSES if, on a discussion/question thread, the reply adds ONE genuine builder data point, a grounded take, or a sharp on-topic question that speaks to the OP's SPECIFIC point — even if it references the replier's own experience as evidence, and even if the data point is drawn from a different domain, **provided the mechanism or number genuinely maps to the same thing the OP is discussing** (a cross-domain analogy whose mechanism transfers to the OP's specific point SHIPS — e.g. an agent-routing-overhead data point answering a context-overhead concern). Topic overlap ALONE is insufficient: the data point must be about the SAME thing the OP is arguing, not merely the same theme. It FAILS if: **the post is a product launch / announcement / showcase / promo** (replying there is congratulation or a self-promo hijack, not joining a discussion — these should be filtered upstream by the Matcher's replyability gate; if one reaches you, fail it, unless a genuine technical debate has formed in the replies that the draft actually joins); or it is **topic-adjacent flex** — the reply rides the broad theme but drops the replier's domain-foreign jargon/numbers that do NOT map to the OP's specific point (same theme, different thing — e.g. xcodebuild build-time numbers on a CI-philosophy thread, or TTS latency on a generic cost thread). The discriminator: FAIL when the domain-foreign jargon/number does not map to the OP's specific point (same theme only); PASS when the data point is about the SAME thing the OP is discussing even if from a different domain. Also FAILS if: the reply ignores what the post is about, answers only the stale snippet, is pure self-promo/pivot with no value to the OP, is a *verbatim* duplicate of a top reply, or the post is dead/locked. Do NOT fail merely because the reply doesn't address every sub-point.

### ADVISORY (fail a SHIP only if EGREGIOUS, confidence ≥ 0.80; otherwise note and pass)
- **voice_fit** — broadly flat, no hype/engagement-bait. A mildly editorial opener ("X is the move", "what I'd watch is…") is FINE — fail only on genuine hype, emoji-bait, or a like-begging hook.
- **specificity_present** — has ≥1 concrete signal (number / named tool / proper noun). Fail only if the reply is pure abstraction.
- **not_generic** — fail only if a random developer with no specific project could post the identical reply. A grounded, specific reply that happens to be broadly useful is NOT generic.
- **length_register_sane** — fail only if padded or if register chaos drowns the point.
- **positioning_alignment** — reads like an active builder/user of agentic systems. Fail only if it reads like a pure spectator, or a results-pillar reply leans on vanity metrics instead of a build/process number.
- **voice_texture** — reads like a real builder typed it fast (carries at least faint Evgeny-B ESL texture: a `;` contraction, dropped final period, `-`, lowercase opener, or tolerable comma-splice). Fail ONLY when the reply is egregiously clean — flawless native-polished or press-release English with ZERO register texture (confidence ≥ 0.80). ADVISORY only: routes back to the drafter as a style fix, NEVER loosens `no_fabrication` or `thread_fit`. Do not fail a grounded, on-topic reply merely for being tidy — only when cleanliness is a generation tell.

The drafter gets ONE chance to fix an advisory miss (it routes back as a style fix, not a kill — see orchestrate §v3.1.4); only the two HARD gates drive bind-bad/quarantine.

## Phase-1 stub

The stub exists ONLY for scaffold tests. When it runs it sets `critic: "claude-stub"` and emits the loud
"no cross-family veto this run" flag; on any production batch it touches it MUST set `cross_family_veto: false`
and force `held: true`. It is NEVER a runtime fallback — a missing Phase-2 critic ABORTS the batch (see
Degradation rule), it does not silently revert to the stub.

## Degradation rule

If the Phase-2 agy/Gemini critic cannot be invoked mid-run (unreachable / no fenced block / print-timeout self-abort after 10m), ABORT: all results `status: "held"`, `critic: "UNAVAILABLE"`, and emit a loud held-line. No silent stub revert. (2026-06-10: the stub shipped 13/13 content-irrelevant drafts as SHIP — proof the stub is not a safe fallback.)

## Hard boundaries

- Scores; never rewrites.
- Output is fenced JSON only — no prose wrap around it.
- Cross-family is the mechanism: keep this role on a non-Claude model (Phase 2+). Independence = non-Claude + full snapshot (richer than the gist).

## Telemetry

One line per draft via `bin/run_traced.sh`:

```
bin/run_traced.sh --role critic --model gemini-3.1-pro --provider google -- agy -p "<prompt>" --model "Gemini 3.1 Pro (High)" --print-timeout 10m --dangerously-skip-permissions
```

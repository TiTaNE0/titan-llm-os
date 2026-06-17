---
type: prd
status: draft
version: 3.1
created: 2026-06-09
revised: 2026-06-15
supersedes: Reply_Pipeline_PRD_v2.3 (single-agent, 3 manual runs)
account: ogrizkov
channel: twitter
epic: agentic-reply-loop
positioning: agentic-systems (50/30/20 — build / apply / results)
architecture: supply-driven (vault-first) as of v3.1
---

# X Reply Pipeline — PRD v3.0 (agentic loop, isolated roles)

## 1. Why v3 (the real problem)

v2.x works, but it is **one agent carrying every constraint at once** — discover, liveness,
English, match-to-grounding, voice, register, skew-short, dedup, asset, gate. Each is a
medium-sized rule; together they overload one context window and quality degrades at the
margins (the 9g batch: right grounding, but length crept long, openers collided, register
went uniform). **This is not a guardrails problem** — the gates are correct. It's a
**context problem**: too many concerns in one head.

The fix is the pattern Evgeny already builds (`claude-agent-kit`, `05_Marketing_System`):
**an orchestrated loop of isolated sub-agents**, each holding only its own concern, handing
**structured data** (not prose) to the next — so no concern bleeds into another. v3 turns
the three manual runs (Scout / Draft / Log-wins) into **one orchestrated loop** that stops
only at the human review gate.

**Positioning (added June 2026 — the second problem v3 must serve.)** The earlier runs also
lacked a single through-line: targets were bound to any plausible project entry, which produced
replies that were grounded but thematically scattered (and, on thin windows, nothing shippable).
The account now commits to one thematic center — **building agentic systems and showing how I
use them to develop, promote, and grow my own projects** — with a 50/30/20 content split (see
the *Updated Positioning* section below). v3's grounding and judging steps are updated to serve
that through-line: the Matcher maps every target to one of the three content pillars before it
binds, and the Critic checks that the reply reads like it comes from someone actively building
and using these systems. This sharpens selection — fewer scattered binds, fewer pivots — rather
than loosening any honesty constraint.

## 2. Objective

A single orchestrator invocation that: scouts 8–12 live English in-niche threads, **maps each
to one of the three content pillars and grounds it 1:1 in real project work** (so the batch
reflects the 50/30/20 split, not a random scatter), drafts short varied human replies that read
like an active builder, asset-cards the top 1–2, passes every deterministic + cross-family check
(including positioning alignment and live-thread fit), and writes a review queue — with each role
isolated so context never tangles. Never auto-posts. A post-cycle role logs what won, preferring
build/process metrics over vanity metrics.

## Updated Positioning (June 2026)

This is the thematic center the whole pipeline now serves. It governs what the Scout looks for,
how the Matcher binds, and what the Critic rewards. It does not change any honesty rule.

**Core positioning:**
> Building agentic systems that develop, promote, and grow my projects. Sharing real pipelines,
> experiments & numbers.

**Content pillars — 50 / 30 / 20:**

| Pillar | Share | What it covers | Grounds in |
|--------|-------|----------------|-----------|
| **Build** — building agentic systems | 50% | architecture, agent memory, orchestration, harnesses, reliability/error-recovery, context injection, tooling | `claude-agent-kit`, `TiTan_LLM_OS` (agentic pillar entries) |
| **Apply** — applying agentic systems to real tasks | 30% | dev pipelines, growth/marketing systems, content automation, X-growth, real shipped apps built with agents | dev + marketing pillar entries (`road-assist`, `nearest-address-codes`, `Intuiscale`, `05_Marketing_System`, `LinkedIn_Automation`, content-modules) |
| **Results** — real results & numbers | 20% | concrete outcomes from the above | **build/process metrics first** (reliability, retry-rate, time-saved, draft-to-publish, latency/token deltas); vanity metrics (followers/impressions/revenue) only once growth is genuinely meaningful |

**The recursive loop is the differentiator:** using agentic systems to generate and refine
content about agentic systems, on the account being grown — the feed becomes a working
demonstration, not a list of projects.

**Honesty guardrails (unchanged, restated for this positioning):**
- No fabricated experience, numbers, or revenue. The `[VERIFY]` rule and the Matcher's
  real-entry-only bind still hold.
- The 20% bucket leads with build/process metrics; it does **not** surface single-digit weekly
  follower/impression gains as if they were wins.
- The courier/day-job work is **not** part of the public narrative; agentic systems may support it
  privately, but it is not surfaced as an "Apply" example until it fits naturally with visible
  agent usage. (Consistent with §10 — personal/day-job life out of grounding.)

## v3.1 — Supply-driven architecture (June 2026)

This section is authoritative for top-of-funnel, control flow, retry/quarantine, the roster (§7),
and telemetry. It **supersedes** the demand-driven flow described in §3/§5 where they conflict; the
rest of v3.0 (isolation rules, structured handoff, human gates) stands unchanged.

### v3.1.1 Why invert — the binding cliff

v3.0 was **demand-driven**: search X for what's hot, then hope a vault entry matches. The 2026-06-15
run exposed the failure: 22 scouted → 9 live → **3 bound** → 0 shipped. Hot AI threads are mostly
launches/drama/announcements that don't map 1:1 onto real project work, so most live threads had no
honest bind and were dropped. With a ~30-entry grounding file and 1:1 no-reuse binding, the funnel
**cannot** produce 12 — the math never closed.

v3.1 inverts to **supply-driven**: index the vault FIRST into search vectors, then send the Scout to
find live threads that match what we already know we can ground. Groundability stops being the thing
we hope for and becomes the thing we search by. Operator constraint (load-bearing for the supply
guarantee): **every vector is AI/agentic** — either an agentic-systems topic itself, or "how an agent
reasoned/implemented X" — never a bare dev topic. That keeps every vector inside the always-hot
agentic discourse, so live, high-velocity threads reliably exist for it.

### v3.1.2 New top-of-funnel: Vault_Scout (stage 0b)

A prep stage that runs **before** X discovery (and is cached — re-run only when `project_authority.md`
changes).

- **Model:** Sonnet 4.6 (Opus on a major vault expansion).
- **Reads:** `project_authority.md` only.
- **Writes:** `runs/_index/search_vectors.json` — an aggregated, reusable set of search intents, each
  tied to the vault entries it can ground and a content pillar.
- **Vector rule:** every vector is phrased through the agentic lens. Good: "agents reasoning about
  offline-first PWA cache invalidation", "agent retry loops & context-window limits", "multi-agent
  content pipelines". Bad (rejected): "Redis Geo consensus" with no agent angle.
- **Anti-staleness (else the pipeline dries up in days).** The vector *set* is cached, but the queries
  are NOT static across runs:
  1. Each vector carries a **pool** of `query_seeds` (synonyms/phrasings), and the Scout **rotates /
     samples** a different subset per run rather than firing the identical query every 24-48h.
  2. The Scout always applies a **recency filter** (last 24-48h) and **excludes already-engaged URLs**
     by reading prior `runs/*/replies_to_post.md` + `reply_register.md` — a thread we already replied
     to never re-enters.
  3. `search_vectors.json` is **re-generated when the vault changes OR after a staleness TTL** (e.g.
     ~weekly) so new phrasings enter even if `project_authority.md` was untouched.

```json
{
  "generated_from": "project_authority.md@<hash>",
  "vectors": [
    {
      "id": "V-agentic-orchestration",
      "content_pillar": "build",
      "search_intent": "threads where people argue about agent-agnostic orchestration / model-as-runner / owning the routing graph",
      "grounds_with": ["CAK-01", "TIT-01"],
      "query_seeds": ["agent orchestration", "model agnostic", "routing graph", "claude code vs opencode"]
    }
  ]
}
```

### v3.1.3 Control flow (round-robin, replace-don't-drop, loop-to-target)

```
0b. VAULT_SCOUT (cached) → search_vectors.json
1.  ORCHESTRATOR round-robins the vector list, biasing the *pick order* toward the 50/30/20 split
    (it owns batch balance — see "Batch balance" below). Vectors are NON-EXCLUSIVE — a vector may
    yield more than one reply across the batch.
2.  X SCOUT (grok): search the chosen vector (rotated query per run, recency-filtered, prior-engaged
    URLs excluded) → return live candidate(s) + thread context in ONE fetch (00b_threads.json is the
    single source of thread text; the blind Claude roles read it). HARD CAP: ≤ MAX_FETCH_PER_VECTOR
    grok calls per vector per run (default 3); on cap with no bind, mark the vector EXHAUSTED.
3.  MATCHER (Opus): deterministic corpse-drop pre-filter → confirm the candidate matches the vector
    + bind to a vault entry + write the contribution + tag content_pillar (shared pivot/thread-fit
    STANDARD with the Critic). It judges ONE candidate at a time — it does NOT balance the batch.
    Pass → LOCK (anchored_count += 1). Fail → tell Scout WHY; Scout fetches the next candidate.
4.  DRAFTER (Sonnet, fresh instance) → GATEKEEPER (gate.sh) → CRITIC (grok, live-read of its own).
5.  STOP CONDITION (whichever first): shipped == TARGET (default 12); OR all vectors EXHAUSTED;
    OR total grok calls == MAX_GROK_CALLS (global budget); OR failure-rate breaker (v3.1.4) fires.
6.  ASSET (top 1-2) → PRODUCER → replies_to_post.md. STOP at human review. Never post.
7.  [later] WINS-LOGGER → wins.md.
```

- **12 is a soft target, not an invariant or a floor.** Loop *toward* 12, bounded by the stop
  conditions in step 5 (per-vector cap, global grok budget, vectors exhausted). When a stop condition
  fires before 12, ship what is real and **report the shortfall with reasons** (`batch_report.md`) —
  do NOT spin. (Implementation note: the Orchestrator loop is bounded by the caps, never a bare
  `while shipped < 12`.) Never let the target pressure a gate into passing a marginal draft — that
  path leads straight back to the 2026-06-10 "13/13 clean-but-irrelevant" failure.
- **Batch balance is the Orchestrator's job, never the Matcher's.** The 50/30/20 split is enforced by
  *which vector the Orchestrator pulls next* (each vector carries a `content_pillar`), so balance is a
  scheduling decision over cheap per-vector state — the Matcher never needs all candidates in one
  context. The Matcher only tags the pillar of its single bind; the Orchestrator counts shipped
  pillars and steers the next pick toward the under-filled bucket.
- **Single fetch, no redundant re-pull.** The Scout fetch exists because the Drafter and Matcher are
  Claude and cannot browse X — they need the text handed to them. The Critic **is** grok and opens the
  URL as part of its own single judging call, so its independent live read is not a second fetch step.
  (If the critic were ever a non-browsing model, it would judge the stored fetch instead — accepting
  weaker independence; that tradeoff is why a browsing critic is preferred.)

### v3.1.4 Retry & quarantine (no silent drops, no global halt)

A Matcher-locked target is viable by construction, so a downstream failure is treated as a problem to
**fix or quarantine**, never a silent drop. But the Matcher is **not** assumed infallible (the
2026-06-15 run produced one genuine pivot-bind the Critic correctly killed), so the Critic stays a
real veto.

**The Orchestrator routes deterministically on the Critic's structured per-criterion verdicts**
(the `criteria[]` booleans in `03_review.json`), NOT the free-text `FIX:` prose. The failed criterion
maps to an action via this table:

| Failed criterion | Default route | Why |
|---|---|---|
| 1 voice_fit | draft-fixable | how it was written; a fresh draft within the same bind fixes it |
| 2 specificity_present | draft-fixable | drafter can add the concrete signal from the bound entry |
| 3 no_fabrication | draft-fixable | drafter overreached past `grounded_claim`; redraft within it |
| 4 not_generic | draft-fixable | drafter can sharpen to the builder-specific take |
| 5 length_register_sane | draft-fixable | pure mechanical rewrite |
| 6 thread_fit | draft-fixable **once**, then bind-bad | live run proved a good bind can be saved by a sharper draft (OrcaRouter); but a *second* thread_fit fail means the target genuinely doesn't fit → replace |
| 7 positioning_alignment | draft-fixable **once**, then bind-bad | same: ground harder once; if it still reads off-positioning, the bind is in the wrong pillar → replace |

- **Reclassify-on-repeat (overrides the table):** any criterion that fails the **same way twice**
  becomes **bind-bad** — if a fresh draft can't satisfy it on the second try, the bind can't support
  an honest draft on it. This is why criteria 3/4/6/7 aren't statically "bind-bad": the *first* fail
  gets a redraft, the *repeat* triggers replacement.
- **Immediate bind-bad (no redraft):** the Critic's `thread_fit` sub-clauses `still_alive=false`
  (deleted/locked) or `drift=dead` (moment passed) → **replace at once**; redrafting a dead thread is
  pointless.
- **draft-fixable action:** kill the Drafter instance, **spawn a fresh Drafter** with
  `{prompt + prior draft + named correction}`, retry (cap: 2 draft retries per target).
- **bind-bad action:** **return to the Matcher/Scout** for a replacement target on that vector.
  Replace, don't drop; don't burn retries fighting an unwinnable target.
- **Per-target circuit breaker:** if a single target keeps failing after its draft-retry cap and one
  replacement, **quarantine it and keep the batch moving** — recorded with its reject history, not
  allowed to halt the run.
- **Rate/confidence-based escalation (replaces the global SYSTEM HALT):** escalate to the operator
  only when the **failure *rate*** across the batch crosses a threshold (e.g. > ~40% of targets hit
  the breaker), OR when rejects are low-confidence and scatter across different criteria each retry —
  the signature of a genuine Matcher/Critic/Drafter parameter conflict. One stuck target = quarantine;
  half the batch stuck = real systemic conflict worth stopping for.

### v3.1.5 Telemetry contract (baked into every role — CAK-07 applied)

The pipeline previously emitted only pass/fail, so it could never explain *why* the funnel leaked.
v3.1 makes telemetry a first-class part of every role's contract (this is just the kernel's
`emit_telemetry` doctrine — append-only JSONL, non-blocking — applied to the reply loop).

- **Every role invocation appends one line** to `runs/<batch>/_telemetry.jsonl` via `bin/trace.sh`
  (`{ts, role, model, provider, vector, target, retry, duration_ms, tokens_in, tokens_out, verdict,
  confidence, reason, outcome}`). CLI roles (grok) wrap the call in `bin/run_traced.sh`, which fills
  `duration_ms` and char/4 token **proxies** automatically (CLI models don't report real token
  counts); Claude sub-agents pass the harness's real `subagent_tokens`.
- **Reject with confidence + reason, never bare FAIL.** The Matcher (contributability) and the Critic
  (each rubric criterion) emit `{verdict, confidence: 0-1, reason: "<one line>"}`. `03_review.json`
  gains a `criteria: [...]` array per result carrying this. **Confidence is ORDINAL** — a sort/triage
  signal (which reject is it least sure about → quarantine vs escalate routing), **never** a soft
  override of a hard gate. The criterion verdict still governs ship/no-ship.
- **Roll-up:** `bin/batch_report.sh <run-dir>` joins `_telemetry.jsonl` + `03_review.json` into
  `runs/<batch>/batch_report.md` — funnel counters, per-role cost/latency, **per-criterion kill-rate
  + avg confidence**, per-vector yield, and the quarantine list. One file the operator reads instead
  of five raw dumps.
- **Two logs, separate purposes, both feed Scout:** this in-pipeline telemetry explains *why the
  funnel leaks* (gate behavior); `wins.md` records *what the audience rewarded* (post-posting). Do not
  merge them.

### v3.1.6 What this fixes

Vault-first + agentic-lens vectors removes the binding cliff (groundability is now searched for, not
hoped for). Round-robin + non-exclusive vectors + loop-to-target makes a higher deliverable count
*reachable* without loosening any quality gate. Replace-don't-drop + per-target quarantine stops the
silent loss of good opportunities. The telemetry contract turns the black box into something tunable —
the next time the funnel underperforms, `batch_report.md` says exactly which criterion, vector, or role
is responsible.

## 3. Architecture (orchestrator + isolated roles)

```
                      ┌─────────────────────────────────────────────┐
                      │  ORCHESTRATOR — "Elite X Content Manager"     │
                      │  Fable 5 · owns the loop, scope, retries,     │
                      │  human handoff. Holds THIN coordination state │
                      │  only — never the full context of any role.   │
                      └───────────────┬─────────────────────────────┘
        structured artifacts (files in runs/<batch>/), tone-firewall between every hop
   ┌───────────────┬───────────────┬───────────────┬───────────────┬──────────────┐
   ▼               ▼               ▼               ▼               ▼              ▼
1 SCOUT         2 MATCHER       3 DRAFTER       4 CRITIC        5 GATEKEEPER   6 ASSET
 (Grok,          (Sonnet 4.6)    (Sonnet 4.6)    (cross-family,  (deterministic (Haiku)
  grok -p)                                        non-Claude)     shell)
 X retrieval →   bind 1:1        write reply     score voice/    gate.sh:        aurora-frost
 hot+domain,     project_        from {tweet +   specificity/    word/!/spec/    insight/stats
 English,        authority       bound entry +   no-fabrication/ length-skew/    fill + render
 24–48h →        entry per       voice +         generic →       dedup-opener/   PNG (top 1–2)
 raw candidates  live target     register]       SHIP|FIX        lowercase/repeat
                                                                        │
                              ┌─── orchestrator loops on FIX/FAIL ──────┘
                              ▼
                           7 PRODUCER (Haiku) → runs/<batch>/replies_to_post.md  → HUMAN REVIEW
                                                                                      │ (operator posts)
                                                                                      ▼
                                              8 WINS-LOGGER (Grok, grok -p, +1 day) → runs/_analytics/wins.md
```

The orchestrator is Claude Code (it can spawn Claude sub-agents and shell out to other CLIs).
Claude-family roles are spawned via `claude -p`/sub-agents; non-Claude roles are invoked as
CLI processes (`grok -p …`, cross-family CLI) and their headless stdout is captured + parsed.

## 4. Roles (each: model · isolated input · structured output · must-not-see)

### 1. Scout — X retrieval  ·  Grok (`grok -p`)
- **Why Grok:** it has live X/web access; the orchestrator invokes `grok -p "<scout brief>"`
  and captures headless stdout. (Claude has no X wall access; this is the bridge.)
- **Input (isolated):** search topics (broad hot AI + the 3-pillar domain vocab), the 24–48h
  window, English-only, `wins.md` + prior `reply_feed`s (learn / dedup) — NOT voice/register/grounding.
- **Output:** `00_candidates.json` — array of `{url, author, age, views, likes, replies, lang,
  hot|domain, text_snippet, source_tag, post_type}`. Raw retrieval + source honesty; no drafting, no ranking prose.
- **Thread-fetch sub-step (batched, post-shortlist):** after the Matcher's liveness shortlist, ONE batched
  `grok -p` call fetches full thread context (opening post in full + highest-signal replies) for the survivors →
  `00b_threads.json`. Routed to the Matcher; the orchestrator never ingests the thread text.
- **Loop:** the orchestrator re-invokes Scout with widened queries until ≥8 live English candidates survive the gate (P7).
- **Must not see:** voice.md, reply_register, project_authority, drafts.

### 2. Liveness+Matcher — grounding  ·  Opus 4.8 (v3.1; was Sonnet 4.6)
- **Why Sonnet (not Haiku):** liveness + 1:1 binding is a judgment call, and a wrong bind poisons
  every downstream draft of that target. Haiku's savings (~cents per run) don't cover that risk;
  Haiku stays on the mechanical roles (Asset fill, Producer assembly).
- **Input (isolated):** `00_candidates.json` + `00b_threads.json` + `project_authority.md` only.
- **Work:** apply the hard Liveness gate (corpse-drop, velocity, fresh-by-reach, English) → apply the
  **replyability gate** (drop poll/meme/promo `post_type` unless `00b_threads.json` shows a real
  discussion to join — groundable ≠ replyable) → **map each survivor to one of the three content
  pillars** (Build / Apply / Results, per *Updated Positioning*) → bind 1:1 a distinct
  `project_authority` entry per survivor against `thread_gist` (no reuse), tag
  `content_pillar` + `project_pillar`/touches/ground_with.
- **Grounding priority (June 2026 positioning):**
  1. **Prefer targets we can ground in real project work** — a thread that maps cleanly onto a
     `project_authority` entry (an actual decision Evgeny made) outranks a thread that only
     topically resembles the account's themes. Marginal, resemblance-only binds are dropped, not
     stretched.
  2. **Tag the `content_pillar`** of this single bind (Build / Apply / Results) — but do **NOT**
     balance the batch. Batch-level 50/30/20 is the **Orchestrator's** job, enforced by which vector
     it pulls next (v3.1.3); the Matcher never sees all candidates at once, so it cannot and must not
     balance. It judges ONE candidate in isolation (preserves context-isolation, §9).
  3. **Results (20%) bucket — build/process metrics first.** Only bind a Results target if the
     bound entry carries a real build/process number (reliability, retry-rate, time-saved,
     draft-to-publish, latency/token delta). Do **not** bind a target that would lead the reply
     toward follower/impression/revenue vanity metrics; those stay out until growth is meaningful.
- **Output:** `01_anchored.json` — `{url, author, engagement, content_pillar, project_pillar, ground_with, why_live, entry_substance, contribution, thread_gist, post_type}` (`content_pillar` ∈ build|apply|results; `project_pillar` is the source pillar in `project_authority.md`). The `contribution` sentence (thread-perspective: what the reply adds to THIS thread) is the bind condition — if the Matcher cannot write it honestly, the target is dropped (**contributability gate**; 2026-06-10a lesson: topically-groundable ≠ genuinely-contributable, an entry-perspective angle manufactures pivots).
- **Must not see:** voice/register (it grounds, it doesn't write), search internals, other roles' reasoning.

### 3. Drafter  ·  Sonnet 4.6
- **Input (isolated):** ONE anchored target at a time — `{thread_gist + bound entry substance + contribution}`
  + `voice.md` + `reply_register.md` + the never-list. **Not** the whole `project_authority`, not the
  search, not other targets. One target, one head. (Drafts against what the thread is actually about,
  incl. replies — not an opening fragment.)
- **Work:** write the reply — Evgeny-B, skew-short (median one sentence, ≥half ≤12 words), varied
  opener, register chaos as the minority move.
- **Output:** `02_drafts.json` — `{url, ground_with, draft, [VERIFY?]}` per target.
- **Must not see:** the asset templates, the gate internals.

### 4. Critic / Judge  ·  cross-family, NON-Claude — Grok live-read (v3.1)
- **Why non-Claude:** a model grading its own family's output is a blind spot (`MKT-02` — the
  cross-family veto is load-bearing).
- **Input (isolated):** the draft + the target URL the critic **opens and reads LIVE** (the live thread
  is the judging basis) + `thread_gist` passed ONLY as "what the drafter believed" cross-reference + the
  bound entry's claim as `grounded_claim` + the target's `content_pillar` + a **compact rubric** of
  criteria, each individually gradeable. The criteria:
  1. **voice_fit** — flat, specific, no hype/bait.
  2. **specificity_present** — ≥1 concrete signal tied to the bound entry.
  3. **no_fabrication** — every claim traces to `grounded_claim`; the author's numbers are not claimed as ours.
  4. **not_generic** — a take only the builder of these specific projects could give.
  5. **length_register_sane** — short norm; register imperfection minor, never touching the signal.
  6. **thread_fit** *(explicit)* — does the reply **meaningfully engage the actual thread** — its real
     ask/reveal as it stands NOW (including what the replies added), not just the opening snippet?
     Fails on snippet-only answers, redundancy with existing replies, staleness, or a pivot toward our
     own projects.
  7. **positioning_alignment** *(new, June 2026)* — does the reply read like it comes from **someone
     actively building and using agentic systems** (consistent with the target's `content_pillar` and the
     Core Positioning)? Fails if it reads like a generic commentator/spectator, or if a Results-pillar
     reply leans on vanity metrics instead of a build/process number.
- **Mandate:** REFUTE, don't grade gently — the drafter is a pathological optimist about its own
  output. Each rubric criterion must be individually gradeable (per-criterion verdict, not one
  vibe score); a draft ships only if it survives every criterion. `thread_fit` and
  `positioning_alignment` are hard gates — a reply that is on-voice but off-thread, or on-thread but
  off-positioning, does not ship.
- **Output:** per draft `SHIP | FIX:<one-line reason naming the failed criterion>`.
- **Must not see:** the full voice/register files (it judges the output against a rubric, not the process).

### 5. Gatekeeper  ·  deterministic shell (no LLM)
- **Work:** `gate.sh` per draft (word∈[5,45], no `!`, concrete signal) + `gate.sh --batch`
  (anti-repeat, length-variance, length-skew, duplicate-opener, lowercase-share). Exit 0/1.
- **Output:** pass/fail + flags. Deterministic, instant, free.
- **Loop:** any FIX (Critic) or FAIL (Gatekeeper) → orchestrator returns that target to the Drafter (cap 2 retries), then skips if still failing.

### 6. Asset  ·  Haiku
- **Input (isolated):** the top 1–2 asset-worthy `{draft + bound entry}` + the aurora-frost template.
- **Work:** fill `insight` (or `stats` if the entry has numbers) → `render_asset.sh` → tight `.card` PNG.
- **Output:** `05_Assets/reply-<…>.html` + `.png`; paths back to the orchestrator.

### 7. Producer  ·  Haiku
- **Work:** assemble `runs/<batch>/replies_to_post.md` — link + ground_with + draft + asset paths,
  all DRAFT. The human review gate. Never posts.

### 8. Wins-logger  ·  Grok (`grok -p`, runs ~1 day after posting)
- **Work:** `grok -p` `from:ogrizkov` engagement of the posted replies → append real winners to
  `runs/_analytics/wins.md` (append-only, real metrics only). Feeds Scout's LEARN next cycle.
- **Distill (orchestrator, after the Grok fetch):** raw metrics don't transfer — for each winner
  the orchestrator appends one distilled rule (what worked + why: opener type, register, pillar,
  length). Scout consults rules, not raw logs. The chain is fail → investigate → verify →
  distill → consult; distillation stays on the Fable 5 host, not on a small model.

## 5. Control flow (the loop the orchestrator runs)

```
1. SCOUT (grok -p) → candidates.   while live<8 and not exhausted: widen, re-scout.
2. MATCHER (liveness shortlist) → live survivors.
2.5 THREAD-FETCH (Scout/grok, ONE batched call over survivors) → 00b_threads.json. Orchestrator routes, never ingests.
   MATCHER applies replyability filter + maps each survivor to a content pillar (Build/Apply/Results) + binds 1:1 against thread_gist → anchored, balancing toward 50/30/20. If <enough replyable+groundable: ask Scout for more.
3. for each target:  DRAFTER → draft  →  GATEKEEPER (gate.sh)  →  CRITIC (cross-family, live-read)
                      on FAIL/FIX → back to DRAFTER (≤2 retries) → else skip target
4. GATEKEEPER --batch over the surviving set (repeat/length/opener/skew). FAIL → orchestrator
   returns the flagged targets to DRAFTER with the specific flag.
5. ASSET → top 1–2 PNGs.
6. PRODUCER → replies_to_post.md.  STOP at human review. (never post)
7. [later, post-posting] WINS-LOGGER → wins.md.
```

The orchestrator holds only: the batch id, the list of targets + their state (drafted/passed/
failed/skipped), and retry counts. It does **not** ingest voice/register/grounding/search — those
live inside the respective roles. That thin state is what keeps its context clean.

## 6. Structured handoff (the tone-firewall, `MKT-03`)

Every hop is a **file artifact**, fields not prose: `00_candidates.json` → `01_anchored.json` →
`02_drafts.json` → `03_review.json` (critic/gate verdicts) → `replies_to_post.md`. Structure is
the firewall: a role can't leak its tone/context downstream because it only emits data. This is
the mechanism that fixes "context mess" — not bigger windows, but smaller, walled ones.

## 7. Model routing (roster — one swap point, IDs rotate monthly)

| # | Role | Model | Invocation |
|---|------|-------|-----------|
| 0 | Orchestrator | `claude-opus-4-8` (host; `claude-fable-5` if available) | host (Claude Code) |
| 0b | Vault_Scout *(v3.1)* | `claude-sonnet-4-6` (Opus on major vault change) | sub-agent |
| 1 | Scout (retrieve + thread-fetch) | Grok (X access) | `grok -p` (headless capture) |
| 2 | Matcher (liveness pre-filter + bind) | `claude-opus-4-8` *(v3.1, ⬆ from Sonnet)* | `claude -p` / sub-agent |
| 3 | Drafter | `claude-sonnet-4-6` | `claude -p` / fresh sub-agent per retry |
| 4 | Critic (live-read) | Grok (`grok-build`, live-read) *(v3.1: settled on Grok)* | `grok -p`, cross-family veto |
| 5 | Gatekeeper | — (shell) | `bin/gate.sh` |
| 6 | Asset | `claude-haiku-4-5` | sub-agent + `bin/render_asset.sh` |
| 7 | Producer | `claude-haiku-4-5` | sub-agent |
| 8 | Wins-logger | Grok | `grok -p` |

Routing rationale (v3.1, 2026-06-15):
- **Orchestrator → Opus 4.8** (the host Claude Code session; Fable 5 if available). Loop control,
  retry/quarantine judgment, deciding when to widen, telemetry roll-up. Thin coordination state.
- **Matcher → Opus 4.8** (⬆ from Sonnet). Binding is the highest-leverage judgment in the pipeline —
  a wrong bind poisons the whole downstream chain. Under supply-driven round-robin the Matcher is also
  the gate that confirms the Scout returned what a vector asked for, so its judgment carries more weight.
  A deterministic corpse-drop pre-filter (shell, by age/views) runs *before* the Opus bind to keep the
  expensive judgment off obvious dead candidates.
- **Critic → Grok, live-read.** Settled on Grok after evaluating alternatives (v3.1): it is cross-family
  (≠ the Claude Drafter) **and** the only model with live X access, so its independent live read of the
  thread is part of its own single call. A non-browsing critic (e.g. Gemini via `agy`) was rejected —
  it cannot open X, and proved unreliable in headless mode. Run at high effort.
- **Drafter → Sonnet 4.6**, spawned **fresh per retry** (kill the polluted instance; the new one gets
  prompt + prior draft + the named correction). Adequate for constrained drafting; cheap.
- **Vault_Scout → Sonnet 4.6.** Parsing the vault into search vectors is extraction + intent-shaping,
  not deep judgment, and it runs only when the vault changes. Haiku stays on the mechanical roles
  (Asset, Producer).

## 8. Reuse — nothing built so far is thrown away

Every v2 asset becomes a role's tool or spec:
- `skill/twitter-reply-scout.md` → **Scout** role spec (its 3 moves + loop + English).
- `project_authority.md` → **Matcher**'s grounding source (3 pillars, P5/P10 rules).
- `voice.md` + `reply_register.md` + `drafting_contract.md` → **Drafter**'s spec.
- `bin/gate.sh` (P1–P10 deterministic checks) → **Gatekeeper**.
- `_shared/asset_partners/aurora-frost/` + `bin/render_asset.sh` → **Asset**.
- `skill/twitter-reply-log-wins.md` + `runs/_analytics/wins.md` → **Wins-logger** + LEARN input.
- Mirrors `05_Marketing_System/roster.md` + `role_specs/` — the reply pipeline gets its own
  `roster.md` + `role_specs/` under `channels/twitter/agents/`.

## 9. Context-isolation rules (the core of v3)

1. Each role reads ONLY its declared inputs (§4) and writes ONLY its structured output.
2. The Drafter sees **one** target + the **one** bound entry — never the full grounding or the batch.
3. No role reads another role's reasoning — only its file artifact.
4. The orchestrator never ingests voice/register/grounding/search text; it routes artifacts + state.
5. Determinism first: anything checkable by shell (`gate.sh`) is shell, not an LLM.
6. Thread context flows as **data** through the file chain (`00b_threads.json` → `01_anchored.json`'s
   `thread_gist`) — the orchestrator routes it without ingesting, exactly as it does the search text.

## 10. Human gates & safety (unchanged doctrine)
- One human gate: review `replies_to_post.md`; operator posts manually. **Never auto-post.**
- No fabricated experience (Matcher binds only real entries; Critic checks; `[VERIFY]` on doubt).
- Cross-family veto load-bearing (Critic non-Claude). Source honesty in Scout. Day-job/personal life
  never in grounding (already scrubbed). Brand DNA fixed in Asset.

## 11. Honest tradeoffs (so we go in eyes-open)
- More moving parts: orchestration, more CLI processes, more cost/latency than one agent. Justified
  only because context-isolation is the actual bottleneck now, and Evgeny's stack already runs
  multi-agent pipelines (this is not new infra for him).
- We still don't have engagement data (`wins.md` empty). v3 makes the system **cleaner**, not proven
  to convert — that's the live test. Don't over-build beyond this before first real wins.
- Cross-family Critic adds a non-Claude dependency; if unavailable, ABORT the batch with all results
  `held` and a loud held-line — the Phase-1 stub is scaffold-only, NOT a runtime fallback (2026-06-10
  proved it ships irrelevant drafts as SHIP). What's load-bearing is the critic's independent context +
  refute mandate, more than the family boundary.
- Dual independent read: the orchestrator fetches thread context once for the Drafter (fetch-to-write,
  step 2.5) and the cross-family Critic independently re-opens each URL live to judge (live-read-to-judge)
  — independent context made literal: the gist that may have misled the writer is never the artifact that
  clears the writer.
- Every harness piece encodes an assumption about current model limits (retry caps, the Matcher
  split, per-role isolation depth). Re-test those assumptions each model generation and strip what's
  no longer load-bearing — don't let scaffolding outlive its reason.

## 12. Build phases (reuse-first, smallest first)
- **Phase 0 (scaffold):** `channels/twitter/agents/roster.md` + `role_specs/{scout,matcher,drafter,
  critic,asset,producer,wins}.md` (mostly point at existing skills/files) + the `runs/<batch>/`
  artifact schemas (`00_candidates`→`03_review`).
- **Phase 1 (orchestrator, happy path):** Opus orchestrator runs Scout(grok -p)→Matcher→Drafter→
  Gatekeeper→Producer in one invocation to a review queue. Critic = Claude stub.
- **Phase 2:** wire the **cross-family Critic** (non-Claude, live-read against Rubric v1.1 incl. thread_fit)
  + the batched thread-fetch (`00b_threads.json`) + the retry loop + the 8–12 widen loop. The Phase-1 stub
  is scaffold-only and is never a runtime fallback (ABORT + held on critic unavailability).
- **Phase 3:** Asset role inline + Wins-logger post-cycle.
- **Phase 4:** tune isolation/budgets from real runs; promote winners to `wins.md`.

## 13. Success criteria
- One orchestrator run yields a `replies_to_post.md` of 8–12 live English targets, each 1:1
  grounded, short + varied + clean register, top 1–2 asset-carded, all gates green — with **no role
  holding more than its own concern**.
- **Every shipped reply maps to one of the three content pillars (Build / Apply / Results), and a
  full batch trends toward the 50/30/20 split** rather than scattering across unrelated themes.
- **Every shipped reply passes `positioning_alignment`** — it reads like it comes from someone
  actively building and using agentic systems, consistent with the Core Positioning.
- **Results-pillar replies lead with build/process metrics** (reliability, retry-rate, time-saved,
  draft-to-publish, latency/token deltas); no shipped reply leans on single-digit follower/impression
  vanity metrics.
- The failures v2 hit at the margins (length creep, opener collision, register uniformity) don't
  recur, because no single context is juggling them.
- No draft ships that could have been written without reading the live thread (thread_fit) — the
  2026-06-10 failure mode (snippet-only context, irrelevant-but-clean drafts) does not recur.
- Never auto-posts; `wins.md` fills after posting and feeds the next Scout — biasing future scouting
  toward the pillars and angles that actually convert.

## 14. Open unknowns (resolve by building)
1. `grok -p` headless output shape — parse reliability into `00_candidates.json` (test first).
2. Cross-family Critic CLI availability + cost on the operator's stack.
3. Orchestrator retry economics — caps so a stubborn target doesn't burn the budget.
4. Whether Matcher+Liveness should split further (only if Matcher's context gets heavy).

## 14b. Save-and-halt (universal failure policy — added 2026-06-10 after grok ran out of credits mid-run b)

Any role whose output is unobtainable for any reason (credits, auth, dead CLI, sub-agent fails twice,
no fenced block after the one re-prompt) freezes the run: SAVE what exists (file artifacts are the
checkpoint), RECORD `runs/<batch>/HALT.json` `{halted_at_stage, reason, completed_stages,
artifacts_present, next_stage, resume_instruction}`, STOP all downstream stages (no asset/producer
ceremony, no padding artifacts — polished output downstream of a dead dependency is fluff), RESUME
from `next_stage` once the blocker clears (every stage is re-entrant via the file handoffs). Never
substitute, never stub, never improvise a replacement model mid-run. The Critic degradation rule
(§4.4) is the special case; this generalizes it to every role. Runbook: orchestrate skill § SAVE-AND-HALT.

## 15. First-live-run post-mortem (2026-06-10_batch)

The first live run produced **13/13 content-irrelevant drafts** — every mechanical gate green
(`gate_single` pass, `gate_batch` pass), killed at the human gate. A post-hoc cross-family grok critic
reading the live threads returned FIX 13/13. The drafts were clean, grounded, and on-voice; they simply
did not engage the posts they replied to.

Three structural defects (not wording bugs):
- **RC-1 — snippet-only context.** The Drafter and Critic saw only the 280-char opening snippet. Where the
  real ask, answer, or reveal lived in the replies (t13: the post was clickbait whose actual subject was
  revealed downthread), the snippet misled and nothing corrected it.
- **RC-2 — no replyability filter.** Polls, memes, and promos were bound and drafted as if they were
  discussions to join. Groundable was treated as replyable; an authority entry that semantically touched
  the snippet was enough to bind, even with no live conversation to add signal to.
- **RC-3 — critic stub + missing thread_fit.** The Phase-1 Claude stub passed all 13 as SHIP, and the
  rubric had no relevance/thread criterion. The cross-family veto existed on paper but did nothing this run.

Batch-level tells the per-draft gate could not see: the `[concede] — the real X is [reframe]` skeleton
appeared 5× under distinct vocabulary, and the em-dash splice ran across 4 drafts as the default move.

Root cause is **upstream context + selection, not draft wording.** The fix is the batched thread-fetch
(`00b_threads.json`, §4/§5), the Matcher replyability gate, the live-read Critic with `thread_fit`
(Rubric v1.1), and the ABORT-not-fallback degradation rule (§11). gate.sh v2.3 adds the structural-template
and em-dash-splice batch checks so the batch-level tells fail deterministically next time.

## 16. What changed from the previous version (June 2026 positioning revision)

This revision changes **content direction and grounding priorities only**. The architecture, role
structure, isolation rules, control flow, model routing, and deterministic gates are unchanged.

- **Frontmatter:** added `revised: 2026-06-15` and a `positioning` line.
- **§1 Why v3:** added the positioning rationale — scattered, theme-less binds were a second failure
  mode alongside the context problem; v3 now serves a single through-line.
- **§2 Objective:** restated so a run maps each target to a content pillar and trends toward 50/30/20,
  drafts that read like an active builder, and judges positioning + live-thread fit.
- **New "Updated Positioning (June 2026)" section:** the Core Positioning statement, the 50/30/20
  Build/Apply/Results pillars with their grounding sources, the recursive-loop differentiator, and the
  honesty guardrails (build-metrics-first in the 20% bucket; courier/day-job work stays out of the
  public narrative).
- **Matcher role (§4.2):** now maps each survivor to a content pillar before binding; prioritizes
  targets groundable in real project work over resemblance-only matches; balances the batch toward
  50/30/20; and for the Results bucket binds only on real build/process metrics, never vanity metrics.
  `01_anchored.json` now carries `content_pillar` + `project_pillar`.
- **Critic role (§4.4):** the rubric is enumerated, with `thread_fit` made explicit (meaningfully
  engages the actual live thread, not the snippet) and a new `positioning_alignment` criterion (reads
  like an active builder/user of agentic systems; Results replies must use build/process metrics). Both
  are hard gates.
- **§13 Success criteria:** added pillar-mapping, 50/30/20 batch trend, positioning alignment, and the
  build-metrics-first rule for shipped replies.

Not changed: human-review gate (never auto-post), cross-family critic veto, source honesty, the
file-artifact tone-firewall, save-and-halt, retry caps, and all of `gate.sh`. Downstream role specs
(`agents/role_specs/matcher.md`, `critic.md`) and `agents/schemas.md` should be reconciled to the
`content_pillar` field and the `positioning_alignment` criterion in a follow-up if this revision is
ratified.

### v3.1 — supply-driven architecture (2026-06-15)

Builds on the June positioning revision above. The authoritative spec for these items is the
**"v3.1 — Supply-driven architecture"** section near the top; summary of changes:

- **Inverted top-of-funnel** from demand-driven to **supply-driven (vault-first)** — fixes the binding
  cliff (3/22 bound, 0 shipped on 2026-06-15). New **Vault_Scout** stage 0b emits
  `runs/_index/search_vectors.json`; every vector is AI/agentic by rule.
- **Round-robin, non-exclusive vectors**, loop-to-target; **12 is a soft target bounded by stop
  conditions** (per-vector + global caps), not an invariant — report shortfall rather than pressure
  the gates or spin.
- **Single fetch** (Scout, for the blind Claude roles); the grok Critic's live read is part of its own
  call — no redundant re-pull, no separate confirm-fetch.
- **Retry/quarantine rewrite:** fresh Drafter instance per retry; FIX classified into draft-fixable
  (retry) vs bind-bad/thread-dead (replace via Matcher/Scout); **per-target quarantine** keeps the
  batch moving; **rate/confidence-based escalation** replaces the global SYSTEM HALT.
- **Roster (§7):** Matcher Sonnet→**Opus**; Critic settled on **grok live-read** (`grok-build`);
  Orchestrator stated as **Opus 4.8** host; **Vault_Scout** added (Sonnet).
- **Telemetry contract baked into every role** (CAK-07): per-call JSONL via `bin/trace.sh` /
  `bin/run_traced.sh`; **reject with confidence + reason, never bare FAIL** (`03_review.json` gains a
  `criteria[]` array); roll-up via `bin/batch_report.sh` → `batch_report.md`. Confidence is ordinal
  (triage/sort), never a soft override of a hard gate.

Built in this revision: `bin/trace.sh`, `bin/run_traced.sh`, `bin/batch_report.sh` (smoke-tested).
Still pending if ratified: write `Vault_Scout` role spec + the `search_vectors.json` schema; reconcile
`agents/role_specs/{matcher,critic,scout,drafter}.md`, `agents/roster.md`, and `agents/schemas.md`
(content_pillar, criteria[], confidence/reason, round-robin, quarantine) to this section; update the
orchestrate skill's control flow.

**v3.1 hardening (2026-06-15, cross-model review):** closed five production gaps found in review —
(1) "target with a floor" reworded to a **soft target bounded by stop conditions** (no infinite
`while shipped<12`); (2) **anti-staleness** for vectors — per-run query rotation, recency filter,
already-engaged-URL exclusion, and a regen TTL (was: static cache → dry in days); (3) **batch
balancing moved Matcher→Orchestrator** (the Matcher only tags `content_pillar`; balancing it would
force all-candidates-in-one-context, violating §9 isolation); (4) **defined "exhausted"** —
`MAX_FETCH_PER_VECTOR` (default 3) + `MAX_GROK_CALLS` global budget as hard stop conditions; (5)
**explicit FIX→action mapping** (v3.1.4 table) so the deterministic Orchestrator routes on the
Critic's structured per-criterion verdicts, with a retry-once-then-reclassify rule for the substance
criteria (refines the reviewer's static table — the live run showed `thread_fit` is often
draft-fixable when the bind is good).

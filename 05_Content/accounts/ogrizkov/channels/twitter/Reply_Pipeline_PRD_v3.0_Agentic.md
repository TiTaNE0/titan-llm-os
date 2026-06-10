---
type: prd
status: draft
created: 2026-06-09
supersedes: Reply_Pipeline_PRD_v2.3 (single-agent, 3 manual runs)
account: ogrizkov
channel: twitter
epic: agentic-reply-loop
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

## 2. Objective

A single orchestrator invocation that: scouts 8–12 live English in-niche threads, grounds
each 1:1 in real project work, drafts short varied human replies, asset-cards the top 1–2,
passes every deterministic + cross-family check, and writes a review queue — with each role
isolated so context never tangles. Never auto-posts. A post-cycle role logs what won.

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

### 2. Liveness+Matcher — grounding  ·  Sonnet 4.6
- **Why Sonnet (not Haiku):** liveness + 1:1 binding is a judgment call, and a wrong bind poisons
  every downstream draft of that target. Haiku's savings (~cents per run) don't cover that risk;
  Haiku stays on the mechanical roles (Asset fill, Producer assembly).
- **Input (isolated):** `00_candidates.json` + `00b_threads.json` + `project_authority.md` only.
- **Work:** apply the hard Liveness gate (corpse-drop, velocity, fresh-by-reach, English) → apply the
  **replyability gate** (drop poll/meme/promo `post_type` unless `00b_threads.json` shows a real
  discussion to join — groundable ≠ replyable) → bind 1:1 a distinct `project_authority` entry per
  survivor against `thread_gist` (no reuse), tag pillar/touches/ground_with.
- **Output:** `01_anchored.json` — `{url, author, engagement, pillar, ground_with, why_live, entry_substance, contribution, thread_gist, post_type}`. The `contribution` sentence (thread-perspective: what the reply adds to THIS thread) is the bind condition — if the Matcher cannot write it honestly, the target is dropped (**contributability gate**; 2026-06-10a lesson: topically-groundable ≠ genuinely-contributable, an entry-perspective angle manufactures pivots).
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

### 4. Critic / Judge  ·  cross-family, NON-Claude (GPT-5.5 or Grok)
- **Why non-Claude:** a model grading its own family's output is a blind spot (`MKT-02` — the
  cross-family veto is load-bearing).
- **Input (isolated):** the draft + the target URL the critic **opens and reads LIVE** (the live thread
  is the judging basis) + `thread_gist` passed ONLY as "what the drafter believed" cross-reference + the
  bound entry's claim as `grounded_claim` + a **compact rubric** of SIX criteria (voice fit, specificity
  present, no fabrication beyond the entry, not generic, length/register sane, thread_fit — does the
  reply engage the live thread's real ask/reveal, judged against the post as it is now).
- **Mandate:** REFUTE, don't grade gently — the drafter is a pathological optimist about its own
  output. Each rubric criterion must be individually gradeable (per-criterion verdict, not one
  vibe score); a draft ships only if it survives every criterion.
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
   MATCHER applies replyability filter + binds 1:1 against thread_gist → anchored. If <enough replyable+groundable: ask Scout for more.
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
| 0 | Orchestrator | `claude-fable-5` (fallback `claude-opus-4-8`) | host (Claude Code) |
| 1 | Scout | Grok (X access) | `grok -p "<brief>"` (headless capture) |
| 2 | Matcher | `claude-sonnet-4-6` | `claude -p` / sub-agent |
| 3 | Drafter | `claude-sonnet-4-6` | `claude -p` / sub-agent |
| 4 | Critic/Judge | non-Claude (`gpt-5.5` or Grok) | CLI, cross-family veto |
| 5 | Gatekeeper | — (shell) | `bin/gate.sh` |
| 6 | Asset | `claude-haiku-4-5` | sub-agent + `bin/render_asset.sh` |
| 7 | Producer | `claude-haiku-4-5` | sub-agent |
| 8 | Wins-logger | Grok | `grok -p` |

Routing rationale (2026-06-10):
- **Orchestrator → Fable 5.** The orchestrator's whole job — loop-running, retry judgment, deciding
  when to widen Scout, verification coverage — is exactly where Fable 5 is differentiated (Anthropic's
  CMA experiments: ~6× the loop-task improvement of prior Opus, resilience through failed iterations,
  full distill-and-consult memory chain). The thin coordination state makes the 2× token price
  ($10/$50 vs $5/$25 per MTok) negligible; it is also the host Claude Code session model.
- **Matcher → Sonnet 4.6.** Grounding is judgment, not extraction; a wrong bind poisons the target's
  whole downstream chain. Haiku keeps the mechanical roles (Asset, Producer) where its speed/cost wins.

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
- The failures v2 hit at the margins (length creep, opener collision, register uniformity) don't
  recur, because no single context is juggling them.
- No draft ships that could have been written without reading the live thread (thread_fit) — the
  2026-06-10 failure mode (snippet-only context, irrelevant-but-clean drafts) does not recur.
- Never auto-posts; `wins.md` fills after posting and feeds the next Scout.

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

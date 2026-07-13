---
type: reference
artifact: pipeline-overview
account: ogrizkov
channel: twitter
describes: Reply_Pipeline_PRD_v3.0_Agentic.md (version 3.1, supply-driven)
written: 2026-06-17
status: current
---

# X Reply Pipeline — How It Works Now (v3.1)

A plain-language reference for the @ogrizkov Twitter/X reply-drafting pipeline as it currently
stands. Source of truth for the spec is `Reply_Pipeline_PRD_v3.0_Agentic.md` (version 3.1); the
per-role contracts live in `agents/roster.md`, `agents/role_specs/`, and `agents/schemas.md`; the
runbook is `skill/twitter-reply-orchestrate.md`. This doc explains the system those files define.

---

## 1. What it is

A single orchestrated run that finds live X threads worth replying to, drafts grounded replies in
Evgeny's voice, judges them with an independent cross-family critic, and writes a human-review queue.
**It never auto-posts.** The operator reviews `replies_to_post.md` and posts manually.

It is NOT the Hermes marketing pipeline (`05_Marketing_System/`). Different system, different account.

---

## 2. Positioning the whole pipeline serves

**Core:** *Building agentic systems that develop, promote, and grow my projects. Sharing real
pipelines, experiments & numbers.*

**Content pillars — 50 / 30 / 20:**

| Pillar | Share | Covers | Grounds in |
|--------|-------|--------|-----------|
| **Build** | 50% | agentic systems: architecture, memory, orchestration, harnesses, reliability, context injection | `claude-agent-kit`, `TiTan_LLM_OS` (CAK-*, TIT-*) |
| **Apply** | 30% | using agents on real work: dev pipelines, growth/marketing, shipped apps | DEV-*, GRW-*, MKT-04 |
| **Results** | 20% | concrete outcomes — **build/process metrics** (reliability, retry-rate, time-saved, latency), NOT vanity (followers/impressions) | entries carrying a real number (DEV-02/06/07, CAK-06…) |

Everything downstream serves this: the Scout searches for it, the Matcher tags each reply's pillar,
the Critic checks the reply reads like an active builder.

---

## 3. The core idea: supply-driven (vault-first)

The earlier (v3.0) design was **demand-driven**: search X for what's hot, then hope a vault entry
matches. It produced a "binding cliff" — most hot threads had no honest grounding, so almost nothing
shipped (2026-06-15 run: 22 scouted → 3 bound → 0 shipped).

**v3.1 inverts it.** Index the vault FIRST into search vectors, then send the Scout to find live
threads that match what we already know we can ground in. Groundability stops being a hope and becomes
the thing we search by.

- **Load-bearing rule:** every search vector is AI/agentic — either an agentic-systems topic itself,
  or "how an agent reasoned/implemented X". This keeps every vector inside the always-hot agentic
  discourse, so live threads reliably exist for it.
- **Result (2026-06-16 run):** 22 candidates → **10 honest binds** (vs 3 demand-driven). The cliff is
  gone; the bottleneck moved downstream (see §9).

---

## 4. The roster (who does what)

| # | Role | Model | Job |
|---|------|-------|-----|
| 0 | **Orchestrator** | Opus 4.8 host (Fable 5 if available) | Runs the loop, holds thin state, routes artifacts, owns 50/30/20 balance + retry/quarantine decisions. Never ingests voice/grounding/search text. |
| 0b | **Vault_Scout** | Sonnet 4.6 | Parses `project_authority.md` → `runs/_index/search_vectors.json`. Cached; re-runs on vault change or 7-day TTL. |
| 1 | **Scout** | **grok** (`grok -p`) | Live X retrieval per vector + thread-context fetch. Only model with live X access. |
| 2 | **Matcher** | Opus 4.8 | Liveness + replyability + contributability gates (incl. domain/mechanism transfer drop — same-theme-but-mechanism-foreign binds are dropped); binds each thread 1:1 to a distinct vault entry; tags pillars. |
| 3 | **Drafter** | Sonnet 4.6 | Writes one reply per target, in voice, grounded in the bound entry. Fresh instance per retry. |
| 4 | **Critic** | **Gemini 3.1 Pro (High)** via `agy -p` (cross-family) | Judges against Rubric v1.3 from the persisted `00b_threads` snapshot, SHIP/FIX. The independent veto. Never opens the URL. |
| 5 | **Gatekeeper** | — (shell) | `bin/gate.sh` — deterministic word-range/`!`/batch-variety checks (single-draft specificity is a non-fatal WARN, not a block — owned by the Critic). No model. |
| 6 | **Asset** | Haiku 4.5 | Fills the aurora-frost card for the top 1–2 (optional). |
| 7 | **Producer** | Haiku 4.5 | Assembles `replies_to_post.md` (the human gate). Never posts. |
| 8 | **Wins-logger** | grok + orchestrator | ~1 day after posting, pulls real engagement → `wins.md`; orchestrator distills one rule per winner. |

**Cross-family veto is preserved:** the Drafter is Claude, the Critic is Gemini (via `agy -p`) — a draft is never graded
by its own model family. Independence = non-Claude family + judging from the persisted `00b_threads` snapshot (full opening
post + replies + engagement at `captured_at`). Gemini cannot browse X; the Scout enriches `00b_threads.json` with
engagement stats and `captured_at` so the Critic has a complete snapshot to judge from, without opening the URL.

---

## 5. End-to-end flow

```
0.  PROBE          grok + agy fenced-JSON probes. Either fails → ABORT (no spend).
0b. VAULT_SCOUT    project_authority.md → runs/_index/search_vectors.json (cached / 7-day TTL).
1.  ROUND-ROBIN    Orchestrator picks the next vector, biased toward the under-filled pillar (50/30/20).
                   Vectors are NON-EXCLUSIVE (one vector can yield >1 reply). Query seeds rotated per run.
2.  SCOUT (grok)   Searches that vector → live candidates + thread context in ONE fetch
                   (00_candidates.json + 00b_threads.json with engagement+captured_at). Recency-filtered; already-engaged URLs excluded.
3.  MATCHER (Opus) Corpse-drop pre-filter → replyability gate → contributability gate → 1:1 bind →
                   tag content_pillar/project_pillar/vector → 01_anchored.json (LOCK).
                   Off-vector or no-honest-contribution → back to Scout for next candidate on that vector.
4.  PER TARGET:    DRAFTER (Sonnet, fresh per retry) → GATEKEEPER (gate.sh) → CRITIC (Gemini via agy, snapshot-read).
                   FIX routing (§7) decides retry vs replace vs quarantine.
5.  STOP when:     shipped == TARGET (12, soft) OR all vectors EXHAUSTED OR grok budget hit OR
                   failure-rate breaker fires. Ship what's real; report any shortfall.
6.  ASSET          top 1–2 by views → PNG card (optional, non-fatal if render fails).
7.  PRODUCER       replies_to_post.md: ready-to-post + dropped + skipped + quarantined, all DRAFT.
                   >>> STOP. Human reviews and posts manually. <<<
8.  WINS-LOGGER    (next day) real engagement → wins.md → feeds the next Scout.
```

---

## 6. The artifact chain (every hop is a file)

| File | Writer | Holds |
|------|--------|-------|
| `runs/_index/search_vectors.json` | Vault_Scout | vectors: `{id, content_pillar, search_intent, grounds_with[], query_seeds[]}` + `generated_at` (TTL) |
| `runs/<batch>/00_candidates.json` | Scout | live candidates `{url, author, age, views, likes, replies, lang, vector, text_snippet, post_type}` |
| `runs/<batch>/00b_threads.json` | Scout | thread context + judging snapshot `{url, opening_post, top_replies[], thread_gist, engagement{views,likes,replies,quotes,reposts,bookmarks}, captured_at, replyable}` |
| `runs/<batch>/01_anchored.json` | Matcher | bound targets `{url, engagement, content_pillar, project_pillar, vector, ground_with, entry_substance, contribution, thread_gist, post_type}` |
| `runs/<batch>/02_drafts.json` | Drafter | `{url, ground_with, draft, verify_flags[]}` per target |
| `runs/<batch>/03_review.json` | Orchestrator | per-result `{gate, critic_verdict, criteria[], status, …}` + batch flags |
| `runs/<batch>/replies_to_post.md` | Producer | the human-review queue (all DRAFT) |
| `runs/<batch>/_telemetry.jsonl` | every role | one line per call (timing, tokens, verdict, confidence, reason) |
| `runs/<batch>/batch_report.md` | `batch_report.sh` | funnel counts + per-role cost + per-criterion kill-rate + per-vector yield |

The orchestrator routes these files; it never reads voice/register/grounding/search text itself. That
isolation ("tone-firewall") is the core of v3 — no role's context bleeds into the next.

---

## 7. The gates and rules (where things get killed, and why)

### Replyability — reply to DISCUSSIONS, not launches (2026-06-16 rule)
The Matcher **hard-drops** `post_type` ∈ `promo | announcement | showcase | meme | poll`. Replying to a
stranger's product launch / ship-announcement / self-showcase reads as congratulation or a self-promo
hijack — never an additive contribution. Reply **only** to `discussion` / `question` (or a genuine
technical debate that has formed in a launch's replies). The Scout deprioritizes launches; the Critic's
`thread_fit` fails them as a backstop.

### Contributability — groundable ≠ contributable
For each bind the Matcher must write a one-sentence `contribution` from the THREAD's perspective: what
the reply adds to THIS thread. If the honest sentence requires redirecting the thread toward our
project's topic, that's a pivot → DROP. (A vault entry merely touching the topic is not enough.)
**Domain/mechanism transfer (2026-06-23):** bind only if the entry's specific mechanism maps onto what
the OP is actually discussing — same theme + different mechanism/domain = DROP. **Forced-bind tell:** if
the `contribution` can only be made concrete with a proper noun/number the thread isn't about, the bind
is forced → DROP. (A cross-domain entry whose mechanism genuinely transfers still binds.)

### Gatekeeper — `bin/gate.sh` (deterministic, no LLM)
Per draft: 5–45 words, zero `!`. Missing concrete signal (digit / known tool token / mid-sentence proper
noun) is a non-fatal `GATE WARN` only — it no longer hard-fails (2026-06-23: the deterministic specificity
mandate forced noun-injection; specificity-in-context is now the Critic's `specificity_present` judgment).
`--batch` mode still hard-fails cross-draft variety (no repeated openers, structural-template, em-dash
overuse, length uniformity). Exit 0 = pass (word-range/`!`/batch ok), 1 = rewrite (word-range, `!`, or a
batch check), 2 = config error (abort; needs bash ≥4).

### Critic — Rubric v1.3 (fair-judge, recalibrated 2026-06-16; snapshot-read as of 2026-06-24)
Gemini 3.1 Pro (High) via `agy -p`. Judges from the persisted `00b_threads` snapshot (opening post + replies + engagement at `captured_at`) — never opens the URL. **Mandate: be a fair judge — SHIP
what a sharp builder would post; fail a criterion only on a MATERIAL problem, not a stylistic nitpick.**
Two tiers, confidence-gated:

- **HARD gates** (block SHIP at confidence ≥ 0.65):
  - `no_fabrication` — every claim traces to the bound entry; the post author's numbers aren't claimed
    as ours; no invented personal/employment detail. (Kept strict — this protects credibility.)
  - `thread_fit` — engages what the post is actually about, and the post is a genuine discussion (not a
    promo). Passes if it adds one real builder data point / grounded take / sharp question that speaks to
    the OP's SPECIFIC point — a data point counts only when it's about the SAME thing the OP is discussing,
    not merely the same theme. FAILS on **topic-adjacent flex** (2026-06-23): a reply that rides the broad
    theme while flexing domain-foreign jargon/numbers that don't map to the OP's point. (A cross-domain
    data point whose mechanism genuinely maps still ships.)
- **ADVISORY** (block SHIP only if egregious, ≥ 0.80; else pass with a note): `voice_fit`,
  `specificity_present`, `not_generic`, `length_register_sane`, `positioning_alignment`.
- **Cross-pass stability:** on re-judge, judge fresh and fairly — do not invent a new objection once the
  named fix landed. (This drift was the v1.2 miscalibration.)

History: v1.2 was a pure "refute, don't grade gently" mandate that rejected acceptable drafts and
invented fresh objections each pass; the 2026-06-10 Claude *stub* is the opposite ditch (shipped 13/13
garbage). v1.3 is the fair middle.

### FIX → action routing (two separate budgets)
The Orchestrator routes on the Critic's structured per-criterion verdicts (not the free-text FIX):

- **Advisory/voice fail → STYLE budget (3):** kill the Drafter instance, spawn a **fresh** Drafter with
  `{prompt + prior draft + named criterion}`. Does NOT consume the bind budget; does NOT quarantine.
  (This is "just send it back to the drafter if it's a voice issue.")
- **Hard-gate fail (`no_fabrication` / `thread_fit`) → BIND budget:** draft-fixable ONCE; if the same
  hard gate fails again → **bind-bad** → return to Matcher/Scout for a replacement on that vector.
- **Immediate bind-bad:** post dead/locked or drifted.
- **Quarantine** (keep the batch moving, record reject history) when the bind budget is spent + one
  replacement failed, OR the style budget is exhausted with an advisory still failing.

### 12 is a soft target, not an invariant
The loop runs toward 12 but is bounded by stop conditions (per-vector cap, global grok budget, vectors
exhausted, failure-rate breaker). When supply is short it ships what's real and reports the shortfall —
never spins, never pressures a gate to pass a marginal draft.

---

## 8. Telemetry (CAK-07 applied)

Every role appends one JSONL line via `bin/trace.sh` (CLI roles wrapped in `bin/run_traced.sh`, which
adds wall-clock + char/4 token proxies since grok doesn't report tokens). Rejects carry a **confidence
(0–1) and a one-line reason** — confidence is ordinal (triage/sort), never a soft override of a hard
gate. `bin/batch_report.sh <run-dir>` rolls it all up into `batch_report.md`: the funnel, per-role
cost/latency, per-criterion kill-rate, per-vector yield, and the quarantine list. This is what makes the
funnel debuggable — when a run underperforms, the report says which criterion/vector/role is responsible.

Two logs, kept separate, both feed the Scout: `_telemetry.jsonl` (why the funnel leaks — gate behavior)
and `wins.md` (what the audience rewarded — post-posting engagement).

---

## 9. Honest current status & the next lever

**What works:** supply-driven binding (10 vs 3), clean FIX-routing, honest skips, telemetry, the fair v1.3
critic clearing genuine-discussion drafts.

**The live bottleneck:** topic-matching vectors **over-surface product launches**. On the 2026-06-16
window, 10 binds were mostly showcases/announcements; after the promo-drop rule the real yield was **2
genuine-discussion targets** (one of them a 61k-view thread). The cross-family critic is calibrated fairly
now; the constraint is target *type*.

**Next-run lever:** bias the vault vectors and Scout queries toward **debates / questions / problem-threads**
("why does X fail", "how do you handle Y", hot takes), not topic-matches — topics return launches,
questions return conversations. That's the single change most likely to fill the funnel.

---

## 10. How to run it

The host Claude Code session IS the orchestrator. In practice: invoke the orchestrate skill /
ask the session to run a batch. It will:
probe grok → (re)build search_vectors if stale → round-robin scout+match toward 12 → draft/gate/critic
loop → write `runs/<YYYY-MM-DD>_batch/replies_to_post.md` → stop for review.

**Prereqs:** `grok` CLI logged in (Scout + Wins-logger); `agy` CLI logged in and responding (`~/.local/bin/agy`, Google Antigravity — required for the Critic); bash ≥4 at
`/opt/homebrew/bin/bash`; `python3`; `project_authority.md` current (drives the vectors); `voice.md` +
`reply_register.md` + `drafting_contract.md` for the Drafter.

**Hard rule:** if grok fails to inference at any stage, the run halts (SAVE-AND-HALT) rather than
substituting a model or stubbing the critic. Nothing is ever auto-posted.

---

## 11. Failure policies

- **SAVE-AND-HALT (universal):** any role whose output is unobtainable (credits, auth, dead CLI, sub-agent
  fails ×2, no fenced block after one re-prompt) → save artifacts, write `runs/<batch>/HALT.json`, stop all
  downstream stages, resume from `next_stage` when the blocker clears. Never substitute/stub/improvise a model.
- **Critic degradation:** if the agy/Gemini critic can't be invoked mid-run (unreachable / no fenced block / print-timeout self-abort after 10m) → ABORT, all results `held`,
  `critic: UNAVAILABLE`, loud held-line. The Claude stub is scaffold-test-only, NEVER a runtime fallback
  (2026-06-10 proved it ships irrelevant drafts as SHIP).

---

## Appendix — key files

- PRD / spec: `Reply_Pipeline_PRD_v3.0_Agentic.md` (v3.1)
- Roster: `agents/roster.md` · Role specs: `agents/role_specs/{vault_scout,scout,matcher,drafter,critic,asset,producer,wins}.md`
- Schemas: `agents/schemas.md` · Runbook: `skill/twitter-reply-orchestrate.md`
- Gate: `bin/gate.sh` · Telemetry: `bin/{trace,run_traced,batch_report}.sh` · Scaffold validator: `bin/verify_v3_scaffold.sh`
- Grounding: `project_authority.md` · Voice: `../../voice.md` + `reply_register.md` + `drafting_contract.md`
- Latest run: `runs/2026-06-16_batch/` (2 ready, 6 promo-dropped, 2 skipped)

> Note (2026-06-17): the v3.1 spec edits (critic v1.3, promo-drop in matcher/scout, orchestrate split
> budgets, the v3.1 build) are on disk and validator-green but **uncommitted** pending the operator's
> commit/graduate call. The telemetry scripts are built and smoke-tested.

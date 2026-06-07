---
type: prd
status: draft
created: 2026-06-07
supersedes: Agentic X (Twitter) Reply Pipeline v2.0
account: ogrizkov
channel: twitter
---

# X Reply Pipeline — PRD v2.1 (Grok Build edition)

Refactor of v2.0 for the **real** runtime: Grok Build CLI + Composer 2.5. Personal
account workflow for **@ogrizkov** — not the Hermes marketing pipeline. Binds to the
voice/strategy files that already exist in this folder.

> **Rev 2026-06-07 (external review):** (1) split into TWO separate runs — a continuous
> session that pauses for human input is fragile; (2) `search_x` is raw retrieval, so
> relevance scoring is an explicit LLM pass, not a tool feature; (3) the code gate runs
> in-loop (agent calls it before finalizing), not as a post-write hook on a closed session.

## What changed from v2.0 (the deltas)

1. **Runtime is real now.** Grok Build has built-in `search_x` + `search_web` tools,
   parallel subagents, plan mode, and reads `AGENTS.md`/skills/hooks/MCP. So Stage 1
   needs no scraper, and the "orchestrator" is Grok Build itself — not a `reply_master.sh`.
2. **Claude is out.** Model is **Composer 2.5** (Grok Build native). All "Claude 3.5 /
   Composer 2.5 via Cursor" language deleted.
3. **Drafter is a POLISHER, not a generator.** This is the load-bearing fix. v2.0's
   autonomous ghostwriter violated this account's own [[drafting_contract]]
   (*"Evgeny drafts, AI polishes… fabricated experience is the one unrecoverable failure"*).
   v2.1 inserts a human **experience-anchor** step between scout and draft.
4. **`<80k followers` hard-drop → relevance score.** The niche target audience
   (indie/agentic/local-first builders) is mostly under 80k; a hard drop deletes them.
5. **Volume/zero-edit metrics removed.** No "8–12/day", no ">85% zero-edit". Replaced
   with the existing doctrine: *skip is free, quality only*.

## Objective

Manual-trigger, guardrailed system that turns "a hot X thread + my real take" into a
voice-accurate reply draft for human approval. Runs entirely on the Grok Build / SuperGrok
subscription. Never auto-posts.

## Stack (verified)

- **Orchestrator:** Grok Build CLI (plan mode + subagents). No master bash script.
- **Discovery:** Grok Build `search_x` tool (live X read, no API wall).
- **Model:** Composer 2.5 (function-calling, MCP, cheap, long instruction-following).
- **Brain (already exists, do not rebuild):** [[voice]] · [[drafting_contract]] ·
  [[strategy]] · `analysis/` · [[modules/twitter/drafting_partner]].
- **Deterministic guardrail:** one tiny bash script (`bin/gate.sh`).
- **Storage:** this vault, under `channels/twitter/runs/`.

## Workflow — TWO physically separate runs with a file handoff

The pipeline does NOT run as one continuous session that pauses for your input — an
agentic CLI suspended mid-run for human terminal input times out and drops context.
Instead it splits at the human anchor into two independent `grok` invocations. Each run
is stateless: it reads a file, does its work, writes a file, and exits. (Same handoff
discipline the rest of the vault uses.)

### RUN 1 — Scout (terminates with a file you then annotate offline)

**Stage 1 — Retrieve, then score.** Two distinct operations, because `search_x` is a raw
retrieval tool — it returns unfiltered posts, it does NOT rank by your niche:
1. `search_x` call(s) → grab raw threads in the niches (agentic workflows, Claude
   Code/Grok Build, memory, local-first, builder experience).
2. **LLM scoring pass** (subagent) → spam-filter + score each thread for indie-builder/
   agentic relevance (signal, **not** follower count) + drop low scorers.

Output: `01_candidates.json` (url, author, hook summary, relevance_score, why-relevant,
empty `anchor` field per thread). **Run 1 exits here.**

**Stage 1.5 — Anchor (HUMAN, offline, no live session).** At your own pace, open
`01_candidates.json` (or its Obsidian view), pick the threads worth replying to, and fill
the `anchor` field with **one raw line of your real take/experience**. Delete the rest.
Save as `02_anchored.json`. No anchor → that thread is not drafted. This is the
authenticity gate — it keeps every draft a polish of *your* substance, never a fabrication.

### RUN 2 — Draft (ingests the anchored file, runs straight through)

**Stage 2 — Analyst.** Reads `02_anchored.json` + `strategy.md` + latest `analysis/`.
Maps what's currently working onto the angle. Output: `03_tactical_brief.json` — per
thread: `suggested_hook`, `tone_adjustment`, `asset_recommendation` (from `05_Assets/`,
optional). (Analytics seeded from the static `analysis/` files; live-metric read deferred.)

**Stage 3 — Draft + Gatekeeper (gate runs IN-LOOP, pre-finalize).** For each anchored
thread, Composer 2.5 drafts in Evgeny-B shape using `voice.md` + `drafting_contract.md`,
seeded by anchor + brief. The gate is **invoked by the agent during the draft loop, before
the final file is written** — not as a post-write shell hook on a closed session:
1. **3-gate skip** (from drafting_contract): experience anchor present · not an intent
   post · not agreement-only. Any trip → **skip**, log it, move on.
2. **Code gate** — agent calls `bin/gate.sh <draft>` as an in-loop tool: `wc -w` ∈ [25,45];
   zero `!`. Exit 0 = accept; exit 1 = the agent rewrites and re-checks (cap 2 retries).
   The retry lives in the agent's reasoning; the script is just the deterministic check.
3. **Truthfulness** — every concrete claim traces to the anchor or a verifiable prior post.

Output: `05_review_queue.md` — final human gate. **Backstop (optional):** a post-write hook
re-runs `gate.sh` over the finished queue and *hard-flags* (does not retry) any draft that
slipped, so a violation can never reach you silently.

## Authenticity binding (non-negotiable)

The drafter NEVER invents experience, hardware, tools, numbers, or workflow. When tempted
to add a claim not in the anchor → **stop and ask**. Per [[drafting_contract]]. ESL texture
preserved, never sanded to clean native English. Private day-job details never referenced (see voice.md).

## Directory layout

```
05_Content/accounts/ogrizkov/
├── voice.md                 (exists — canonical voice, ACCOUNT-level — shared across channels)
└── channels/twitter/
├── drafting_contract.md     (exists — skip gates + truthfulness; reads [[accounts/ogrizkov/voice]])
├── strategy.md              (exists — tactical layer)
├── analysis/                (exists — reply metrics reviews)
├── Reply_Pipeline_PRD_v2.1.md   (this file)
├── bin/
│   └── gate.sh              (NEW — wc/grep code gate + retry)
├── skill/                   (NEW — Grok Build skill: the 3-stage runbook)
└── runs/
    └── YYYY-MM-DD_batch/
        ├── 01_candidates.json
        ├── 02_anchored.json
        ├── 03_tactical_brief.json
        └── 05_review_queue.md   (human gate)
```

## Build scope

**Day 1 (minimal — gets drafts today):**
- **Two Grok Build skills/commands**, matching the two runs:
  - `scout` (Run 1) → `search_x` + LLM scoring pass → `01_candidates.json`, then exit.
  - `draft` (Run 2) → ingest `02_anchored.json` → analyst → draft → in-loop gate →
    `05_review_queue.md`. Bound to `voice.md` + `drafting_contract.md`; carries the 3-gate skip.
- `bin/gate.sh` — ~10-line deterministic word/`!` check (exit 0/1), called by the `draft`
  agent in-loop; optionally re-run as a post-write backstop hook.
- `runs/` output convention + the JSON handoff shapes (incl. the empty `anchor` field).

**Deferred (after first real runs):**
- Splitting Analyst into its own parallel subagent.
- `asset_recommendation` auto-attach from `05_Assets/`.
- `search_web` enrichment, image/video tools.
- Any standing automation — stays manual-trigger.

## Success (realistic)

- A run ends with a populated `05_review_queue.md` you'd actually post (after light edits)
  OR an honest "skip — no anchor-worthy thread today." Both are success.
- No fabricated experience reaches the queue. (The one unrecoverable failure.)
- Zero out-of-pocket beyond the Grok subscription.

## Open unknowns (resolve by running, not guessing)

1. **`search_x` quality** — does it surface genuinely good niche threads, or noise? Unknown
   until first run. Cheap to test.
2. **Skill mechanics** — exact Grok Build skill path/format and whether `bin/gate.sh` runs
   as a hook vs. a shell call from the skill. Confirm at build time against Grok Build docs.
3. **Analytics read** — can `search_x` pull *your own* recent reply metrics reliably, or is
   Stage 2 seeded from the static `analysis/` files for now? Default to `analysis/` if flaky.

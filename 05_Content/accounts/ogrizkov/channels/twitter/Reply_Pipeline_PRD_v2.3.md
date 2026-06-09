---
type: prd
status: draft
created: 2026-06-08
updated: 2026-06-09
supersedes: Reply_Pipeline_PRD_v2.1 (v2.2 withdrawn — wrong grounding source)
account: ogrizkov
channel: twitter
pillars: [development, agentic, marketing]
---

# X Reply Pipeline — PRD v2.3 (project-anchored, 3-pillar edition)

The first live runs (2026-06-08/09) exposed three problems, fixed here. (1) Replies were
grounded only in abstractions → nine near-identical posts, ~0 engagement. (2) The scout's scope
was too narrow on both ends — Hunt A read its example keywords as a whitelist (no GPT, no Chinese
models), and grounding was limited to 2 AI projects. (3) The scout's reply-opportunity rule had
no lower bound and selected **dead posts** (0 likes / 2–10 views / 0 replies), where a reply is
invisible. This PRD anchors grounding in Evgeny's **real projects across 3 pillars**, broadens
the scout, and adds a **liveness floor**.

> v2.2 (withdrawn) auto-mined all of `04_Logs` and pulled off-brand trivia + a private-life
> detail that has no place in public content. Corrected: grounding is curated from project
> passports across 3 pillars and carries **no personal-life facts at all** — only the projects'
> technical substance. (`nearest-address-codes` is a delivery/logistics PWA; the product and its
> engineering are fair game; the person behind it is simply not in the file.)

## Root causes → fixes

### 1. Grounding was abstractions → `project_authority.md`, 3 pillars (built)
The drafter's only concrete source was the abstract "converting angles" list, so it produced
abstractions, nine times. Fixed by grounding each reply in a real, source-tagged entry from
`project_authority.md`, now structured into three pillars:
- **Development** — `road-assist` (Java/Spring microservices), `nearest-address-codes`
  (Next.js PWA, offline-first), `Intuiscale` (iOS Swift), `Voice_Cloning_Bot` (hybrid TTS).
  The credibility floor: proof he ships real products.
- **Agentic / work systems** — `claude-agent-kit`, `TiTan_LLM_OS`. The differentiated lead.
- **Marketing / growth** — `05_Marketing_System`, `LinkedIn_Automation`, faceless content modules.
Through-line: AI/agent voice leads; dev grounds credibility; marketing is its own lane.

### 2a. Scope too narrow → Hunt A broad, Hunt B all 3 pillars (scout rewritten)
- **Hunt A** = ALL hot AI, no whitelist: GPT/OpenAI, Chinese models (DeepSeek, Qwen, Kimi, GLM,
  MiniMax), any release/hype, plus Claude Code / Grok Build / MCP. Example terms are not a filter.
- **Hunt B** = project-domain threads across all 3 pillars (dev + agentic + marketing vocab).

### 2b. 1:1 entry binding (draft skill) — the variety mechanism
Each target binds one distinct `project_authority.md` entry, no reuse in a batch. N targets force
N entries → repetition is structurally impossible and every reply carries real substance.

### 3. Dead-post selection → liveness floor + velocity (scout rewritten)
The reply-opportunity rule only had an upper bound (don't drown in mega-threads) and optimized
toward zero. Added a **lower bound**:
- **Reject corpses:** a target older than ~2h with near-zero reach (≈ <50 views, 0 replies, 0
  likes) is dropped — a reply there is seen by no one.
- **Don't be fooled by fresh:** a <45-min-old post with low counts is new, not dead — judge it by
  the OP's reach/history and topic heat, not its current 2 views.
- **Prefer velocity + conversation;** keep the anti-drown upper bound. **Target the live middle band.**
- Plus **analytics honesty:** stop lifting our own 0-engagement replies and listing them as
  "proven-converting angles" (the 2026-06-09 feed did exactly this — a self-reinforcing garbage
  loop). Converting signal comes only from genuinely engaged posts or `../analysis/`.

### Gate (kept, tested)
`bin/gate.sh` unchanged: per-draft word/`!`/specificity + `--batch` anti-uniformity. Verified it
FAILs the posted batch (`'memory' in 9/9`) and PASSes a varied one.

## Workflow (current)

```
RUN 1 — Scout  (positive output spec, three moves)
  DISCOVER  what's hot on X now — live, broad, whitelist-free (the frontier moves weekly) + our
            domains (dev + agentic + marketing vocab) — 24–48h
  MATCH     each hot thread to a project_authority entry we can speak to (groundability = keeper)
  LEARN     read runs/_analytics/wins.md + prior feeds; bias toward what has converted for us
  → reply_feed.md  (targets ranked; each: found_via, pillar, touches:<project>, ground_with:<entry id>,
                    engagement/liveness read; + analytics summary + brief reject notes)
  exit

  Good target = a live thread with momentum (seen, not drowned); fresh posts judged by author reach.
  The skill is written as what we NEED AS OUTPUT, not a list of don'ts.

RUN 2 — Draft
  Bind 1 project_authority entry per target, 1:1, no reuse, respect cooldown
  Draft in Evgeny-B voice = tweet + bound entry.substance/angle + voice
  in-loop gate.sh (word/!/specificity)  →  gate.sh --batch over the queue
  → replies_to_post.md (human gate). Never post.
```

## Files

```
channels/twitter/
├── project_authority.md          (3-pillar grounding: DEV-/CAK-/TIT-/MKT-/GRW- entries)   ✅
├── Reply_Pipeline_PRD_v2.3.md     (this file)                                              ✅
├── bin/gate.sh                    (specificity + --batch, tested)                          ✅
├── skill/twitter-reply-scout.md   (positive spec: Discover → Match → Learn; live-target def)  ✅
├── skill/twitter-reply-draft.md   (ground in project_authority, 1:1, personal-life scrubbed)  ✅
└── runs/
    ├── _analytics/wins.md         (NEW — logged best performers; the LEARN input)            ✅
    └── <date>_batch/              (feed + queue from live runs)
```

Deleted: `experience_ledger.md`, `Reply_Pipeline_PRD_v2.2.md`, the stray
`runs/2026-06-08_batch/replies_to_post.md` rewrite.

## Success criteria
- Feed targets are **live** (no corpses), tagged by pillar + `ground_with` entry, spanning dev /
  agentic / marketing as the day's threads allow.
- A batch's replies bind to distinct entries; no two share a core claim; each names a real
  specific. `gate.sh --batch` passes. Or honest "skip — too few live, groundable threads today."
- No fabricated experience, no operator personal-life reference, no hardware flex.
- Real test is engagement on live threads with actual eyeballs — the liveness floor is what makes
  that measurable at all.

## Open unknowns (resolve by running)
1. **Liveness thresholds.** The ~2h / <50-views corpse cutoff is a first guess; tune from real
   feeds. The fresh-post OP-reach judgment is the hardest call — watch for false "fresh" picks.
2. **Pillar balance.** Does the feed over-index on one pillar? If dev/marketing threads are thin
   some days, agentic carries; that's fine.
3. **Does project-anchored + live convert** on a small account? Unknown until posted into threads
   that actually have an audience. Assets + spacing are the next levers.

---
type: grounding_source
account: ogrizkov
channel: twitter
created: 2026-06-08
updated: 2026-06-09
status: seed
pillars: [development, agentic, marketing]
anchor_projects:
  development: [nearest-address-codes, road-assist, Intuiscale, Voice_Cloning_Bot]
  agentic: [claude-agent-kit, TiTan_LLM_OS]
  marketing: [05_Marketing_System, LinkedIn_Automation, content-modules]
source_of_truth: 01_Projects/ passports + 03_Brain/System_Agents.md + 05_Marketing_System/ + 06_Research/
---

# Project Authority — @ogrizkov

The grounding layer for replies. Curated from Evgeny's **real projects** — never mined blindly
from `04_Logs`. The account's through-line: **he builds real products AND the agent + marketing
systems that ship and promote them.** Three pillars, all valid grounding:

- **Pillar 1 — Development** (credibility floor): real shipped software — `road-assist`
  (Java microservices), `nearest-address-codes` (Next.js PWA), `Intuiscale` (iOS Swift),
  `Voice_Cloning_Bot` (hybrid TTS). Proof he ships, not just tweets.
- **Pillar 2 — Agentic / work systems** (the differentiated lead): `claude-agent-kit`,
  `TiTan_LLM_OS` — agent-agnostic orchestration, LLM-OS, kernel rules, error recovery.
- **Pillar 3 — Marketing / growth systems**: `05_Marketing_System` multi-agent pipeline,
  `LinkedIn_Automation` stealth pipeline, the AI content modules — both the **faceless** route
  and the **UGC / AI-character** route (the AI-influencer space, not just faceless).

Voice lead is the AI/agent angle; dev grounds credibility ("I ship real Swift/Java/Next.js,
here's what the agent system does to that workflow"); marketing is its own strong lane.

## Hard scope (read before grounding anything)

- **Ground only in the technical substance below.** The operator's personal life and employment
  are out of scope — they are not in this file and must not be inferred into a reply. Reply as the
  builder of these projects, full stop. (`nearest-address-codes` is a delivery/logistics PWA built
  for couriers — that's the product's purpose and is fine to discuss as a product. Nothing about
  who runs it.)
- **No hardware/perf flexes** ("ran X on a Mac Mini at N tok/s"). Architecture level, not gadget.
- **Source honesty** (same rule as `05_Marketing_System/schemas/scout_schema.md`): every entry
  cites where the fact comes from; numbers only if documented; otherwise general version or
  `[VERIFY: ...]`. No invented metrics.
- **Stealth / anti-detection substance is excluded from public reply grounding.** Entries whose substance is bot-detection evasion, fingerprint/behavioral-entropy stealth, or anti-detection timing (e.g. GRW-01, GRW-02) are NOT for public reply grounding — they are reputational landmines. They stay in this file as authority context but are excluded from public replies; the Matcher must never bind them. Marked per-entry with `reply_scope: excluded`.

## Schema

```
### <ID> — <handle>
- pillar: <development | agentic | marketing>
- project: <name>
- evidence: <passport / board / brain-file / log + section>   # traceable, never invented
- substance: <the real thing — verbatim-grounded>
- angle: <the take it supports — one line, his lane>
- tags: <topics a scouted thread must touch to bind this>
- postable_as: <experience | opinion | honest-gap>
- reuse: <cooldown days>
```

===============================================================================
# PILLAR 1 — DEVELOPMENT (real shipped software)
===============================================================================

### DEV-01 — road-assist: real-time safety microservice
- pillar: development
- project: road-assist
- evidence: `01_Projects/road-assist.md` (Core Mission + Tech Stack)
- substance: Java 21 / Spring Boot 3.3 community road-safety microservice — accepts hazard/SOS reports, scores them with trust-based consensus, indexes live events in reactive Redis Geo (hot path), broadcasts over STOMP WebSockets, RabbitMQ messaging, deployed on AWS il-central-1.
- angle: Real-time geo + trust-consensus is a distributed-systems problem; the model doesn't help here, the architecture does.
- tags: [java, spring, microservices, real-time, redis, websocket, distributed-systems, backend]
- postable_as: experience
- reuse: 7d

### DEV-02 — killed the hand-maintained API spec
- pillar: development
- project: road-assist
- evidence: `04_Logs/2026-05-08` (Auto_Generate_OpenAPI_Spec_From_Code)
- substance: Deleted a 522-line hand-maintained openapi.yaml; springdoc-openapi 2.3.0 now generates the spec live from code at `/v3/api-docs`, JWT scheme included, Swagger UI gated in prod. 3 tests verify the contract.
- angle: A hand-maintained API spec drifts on every controller change; generating it from code is the only version that stays true.
- tags: [api, openapi, drift, contract, java, backend, single-source-of-truth]
- postable_as: experience
- reuse: 7d

### DEV-03 — consistency audit before prod
- pillar: development
- project: road-assist
- evidence: `04_Logs/CONSISTENCY_AUDIT_2026-05-08.md`
- substance: A pre-prod consistency audit caught 3 criticals: confidence hardcoded to 100% (demo mode left in), API response field-name chaos, and a DDL wipe risk. Blocked deploy until fixed.
- angle: The bug that kills you in prod is usually the demo-mode shortcut nobody removed; an audit step is cheaper than the incident.
- tags: [eval, audit, reliability, drift, backend, pre-prod]
- postable_as: experience
- reuse: 7d

### DEV-04 — nearest-address-codes: offline-first PWA
- pillar: development
- project: nearest-address-codes
- evidence: `01_Projects/nearest-address-codes.md` (Product Surface + Tech Stack)
- substance: Next.js 16 (App Router) / TypeScript strict PWA for couriers — Neon Postgres, Clerk auth, SWR/Zod, STOMP real-time, Vitest/Playwright. Offline-first runtime: cached nearby data, queued submissions, push notifications, background sync. List / Focus / Zen workspace modes.
- angle: Offline-first on the web is its own discipline — queue, sync, cache invalidation — long before any AI enters the picture.
- tags: [pwa, offline-first, nextjs, typescript, frontend, sync, web]
- postable_as: experience
- reuse: 7d

### DEV-05 — offline cold-launch hardening
- pillar: development
- project: nearest-address-codes
- evidence: `04_Logs/2026-05-18` (Offline_Cold_Launch_Hardening)
- substance: A Workbox precache gap (locale-root HTML emitted outside the webpack graph) made the iPhone PWA loop `/offline.html` on airplane-mode cold launch. Fixed with additionalManifestEntries for locale shells + version-suffixed cacheNames to beat WebKit cache-ghosting. Real-device verified from the Home Screen in airplane mode.
- angle: PWA offline bugs only show up on a real device in airplane mode; the simulator lies to you.
- tags: [pwa, offline, service-worker, workbox, ios, web, debugging]
- postable_as: experience
- reuse: 7d

### DEV-06 — the precision bug hiding in a rounded URL
- pillar: development
- project: nearest-address-codes
- evidence: `04_Logs/2026-05-22` (Fix_Addresses_URL_Rounding_Bug)
- substance: SWR rounded lat/lng to 3 decimals (~110m grid) and baked them into the fetch URL, so the server ranked from the rounded center and missed the true-nearest address 30-50% of the time. Hidden for weeks; only surfaced when a later change tightened coordinate noise to ≤5m. Fix pins the precision contract (≥5 decimals) with a regression test.
- angle: A rounding bug can sit invisible until an unrelated change exposes it; the regression test that pins the contract is the real fix, not the patch.
- tags: [bug, precision, regression, geo, frontend, self-correction, evolving-codebase]
- postable_as: experience
- reuse: 7d

### DEV-07 — localization at scale with parallel sub-agents
- pillar: development
- project: Intuiscale
- evidence: `04_Logs/2026-05-20` / `2026-05-21` (Localization V3)
- substance: iOS Swift app localized to 8 locales — 2,253 translations merged, 100% coverage on both catalogs, done by 3 parallel background sub-agents (one per locale), each fed a strictly-scoped delta so V1 work stayed untouched. Cultural-anchor rates tracked per locale.
- angle: Parallel sub-agents only stay consistent when each gets its own scoped slice; without the scoping they overwrite each other.
- tags: [ios, swift, localization, sub-agents, parallel, orchestration, scale]
- postable_as: experience
- reuse: 7d

### DEV-08 — an agent-friendly iOS build harness
- pillar: development
- project: Intuiscale
- evidence: `04_Logs/2026-05-27` (Makefile_Xcbeautify)
- substance: A root Makefile wrapping `xcodebuild | xcbeautify` with a scheme split (unit vs UI) and `make doctor/build/test/ui-test`, so a fast unit gate runs every commit instead of the full slow suite each time. (No per-commit timing figure is documented for this iOS harness — do not state one; any "minutes vs estimate" number you may have seen belongs to a separate Java/Gradle test-split task, not here.)
- angle: The eval step has to be fast or it won't run every time; splitting the slow tests out is what keeps the fast gate honest — and it's what makes the codebase agent-drivable.
- tags: [ios, swift, ci, test-split, makefile, harness, eval, loop-speed]
- postable_as: experience
- reuse: 7d

### DEV-09 — Voice_Cloning_Bot: hybrid local/cloud TTS
- pillar: development
- project: Voice_Cloning_Bot
- evidence: `01_Projects/Voice_Cloning_Bot.md` (Core Mission + Tech Stack)
- substance: A multi-tenant Telegram TTS/voice-clone bot with a triple-tier strategy — local Qwen3-TTS on MPS (dev), RunPod serverless (premium), ElevenLabs fallback — a weighted credit economy (local 1× vs ElevenLabs 25×), zero-binary transfer via Cloudflare R2, FK-enforced per-user voice isolation.
- angle: A tiered local→cloud fallback with a credit economy is how you ship a real product on top of expensive APIs without the bill owning you.
- tags: [tts, local-first, hybrid, product, multi-tenant, cost, r2, python]
- postable_as: experience
- reuse: 7d

===============================================================================
# PILLAR 2 — AGENTIC / WORK SYSTEMS (the differentiated lead)
===============================================================================

### CAK-01 — the runner is swappable, the vault is the brain
- pillar: agentic
- project: claude-agent-kit
- evidence: passport Core Mission
- substance: A decoupled, agent-agnostic orchestration layer bridging cloud LLMs (Claude Code, OpenCode, etc.) to a local Obsidian vault. The model is a replaceable runner; the intelligence lives in the vault, not chat history.
- angle: The primitive most builders skip isn't a better prompt — it's putting the intelligence in files so the model stays swappable.
- tags: [agent-agnostic, orchestration, claude-code, opencode, editor-vs-loop, llm-os, local-first]
- postable_as: experience
- reuse: 7d

### CAK-02 — the handshake before any work
- pillar: agentic
- project: claude-agent-kit
- evidence: passport Key Components #1 (AGENTS.md root loader)
- substance: An AGENTS.md root loader identifies the project and bridges into the vault before the agent touches anything — identification + context bridge first, work second.
- angle: Reliable agents start with a handshake, not a prompt; the loader runs before the model gets to act.
- tags: [agents-md, claude-md, boot, context, harness, plan-first, security]
- postable_as: experience
- reuse: 7d

### CAK-03 — one kernel file, no duplicate rules
- pillar: agentic
- project: claude-agent-kit
- evidence: passport Components #2 + Hard Constraint 2
- substance: System_Agents.md is the kernel — 20+ macros plus the error-recovery framework — and a hard constraint keeps ALL global rules there. No duplicate rule files. Single source of truth.
- angle: When agent rules sprawl across files they drift; one kernel file is a constraint, not a preference.
- tags: [claude-md, agents-md, rules, single-source-of-truth, drift, kernel]
- postable_as: opinion
- reuse: 7d

### CAK-04 — error recovery as a first-class layer (and the honest gap)
- pillar: agentic
- project: claude-agent-kit
- evidence: passport Components #2 + Known Gaps
- substance: An error-recovery framework with defined E1–E5 error classes. Honest current state: the classes exist but aren't yet hooked into every macro — an open gap on the board, not a finished feature.
- angle: Most "reliable agent" talk skips error taxonomy; defining the classes is step one, wiring them into every call is the unglamorous rest — and I'm still mid-wiring.
- tags: [error-recovery, reliability, harness, agent-design, runaway-loop]
- postable_as: honest-gap
- reuse: 7d

### CAK-05 — five roles, not one do-everything agent
- pillar: agentic
- project: claude-agent-kit
- evidence: passport Components #3 (Agent_Roles.md)
- substance: Five defined personas — Executioner, Architect, Researcher, Synthesizer, Content Producer — each a bounded role rather than one general agent.
- angle: Splitting the agent into bounded roles beats one prompt trying to be all of them; the boundaries are where reliability comes from.
- tags: [sub-agents, roles, orchestration, agent-design, multi-agent]
- postable_as: experience
- reuse: 7d

### CAK-06 — context injection is budgeted, not "inject everything"
- pillar: agentic
- project: claude-agent-kit
- evidence: passport Components #4 (Context_Injection_Protocol, 8 steps); the 30% token-budget cap detail in `04_Logs/2026-05-16`
- substance: An 8-step boot sequence. Injection is budgeted — a token-budget cap with explicit drop priority and a verification check before work — not a dump of all available context.
- angle: A memory/context layer only helps if it's budgeted; uncapped "remember everything" is the cold-start cost moved up a layer.
- tags: [context, memory, cold-start, token-budget, claude-md]
- postable_as: experience
- reuse: 7d

### CAK-07 — every macro emits telemetry as its last step
- pillar: agentic
- project: claude-agent-kit
- evidence: passport Hard Constraint 4 (emit_telemetry.sh) + `04_Logs/2026-05-16`, `2026-05-05`
- substance: Hard constraint: every macro emits telemetry via emit_telemetry.sh as its final step. Append-only JSONL, best-effort, never blocks the run.
- angle: Eval-in-the-loop only survives if it's append-only and non-blocking; the moment instrumentation can stall a run, it gets turned off.
- tags: [telemetry, eval, observability, in-the-loop, harness]
- postable_as: experience
- reuse: 7d

### CAK-08 — frozen structure, typed macros
- pillar: agentic
- project: claude-agent-kit
- evidence: passport Hard Constraints 3 & 5
- substance: Vault structure is frozen — no renaming directories, no parallel task systems. New macros must carry frontmatter: name, description, error_recovery_class.
- angle: Freezing the structure and typing every macro is boring discipline, and it's exactly what stops an agent system from rotting into chaos.
- tags: [discipline, structure, macros, agent-design, maintainability]
- postable_as: opinion
- reuse: 7d

### CAK-09 — honest open gaps (build-in-public)
- pillar: agentic
- project: claude-agent-kit
- evidence: passport Known Gaps & Proposals
- substance: Real current gaps: the content pipeline lives in the vault but isn't yet wired into the agent-selection UI; weekly synthesis runs on-demand, not scheduled; error classes not yet hooked into every macro.
- angle: Stated flat, as the bio promises — what's built, what's still open. No arc, no hype.
- tags: [build-in-public, honest-frictions, roadmap, agent-design]
- postable_as: honest-gap
- reuse: 7d

### TIT-01 — the brain/runner split
- pillar: agentic
- project: TiTan_LLM_OS
- evidence: passport Core Mission + `06_Research/TiTan_LLM_OS_Research.md`
- substance: A local LLM operating system where intelligence lives in Markdown and is decoupled from whichever agent runs it; tool-agnostic via an AGENTS.md loader + a `.vault_link` symlink, so any runner reads the same brain.
- angle: Decouple the brain from the runner and the model becomes a worker reading blueprints — that's the whole bet.
- tags: [llm-os, tool-agnostic, local-first, agents-md, architecture, brain-runner, portability]
- postable_as: experience
- reuse: 7d

### TIT-02 — plan-first, before execute
- pillar: agentic
- project: TiTan_LLM_OS
- evidence: `06_Research/TiTan_LLM_OS_Research.md` (Local Bootloader & Workflow)
- substance: Two-step workflow baked into the loader — read the bootstrap, then execute under a PLAN ONLY directive first. Plus anti-token-waste rules (no glob/find, session-start log read).
- angle: Plan-first isn't a habit you remember to do; it's a directive in the loader that runs before the agent can touch anything.
- tags: [plan-first, harness, discipline, agents-md, token-waste]
- postable_as: experience
- reuse: 7d

===============================================================================
# PILLAR 3 — MARKETING / GROWTH SYSTEMS
===============================================================================

### MKT-01 — six bounded roles, model routing per step
- pillar: marketing
- project: 05_Marketing_System
- evidence: `05_Marketing_System/roster.md`
- substance: A 6-role content pipeline — Scout, Strategist, Creator, Viability Gatekeeper, Critic+Judge, Producer — where each step carries its own model explicitly and the model IDs rotate ~monthly from one swap point.
- angle: Per-step model routing with a single swap point beats hardcoding one model everywhere; the roster changes monthly, the pipeline doesn't.
- tags: [multi-agent, orchestration, model-routing, pipeline, content, agent-design]
- postable_as: experience
- reuse: 7d

### MKT-02 — cross-family veto is load-bearing
- pillar: marketing
- project: 05_Marketing_System
- evidence: `05_Marketing_System/roster.md` rules
- substance: The Critic/Judge is deliberately kept on a non-Claude model so a Claude-written draft is scored by a different model family. The cross-family veto is treated as load-bearing, not optional.
- angle: A model grading its own family's output is a blind spot; the veto only means something if the judge is a different family.
- tags: [eval, judge, multi-agent, verification, cross-family, content]
- postable_as: opinion
- reuse: 7d

### MKT-03 — the Scout writes data, not prose (tone-firewall)
- pillar: marketing
- project: 05_Marketing_System
- evidence: `05_Marketing_System/schemas/scout_schema.md`
- substance: The Scout emits field-based structured data, never prose — "the structure IS the tone-firewall; a chatty Scout poisons downstream voice."
- angle: Upstream agents should hand structured data downstream, not prose — voice leaks through prose, and a chatty scout poisons everything after it.
- tags: [pipeline, tone, structure, multi-agent, content, agent-design]
- postable_as: experience
- reuse: 7d

### MKT-04 — source-honesty: tag every signal or it's a guess
- pillar: marketing
- project: 05_Marketing_System
- evidence: `05_Marketing_System/schemas/scout_schema.md` (Source honesty)
- substance: Every signal tagged [scraped] / [X-live] / [hypothesis]. Engagement numbers only on measured signals; a failed scrape FLAGGED, never silently skipped; inferred trends never dressed as observed.
- angle: An agent finding without a source tag is a guess wearing a fact's clothes; tag the source or don't act on the number.
- tags: [source-honesty, eval, hallucination, verification, content, agent-design]
- postable_as: opinion
- reuse: 7d

### GRW-01 — LinkedIn_Automation: invisible-by-design HITL pipeline
- pillar: marketing
- project: LinkedIn_Automation
- evidence: `01_Projects/LinkedIn_Automation.md` (Core Mission + Tech Stack)
- substance: A self-developing, human-in-the-loop content pipeline that engages LinkedIn in four phases (Warm-Up, Authority, Anchor, Maintenance), engineered for JA4 fingerprint consistency + behavioral entropy to stay statistically invisible to enterprise bot detection (Akamai/DataDome). Playwright-stealth, Gemini Flash/Pro, Telegram approve/reject HITL.
- angle: Real growth automation isn't a bot spamming — it's a HITL pipeline engineered to look human to the detection layer, with you approving every move.
- tags: [automation, growth, linkedin, stealth, hitl, playwright, anti-detection]
- reply_scope: excluded (anti-detection — not for public reply grounding)
- postable_as: experience
- reuse: 7d

### GRW-02 — fixed fire-times are a detection signature
- pillar: marketing
- project: LinkedIn_Automation
- evidence: `04_Logs/2026-05-07` (Phase_F_Scheduler_Activation, Stealth Tripod)
- substance: Scheduled via launchd; user pushback caught that hardcoded fire times are a metronomic detection signature, so added random_window_jitter (per-mode max delays) with a re-check after sleep. 5 cardinal manual-sync rules codified in SOUL.md + CLAUDE.md.
- angle: Predictable timing is itself a tell; jitter isn't polish, it's part of staying invisible — and the rules belong in the memory file, not your head.
- tags: [scheduling, jitter, stealth, anti-detection, agent-rules, automation]
- reply_scope: excluded (anti-detection — not for public reply grounding)
- postable_as: experience
- reuse: 7d

### GRW-03 — the content pipeline is channel/type-agnostic
- pillar: marketing
- project: content-modules
- evidence: `06_Research/TikTok_Slideshow_Faceless_Module_PRD.md` (§8.10)
- substance: Adding a whole new content type to the marketing pipeline required zero edits to the core — the type slots into a registered-but-empty profile against a common contract. Two routes exist under it: the **faceless** route (built) and the **UGC / AI-character** route (stubbed), proving the pipeline takes more than one production mode. The module manufactures a niche rather than chasing an existing one.
- angle: A content pipeline worth building lets you add a channel/type (faceless, UGC AI-character, whatever) with zero core edits; if adding a format means rewriting the engine, it's not a pipeline.
- tags: [content, pipeline, faceless, ugc, ai-character, ai-avatar, tiktok, ai-influencer, channel-agnostic, agent-design]
- postable_as: experience
- reuse: 7d

### GRW-04 — confessional travels, formula cards die
- pillar: marketing
- project: content-modules
- evidence: `06_Research/TikTok_Slideshow_Faceless_Module_PRD.md` (CRAFT RULE)
- substance: The one real signal from market scrape: experiential/confessional content travels (530 shares on one), formula/teaching cards die (a formula card is a hard gatekeeper KILL in the pipeline). Told-not-shown is the failure mode.
- angle: On short-form, the teaching-card format is dead on arrival; the confession that happens to contain the lesson is what moves.
- tags: [content, short-form, tiktok, craft, hook, ai-influencer, ugc, ai-character]
- postable_as: opinion
- reuse: 7d

### GRW-05 — assets are the unit of reuse, review before spend
- pillar: marketing
- project: content-modules
- evidence: `06_Research/Asset_Prompt_Step_PRD_v1.md`
- substance: Don't generate finished throwaway slide-images; generate atomic reusable assets (jacket, phone, forearm, backgrounds) stored in a per-project library and composed into slides later. Author the generation prompts as text and review them BEFORE any spend — generation is the expensive, slop-prone step.
- angle: For AI image content, the asset is the unit of reuse, not the finished slide; and you review the prompt as text before you ever pay to render it.
- tags: [content, ai-image, assets, reuse, faceless, ugc, ai-character, review-gate, cost, ai-influencer]
- postable_as: experience
- reuse: 7d

### GRW-06 — self-relative success + a pre-committed kill condition
- pillar: marketing
- project: content-modules
- evidence: `06_Research/TikTok_Slideshow_Faceless_Module_PRD.md` (Validation model)
- substance: Success is measured self-relative (does run N beat our own run 1 on swipe-through / saves / shares), never "did we beat existing creators." A kill condition is pre-committed up front: N=10 posts / 4 weeks / re-spec if no upward trend by run 6.
- angle: When you're manufacturing a niche, "beat the competitors" is the wrong metric — beat your own run 1, and pre-commit the kill condition so you don't pour effort into a dead format.
- tags: [content, analytics, metrics, kill-condition, experiment, ai-influencer]
- postable_as: opinion
- reuse: 7d

===============================================================================

## Curation note (when extending this file)

Add entries ONLY from the anchor projects' passports / boards / brain-files / approved PRDs,
and ONLY when they carry a real decision Evgeny actually made. Keep the three pillars balanced
so the Scout can ground dev, agentic, AND marketing threads. Prefer `honest-gap` and `opinion`
entries — a builder thinking out loud is the brand. Keep hardware flexes and the operator's
personal life out (don't add the fact just to flag it). Every entry stays source-tagged. The
Stage-1.6 auto-curate reads the project **boards** and recent `02_Tasks/` for these projects —
not the whole of `04_Logs`.

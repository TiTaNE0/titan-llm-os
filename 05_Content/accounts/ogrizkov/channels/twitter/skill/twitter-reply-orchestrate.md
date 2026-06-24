# Skill: twitter-reply-orchestrate

Orchestrator runbook — the host Claude Code session IS the orchestrator (claude-opus-4-8 host; claude-fable-5 if available). Roster + role contracts: `../agents/roster.md`.

---

## PROBE

At run start, two cheap liveness probes (both must pass before spending any budget):

1. **grok probe** — one `grok -p` call requesting a trivial fenced ` ```json ` block (e.g. `{"probe": "ok"}`). If no parseable fenced block → **ABORT**: "grok fenced-JSON probe failed; output shape changed". De-risks Scout + Wins-logger (PRD §14.1).

2. **agy probe** — one `agy -p '{"probe": "ok"}' --model "Gemini 3.1 Pro (High)" --print-timeout 10m --dangerously-skip-permissions` call requesting the same trivial block. If no parseable fenced block → **ABORT**: "agy fenced-JSON probe failed — Critic unavailable before budget spend". De-risks the Critic before any Scout/Matcher cost is incurred.

---

## STATE MODEL

Orchestrator holds ONLY:
- `batch_id` — string
- Per-target status ∈ `{drafted, passed, failed, skipped, quarantined, held}`
- Per-target `retry_count` (draft cap 2)
- `grok_calls` — global counter, cap `MAX_GROK_CALLS=40`
- Per-vector `vector_fetches` count, cap `MAX_FETCH_PER_VECTOR=3`; vector marked `EXHAUSTED` on cap with no bind
- Per-vector `vector_state` ∈ `{available, exhausted}`
- `shipped_by_pillar` — counts per `{build, apply, results}`; drives 50/30/20 steering
- Per-vector `query_rotation` — which `query_seeds` subset was used each run (rotation state lives here, not in the Scout — Scout is stateless)
- `calibration_probes` — for the current critic batch only: injected probe `id`s + their working-set positions. Orchestrator state ONLY; never written into the batch handed to the Critic and never into `results[]`. Cleared after each strip.

Orchestrator **never ingests** `voice.md` / `reply_register.md` / grounding text / search results (PRD §9.4). It routes file artifacts. That thin state is what keeps its context clean.

---

## CONTROL FLOW

**0. PROBE** — see above; abort on failure.

**0b. VAULT_SCOUT (cached).**
   - Check `runs/_index/search_vectors.json`. Regenerate if: the file is missing; OR `project_authority.md` has changed since `generated_from` hash; OR `generated_at` is ≥7 days old.
   - If none of the above: reuse the cached file; do not re-invoke Vault_Scout.
   - When regeneration is needed: invoke Vault_Scout sub-agent (`claude-sonnet-4-6`); it reads `project_authority.md` only and writes `runs/_index/search_vectors.json`. Orchestrator does not ingest its output — it just routes the file path to the round-robin loop.
   - Every vector in `search_vectors.json` must be phrased through the agentic lens (operator constraint — load-bearing for the supply guarantee).

**1. Batch ID.** `batch_id = <YYYY-MM-DD>_batch`. If that directory exists, append a suffix letter (`a`, `b`, …). `mkdir runs/<batch_id>/`.

**2. ROUND-ROBIN LOOP.**
   - Load vectors from `runs/_index/search_vectors.json`.
   - Pick the next vector using round-robin, biased toward the under-filled pillar via `shipped_by_pillar` (50/30/20 steering). Vectors are NON-EXCLUSIVE — a vector may yield more than one reply across the batch.
   - From the chosen vector's `query_seeds` pool, pick an unused subset for this run (rotation state tracked in `query_rotation`; hand the **concrete query** to Scout — Scout is stateless).
   - Invoke Scout (`grok -p`): single fetch → returns live candidates into `00_candidates.json` and full thread context into `00b_threads.json`. Increment `grok_calls` + `vector_fetches[vector]`.
   - Matcher sub-agent (`claude-opus-4-8`):
     - Shell corpse-drop pre-filter (by age/views) runs BEFORE the expensive Opus bind.
     - Matcher confirms the candidate matches the vector → binds 1:1 to a vault entry → tags `content_pillar` / `project_pillar` / `vector` → writes `01_anchored.json` for this target; LOCK (`anchored_count += 1`).
     - On Matcher fail: Matcher returns WHY; Scout fetches the next candidate on this vector (increment `grok_calls` + `vector_fetches[vector]`; a replacement CONSUMES vector quota — D3).
     - On `vector_fetches[vector] == MAX_FETCH_PER_VECTOR` with no bind: mark vector `EXHAUSTED`.

**3. STOP CONDITIONS** — check after every bind attempt (whichever fires first):
   - `shipped == TARGET` (default 12) — soft target; see note below.
   - All vectors `EXHAUSTED`.
   - `grok_calls == MAX_GROK_CALLS` (40).
   - Failure-rate breaker: failure rate >~40% across the batch OR low-confidence rejects scattering across different criteria each retry (signature of a systemic conflict).

   **12 is a soft target bounded by these stops, never a bare `while shipped<12`.** On early stop: ship what is real and report the shortfall in `batch_report.md`. Never pressure a gate.

**4. PER-TARGET DRAFT/JUDGE LOOP.**

   For each locked target in `01_anchored.json`:

   a. **Drafter sub-agent (`claude-sonnet-4-6`, FRESH per retry):** receives `{thread_gist, bound entry substance + contribution, content_pillar, voice.md, reply_register.md, drafting_contract.md never-list}` for this ONE target → appends draft to `02_drafts.json`.

   b. **GATEKEEPER:** `/opt/homebrew/bin/bash bin/gate.sh <draft>` (single-draft gate).
      - Exit 2 → **ABORT** (config error: need bash≥4; `brew install bash`). Never retry exit 2.
      - Exit 1 → gate FAIL (word-range out of [5,45] OR banned `!`): if draft retries remain, return to Drafter with the flag. If budget exhausted → `status=skipped`.
      - Exit 0 → proceed to Critic. A `GATE WARN: no concrete signal` on stderr is non-blocking; specificity is owned by the Critic's `specificity_present` judgment.
      - Missing specificity no longer causes exit 1 — it emits a stderr WARN and passes.

   c. **CRITIC (Gemini snapshot-read via agy -p) + CALIBRATION PROBE:**
      - **INJECT:** pick 1-2 probes at random from `tests/critic_probes.json`; build payload `{url, content_pillar, grounded_claim, claimed_contribution, DRAFT, snapshot:null}` for each probe (probes have no real thread snapshot — judge from grounded_claim+DRAFT); append interleaved with the real drafts; record their ids + working-set positions in `calibration_probes`. NEVER pass `id`, `why_bad`, or any marker to agy — it must judge them as ordinary drafts.
      - **JUDGE:** For each real draft, build the snapshot payload from its `00b_threads` entry: `{url, content_pillar, grounded_claim, claimed_contribution, DRAFT, snapshot:{opening_post, top_replies, thread_gist, engagement, captured_at}}`. Orchestrator passes the full batch (real + probe) to agy via `run_traced.sh --role critic --model gemini-3.1-pro --provider google -- agy -p "<prompt>" --model "Gemini 3.1 Pro (High)" --print-timeout 10m --dangerously-skip-permissions`. The call BLOCKS until agy responds (up to 10m). agy NEVER opens the URL — it judges from the snapshot. Routes fenced JSON back without ingesting it. (No `grok_calls` increment — this is not a grok call.)
      - **EVALUATE PROBES:** a calibrated critic FIXes every probe. If ANY probe verdict is SHIP → ABORT: `held:true`, loud flag "CALIBRATION FAILED — critic SHIPped a planted probe — batch HELD", write `_calibration` block `{probes_injected, probes_shipped, result:"abort", probe_ids:[...]}` into `03_review.json`, STOP — no 4d, no asset, no Producer (same posture as CRITIC-UNAVAILABLE). If all probes FIX → write `_calibration {result:"pass", probes_shipped:0, probe_ids:[...]}` and continue.
      - **STRIP:** remove probe entries from the judged set before 4d; `results[]`, asset selection, and Producer see ONLY real drafts. Clear `calibration_probes`.
      - On agy/Gemini critic unavailability mid-run (unreachable / no fenced block / print-timeout self-abort after 10m) → HALT: all results `status=held`, `critic=UNAVAILABLE`, loud held-line. NEVER stub-fallback at runtime.

   d. **FIX → ACTION ROUTING (v1.3)** — deterministic on `criteria[]` booleans, not the free-text FIX prose. Two retry budgets, kept SEPARATE so a style fix never consumes the bind budget:
      - **STYLE budget (3 per target):** `voice_fit` / `specificity_present` / `not_generic` / `length_register_sane` / `positioning_alignment` / `voice_texture` are **style-fixable** → kill Drafter instance, spawn FRESH Drafter with `{prompt + prior draft + named criterion}`, retry. These are the cheap "return to the drafter" fixes; they do **not** count against the bind budget and do **not** quarantine a target on their own (a draft that only ever fails advisory criteria keeps going back to the drafter up to the style cap).
      - **BIND budget (the two HARD gates only):** `no_fabrication` and `thread_fit` → **draft-fixable ONCE** (fresh Drafter), then **bind-bad** if the SAME hard gate fails again.
      - **Immediate bind-bad** on `still_alive=false` or `drift=dead` — redrafting a dead thread is pointless.
      - **Verdict gating:** route on the Critic's confidence-gate (HARD gate fail ≥0.65; advisory fail ≥0.80). A low-confidence misgiving is not a FIX — do not loop on it.
      - **draft-fixable / style action:** kill + fresh Drafter with the named criterion.
      - **bind-bad action:** return to Matcher/Scout for a replacement on that vector (replacement CONSUMES `vector_fetches` quota — D3).

   e. **PER-TARGET CIRCUIT BREAKER:** quarantine (`status=quarantined`, record full reject history, keep batch moving) only when EITHER a HARD gate has failed twice (bind budget spent) + 1 replacement failed, OR the STYLE budget (3) is exhausted with an advisory criterion still failing. A target is never quarantined while it is still making progress against the named fix.

   f. Record all verdicts including `criteria[]` in `03_review.json`.

**5. RATE-BASED ESCALATION** (replaces global SYSTEM HALT).
   - Escalate to operator ONLY when failure rate >~40% of targets hit the breaker, OR when rejects are low-confidence and scatter across different criteria each retry. One stuck target = quarantine; half the batch stuck = escalate.

**6. ASSET — top 2 by `engagement.views` among `passed` targets.**
   - Orchestrator selects deterministically (top 2 by views from `01_anchored.json`).
   - Asset sub-agent (`claude-haiku-4-5`) fills aurora-frost template → writes HTML to `05_Content/05_Assets/reply-<YYYYMMDD>-<batch>-t<N>-<format>.html`.
   - Orchestrator runs `bin/render_asset.sh <html> <png> 1200x1500`.
   - Exit 3 → non-fatal: keep HTML, note **"open + screenshot"**, continue.

**7. PRODUCER sub-agent (`claude-haiku-4-5`).**
   - Reads `01_anchored.json` + `02_drafts.json` + `03_review.json`.
   - Writes `runs/<batch>/replies_to_post.md`: all DRAFT, includes skipped targets with `skip_reason`, surfaces QUARANTINED targets with their full reject history as a separate section (distinct from skipped).
   - **STOP — human review. NEVER post.**

**8. LOUD FLAGS** — emit to stdout AND `03_review.json`:
   - `"no cross-family veto this run"` (emitted only by the Phase-1 `claude-stub` — scaffold tests, never production; a stub batch is also forced `held: true`).
   - `"BATCH HELD — DO NOT POST"` whenever `held: true` (critic gate halt or any hard-block).
   - `"CRITIC UNAVAILABLE — batch HELD"` if the Phase-2 agy/Gemini critic could not be invoked mid-run (unreachable / no fenced block / print-timeout fired after 10m).
   - `"CALIBRATION FAILED — critic SHIPped a planted probe — batch HELD"` when any injected probe returned SHIP at 4c; batch forced `held:true`, `_calibration.result="abort"`.
   - Per-vector `EXHAUSTED` line when `vector_fetches[vector] == MAX_FETCH_PER_VECTOR` with no bind.
   - `MAX_GROK_CALLS reached` line when `grok_calls == 40`.
   - Shortfall line when the batch stops before TARGET with reasons (from `batch_report.md`).
   - Every skipped target with its `skip_reason`.
   - Every quarantined target with its reject history.

**9. WINS-LOGGER (post-posting, ~1 day later).**
   - `grok -p from:ogrizkov` engagement over the window → Wins-logger appends real winners to `runs/_analytics/wins.md`.
   - The Orchestrator host (claude-opus-4-8 primary; claude-fable-5 if available) appends ONE distilled rule per winner (opener type, register, pillar, length). Distillation never delegated to a small model.

---

## ERROR PATHS

| Condition | Action |
|-----------|--------|
| `grok` probe returns no fenced block | ABORT: "grok fenced-JSON probe failed; output shape changed" |
| `agy` probe returns no fenced block | ABORT: "agy fenced-JSON probe failed — Critic unavailable before budget spend" |
| agy/Gemini critic exceeds 10m print-timeout | agy self-aborts → CRITIC-UNAVAILABLE → SAVE-AND-HALT |
| `gate.sh` exit 2 at any point | ABORT (config error: need bash≥4 — `/opt/homebrew/bin/bash`; `brew install bash`) |
| `gate.sh` exit 1 (word-range or banned `!`) | Retry within draft cap (2/target); else skip + log reason |
| `render_asset.sh` exit 3 | Non-fatal: keep HTML, note "open + screenshot", continue batch |
| `grok -p` returns no fenced block mid-run | Re-prompt once; if still no block → SAVE-AND-HALT (below) |
| Any role's output unobtainable (credits/auth/CLI dead/sub-agent fails ×2) | SAVE-AND-HALT (below); never substitute, never stub, never improvise a replacement model |
| Critic FIX — draft-fixable criterion | Kill Drafter, spawn fresh Drafter with named criterion; retry within draft cap |
| Critic FIX — bind-bad criterion | Return to Matcher/Scout for replacement on that vector (consumes vector quota) |
| `MAX_FETCH_PER_VECTOR` reached with no bind | Mark vector EXHAUSTED; move to next vector; emit loud EXHAUSTED line |
| `MAX_GROK_CALLS` (40) reached | Stop loop; ship what's real; emit loud cap-reached line; report shortfall in `batch_report.md` |
| Draft cap (2) + 1 replacement exhausted on a target | `status=quarantined`; record reject history; keep batch moving |
| Failure rate >~40% across batch | Rate-based escalation: surface to operator; do not spin |
| Critic SHIPs a planted calibration probe (4c) | ABORT: `held:true`, loud "CALIBRATION FAILED" line, `_calibration.result="abort"`; strip probes; no downstream stages |

## SAVE-AND-HALT (universal failure policy — 2026-06-10b lesson)

When any role cannot produce its output for ANY reason (out of credits, auth failure, dead CLI,
sub-agent failing twice, no fenced block after the one re-prompt):

1. **SAVE** — all artifacts already on disk stay; finish any sub-agent already in flight; start NOTHING new.
2. **RECORD** — write `runs/<batch>/HALT.json`: `{halted_at_stage, reason, completed_stages,
   artifacts_present, next_stage, resume_instruction}`. Mirror `held: true` + the loud line into
   `03_review.json` if it exists yet.
3. **STOP** — no downstream stages, no asset, no producer ceremony, no padding artifacts. The batch dir
   plus `HALT.json` IS the deliverable. Generating polished output downstream of a dead dependency is
   fluff; the operator reads `HALT.json`, not a dressed-up rejection file.
4. **RESUME** — when the blocker clears: re-run the PROBE, read `HALT.json`, continue from `next_stage`
   using the saved artifacts. File-based handoffs make every stage re-entrant; nothing is redone.

The Critic degradation rule (`role_specs/critic.md`) is the special case of this policy; this section
generalizes it to every role.

---

## ISOLATION MATRIX

| Role | Reads | Must never see |
|------|-------|----------------|
| Vault_Scout | `project_authority.md` | `voice.md`, `reply_register.md`, drafts, live X data, `runs/<batch>/` artifacts |
| Scout | 3-pillar domain vocab (concrete query from orchestrator), 24–48h window, `wins.md`, prior `replies_to_post.md` | `voice.md`, `reply_register.md`, `project_authority.md` grounding entries, drafts |
| Scout (thread-fetch) | Orchestrator-provided URL + live X | `voice.md`, `reply_register.md`, `project_authority.md` grounding entries, drafts |
| Matcher | `00_candidates.json`, `00b_threads.json`, `project_authority.md`, `search_vectors.json` | `voice.md`, `reply_register.md`, search internals, other roles' reasoning |
| Drafter | ONE target's `thread_gist` + ONE bound entry substance + `contribution`, `content_pillar`, `voice.md`, `reply_register.md`, never-list | Full `project_authority.md`, other targets, search internals, asset templates, gate internals |
| Critic | Draft, persisted `00b_threads` snapshot `{opening_post, top_replies, thread_gist, engagement, captured_at}`, bound entry claim, `content_pillar`, Rubric v1.3 | Full `voice.md` / `reply_register.md`, other drafts, gate internals, live X / any URL to open |
| Gatekeeper | Draft or batch file (shell; no LLM context) | — |
| Asset | Top 1–2 `{draft + bound entry}` selected by orchestrator, aurora-frost template | Search internals, other targets, gate internals, `voice.md`, `reply_register.md` |
| Producer | `01_anchored.json`, `02_drafts.json`, `03_review.json` | Search internals, `voice.md`, `reply_register.md`, `project_authority.md`, asset templates, gate internals |
| Wins-logger | `wins.md`, posted batch `replies_to_post.md` | Other batches' drafts, asset templates, gate internals |

Orchestrator never ingests voice / register / grounding / search text — routes artifacts only.

---

## CAPS (consolidated)

| Cap | Value |
|-----|-------|
| `MAX_FETCH_PER_VECTOR` (grok calls per vector per run) | 3 → mark EXHAUSTED on cap with no bind |
| `MAX_GROK_CALLS` (global grok budget) | 40 |
| TARGET (shipped replies) | 12 (soft) |
| Bind-budget draft retries per target (HARD gates: no_fabrication, thread_fit) | 2 |
| Style-budget draft retries per target (advisory criteria, separate pool) | 3 |
| Replacement targets per target before quarantine | 1 |
| Asset selection | Top 2 by `engagement.views` among SHIP |
| Failure-rate escalation threshold | ~40% |
| Vault_Scout staleness TTL | 7 days |

# Skill: twitter-reply-orchestrate

Orchestrator runbook — the host Claude Code session IS the orchestrator (`claude-fable-5`; fallback `claude-opus-4-8`). Roster + role contracts: `../agents/roster.md`.

---

## PROBE

At run start, one cheap `grok -p` call requesting a trivial fenced ` ```json ` block (e.g. `{"probe": "ok"}`). If no parseable fenced block is extracted from stdout → **ABORT** with message: "grok fenced-JSON probe failed; output shape changed". De-risks PRD §14.1 before spending any budget.

---

## STATE MODEL

Orchestrator holds ONLY:
- `batch_id` — string
- Per-target status ∈ `{drafted, passed, failed, skipped}`
- Per-target retry count (shared budget)

Orchestrator **never ingests** `voice.md` / `reply_register.md` / grounding text / search results (PRD §9.4). It routes file artifacts. That thin state is what keeps its context clean.

---

## CONTROL FLOW

**0. PROBE** — see above; abort on failure.

**1. Batch ID.** `batch_id = <YYYY-MM-DD>_batch`. If that directory exists, append a suffix letter (`a`, `b`, …). `mkdir runs/<batch_id>/`.

**2. SCOUT — widen loop (cap 3 passes).**
   - Invoke Scout: `grok -p "<brief demanding single fenced json block>"` → parse stdout for fenced ` ```json ` block → write `runs/<batch>/00_candidates.json`.
   - Aim 18–25 candidates per pass: downstream gates (replyability + contributability + live-read critic) cut hard, so the pool must be wide for the batch to ship more than 2–3 replies.
   - Count live English survivors in the JSON.
   - If survivors <8 AND pass count <3: widen topics, re-invoke Scout, repeat.
   - If cap (3) hit: emit loud **"widened 3 times, only M live this window"** to stdout. Proceed with whatever survived.

**3. MATCHER sub-agent (`claude-sonnet-4-6`) — liveness shortlist.**
   - Inputs passed: `00_candidates.json` + `project_authority.md`.
   - Matcher applies the liveness gate → a shortlist of live survivors (binding happens after 3.5).

**3.5. THREAD-FETCH (Scout / grok, batched).**
   - Orchestrator passes the Matcher's liveness-survivor URL list to Scout for ONE batched `grok -p` call.
   - Parse the single fenced ` ```json ` block → write `runs/<batch>/00b_threads.json`.
   - Route to Matcher; the orchestrator NEVER ingests the thread text (same firewall as the search results).
   - Matcher then applies the replyability filter (drop poll/meme/promo without a real discussion) + the
     contributability gate (bind only if an honest thread-perspective `contribution` sentence exists — no
     pivot-binds) + binds each survivor 1:1 against `thread_gist` → writes `01_anchored.json` (carries
     `thread_gist` + `post_type` + `contribution`).
   - If replyable+groundable <8 AND a re-scout pass is unused (at most 1 extra): trigger one more Scout pass, re-run Matcher.
   - Proceed with ≥1 anchored target; abort only if zero.

**4. PER-TARGET LOOP — shared retry budget: 2 retries across gate FAIL + Critic FIX per target.**

   For each target in `01_anchored.json`:

   a. **Drafter sub-agent (`claude-sonnet-4-6`):** receives {`thread_gist`, bound entry substance + `contribution`, `voice.md`, `reply_register.md`, `drafting_contract.md` never-list} for this ONE target → appends draft to `02_drafts.json`. The draft DELIVERS the `contribution` sentence (thread's need = destination, entry = evidence).

   b. **GATEKEEPER:** `/opt/homebrew/bin/bash bin/gate.sh <draft>` (single-draft gate).
      - Exit 2 → **ABORT** (config error: need bash≥4; `brew install bash`). Never retry exit 2.
      - Exit 1 → gate FAIL: if budget left, count retry, return to Drafter with the flag. If budget exhausted → `status=skipped`, record `skip_reason`.
      - Exit 0 → proceed to Critic.

   c. **CRITIC (Phase-2 grok, live-read):** per draft (or batched over survivors), the grok critic OPENS each
      URL and judges against the LIVE thread. Orchestrator passes {`url`, `thread_gist` as cross-ref ONLY,
      `grounded_claim`, `draft`} and routes the fenced JSON back without ingesting it.
      - On critic unavailability mid-run → HALT: all results `status=held`, `critic=UNAVAILABLE`, loud held-line. NEVER stub-fallback at runtime.
      - `FIX:<criterion>`: if budget left, count retry, return to Drafter with the named criterion fed back. If budget exhausted → `status=skipped`.
      - `SHIP` → `status=passed`.

   d. Record all verdicts in `03_review.json`.

**5. BATCH GATE.**
   - Assemble all `passed` drafts as `DRAFT:` lines → `gate.sh --batch`.
   - Exit 2 → **ABORT**.
   - Exit 1 → flagged targets return to Drafter within remaining shared budget; re-gate; re-batch. Any target that cannot clear → `status=skipped`.
   - Exit 0 → proceed.

**6. ASSET — top 2 by `engagement.views` among `passed` targets.**
   - Orchestrator selects deterministically (top 2 by views from `01_anchored.json`).
   - Asset sub-agent (`claude-haiku-4-5`) fills aurora-frost template → writes HTML to `05_Content/05_Assets/reply-<YYYYMMDD>-<batch>-t<N>-<format>.html`.
   - Orchestrator runs `bin/render_asset.sh <html> <png> 1200x1500`.
   - Exit 3 → non-fatal: keep HTML, note **"open + screenshot"**, continue.

**7. PRODUCER sub-agent (`claude-haiku-4-5`).**
   - Reads `01_anchored.json` + `02_drafts.json` + `03_review.json`.
   - Writes `runs/<batch>/replies_to_post.md`: all DRAFT, includes skipped targets with `skip_reason`.
   - **STOP — human review. NEVER post.**

**8. LOUD FLAGS** — emit to stdout AND `03_review.json`:
   - `"no cross-family veto this run"` (emitted only by the Phase-1 `claude-stub` — scaffold tests, never production; a stub batch is also forced `held: true`).
   - `"BATCH HELD — DO NOT POST"` whenever `held: true` (critic gate halt or any hard-block).
   - `"CRITIC UNAVAILABLE — batch HELD"` if the Phase-2 grok critic could not be invoked mid-run.
   - Scout widen-exhaustion line if cap was hit.
   - Every skipped target with its `skip_reason`.

**9. WINS-LOGGER (post-posting, ~1 day later).**
   - `grok -p from:ogrizkov` engagement over the window → Wins-logger appends real winners to `runs/_analytics/wins.md`.
   - Orchestrator (Fable 5 host, same session) appends ONE distilled rule per winner (opener type, register, pillar, length). Distillation never delegated to a small model.

---

## ERROR PATHS

| Condition | Action |
|-----------|--------|
| `grok` probe returns no fenced block | ABORT: "grok fenced-JSON probe failed; output shape changed" |
| `gate.sh` exit 2 at any point | ABORT (config error: need bash≥4 — `/opt/homebrew/bin/bash`; `brew install bash`) |
| `gate.sh` exit 1 (per-draft or batch) | Retry within shared budget (2/target); else skip + log reason |
| `render_asset.sh` exit 3 | Non-fatal: keep HTML, note "open + screenshot", continue batch |
| `grok -p` returns no fenced block mid-run | Re-prompt once; if still no block → SAVE-AND-HALT (below) |
| Any role's output unobtainable (credits/auth/CLI dead/sub-agent fails ×2) | SAVE-AND-HALT (below); never substitute, never stub, never improvise a replacement model |
| Critic FIX | Return to Drafter with named criterion; retry within budget; else skip |

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
| Scout | 3-pillar domain vocab, 24–48h window, `wins.md`, prior `replies_to_post.md` | `voice.md`, `reply_register.md`, `project_authority.md` grounding entries, drafts |
| Scout (thread-fetch) | Matcher's liveness-survivor URL list, live X | `voice.md`, `reply_register.md`, `project_authority.md` grounding entries, drafts |
| Matcher | `00_candidates.json`, `00b_threads.json`, `project_authority.md` | `voice.md`, `reply_register.md`, search internals, other roles' reasoning |
| Drafter | ONE target's `thread_gist` + ONE bound entry substance + `contribution`, `voice.md`, `reply_register.md`, never-list | Full `project_authority.md`, other targets, search internals, asset templates, gate internals |
| Critic | Draft, `thread_gist`, the target URL opened live, bound entry claim, Rubric v1.1 | Full `voice.md` / `reply_register.md`, other drafts, gate internals |
| Gatekeeper | Draft or batch file (shell; no LLM context) | — |
| Asset | Top 1–2 `{draft + bound entry}` selected by orchestrator, aurora-frost template | Search internals, other targets, gate internals, `voice.md`, `reply_register.md` |
| Producer | `01_anchored.json`, `02_drafts.json`, `03_review.json` | Search internals, `voice.md`, `reply_register.md`, `project_authority.md`, asset templates, gate internals |
| Wins-logger | `wins.md`, posted batch `replies_to_post.md` | Other batches' drafts, asset templates, gate internals |

Orchestrator never ingests voice / register / grounding / search text — routes artifacts only.

---

## CAPS (consolidated)

| Cap | Value |
|-----|-------|
| Scout widen passes | 3 |
| Groundable floor | 8 (triggers re-scout if unused pass available) |
| Matcher re-scout | 1 extra pass max |
| Shared retries per target (gate FAIL + Critic FIX combined) | 2 |
| Asset selection | Top 2 by `engagement.views` among SHIP |
| grok thread-fetch calls | ≤2 (one batched call + at most one re-fetch after re-scout) |
| grok critic calls | ≤13 + retries (one per draft, or one batched call, + FIX re-judges within budget) |
| Total grok call ceiling | probe 1 + scout ≤3 + thread-fetch ≤2 + critic ≤13 + retry tail + wins 1 |

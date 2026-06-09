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
   - Count live English survivors in the JSON.
   - If survivors <8 AND pass count <3: widen topics, re-invoke Scout, repeat.
   - If cap (3) hit: emit loud **"widened 3 times, only M live this window"** to stdout. Proceed with whatever survived.

**3. MATCHER sub-agent (`claude-sonnet-4-6`).**
   - Inputs passed: `00_candidates.json` + `project_authority.md` only.
   - Matcher applies liveness gate + 1:1 binding → writes `01_anchored.json`.
   - If groundable <8 AND a re-scout pass is unused (at most 1 extra): trigger one more Scout pass, re-run Matcher.
   - Proceed with ≥1 anchored target; abort only if zero.

**4. PER-TARGET LOOP — shared retry budget: 2 retries across gate FAIL + Critic FIX per target.**

   For each target in `01_anchored.json`:

   a. **Drafter sub-agent (`claude-sonnet-4-6`):** receives {tweet text, bound entry substance/angle, `voice.md`, `reply_register.md`, `drafting_contract.md` never-list} for this ONE target → appends draft to `02_drafts.json`.

   b. **GATEKEEPER:** `/opt/homebrew/bin/bash bin/gate.sh <draft>` (single-draft gate).
      - Exit 2 → **ABORT** (config error: need bash≥4; `brew install bash`). Never retry exit 2.
      - Exit 1 → gate FAIL: if budget left, count retry, return to Drafter with the flag. If budget exhausted → `status=skipped`, record `skip_reason`.
      - Exit 0 → proceed to Critic.

   c. **CRITIC:** Phase 1 = Claude stub (`critic_verdict: "SHIP"`, `critic: "claude-stub"`). Phase 2 = `grok -p` vs Rubric v1.
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
   - `"no cross-family veto this run"` (Phase 1, every run).
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
| `grok -p` returns no fenced block mid-run | Re-prompt once; if still no block, proceed honestly without that stage's output; log it |
| Critic FIX | Return to Drafter with named criterion; retry within budget; else skip |

---

## ISOLATION MATRIX

| Role | Reads | Must never see |
|------|-------|----------------|
| Scout | 3-pillar domain vocab, 24–48h window, `wins.md`, prior `replies_to_post.md` | `voice.md`, `reply_register.md`, `project_authority.md` grounding entries, drafts |
| Matcher | `00_candidates.json`, `project_authority.md` | `voice.md`, `reply_register.md`, search internals, other roles' reasoning |
| Drafter | ONE tweet text + ONE bound entry substance/angle, `voice.md`, `reply_register.md`, never-list | Full `project_authority.md`, other targets, search internals, asset templates, gate internals |
| Critic | Draft, target tweet, bound entry claim, Rubric v1 | Full `voice.md` / `reply_register.md`, other drafts, gate internals |
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

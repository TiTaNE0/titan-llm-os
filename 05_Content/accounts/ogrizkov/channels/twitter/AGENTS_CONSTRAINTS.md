---
type: reference
artifact: agent-constraints
account: ogrizkov
channel: twitter
describes: per-agent constraints for the v3.2 reply pipeline (roster + isolation matrix + role-spec gates + caps)
sources: agents/roster.md, agents/role_specs/*, agents/schemas.md, agents/params.json, agents/critic_ladder.json, skill/twitter-reply-orchestrate.md
written: 2026-11-23
status: current
---

# Agent Constraints — @ogrizkov reply pipeline (v3.2)

One line per agent's hard edges: model · what it reads · what it must never see · the rules it enforces · the caps that bound it. Authoritative sources are the roster, the role specs, the scripts in `bin/`, and the runbook ISOLATION MATRIX / CAPS — this page consolidates them. Numbers are not repeated here: every number a script reads lives in `agents/params.json`; the critic model order lives in `agents/critic_ladder.json` and the model of a run in `runs/_index/critic_model.json`.

---

## 0 · Orchestrator
- **Model:** claude-opus-4-8 host (claude-fable-5 if available)
- **Reads:** file artifacts only (routes paths), the budget JSON of the run
- **Never sees:** voice.md, reply_register.md, grounding text, search results — never ingests content
- **Enforces:** thin state; two waves (recommended items never wait on review items); routing (forced_anchor / op_relevance / interest → drop, no redraft); SAVE-AND-HALT interactive, resume unattended (runbook `## UNATTENDED MODE` is the single owner)
- **Caps:** `cost.*` and `volume.deliver_per_run` in params.json; the delivery number is a ceiling, never a quota

## 0b · Vault_Scout
- **Model:** claude-sonnet-4-6 (Opus on a major vault change)
- **Reads:** `project_authority.md`, `runs/_index/authority_zones.json`
- **Never sees:** voice/register, drafts, live X, run artifacts
- **Enforces:** project vectors from `answers[]` / `contests[]` only; topic vectors, at least one per authority zone (these find the Clean items)
- **Caps:** cached; regenerate on vault or zone change or 7-day TTL

## 1 · Scout (discovery only)
- **Model:** grok (`grok -p`) — the only model with live X search; used only for the discovery search
- **Reads:** concrete queries: call A the watchlist authors and the large-account list, call B the vector queries; the exclude list
- **Never sees:** voice/register, `project_authority` grounding entries, drafts
- **Enforces:** live retrieval only; English; `author_followers`, `posted_at`, `views`, `matched_quote`, honest `post_type`
- **Caps:** `cost.max_grok_calls` per run (two discovery calls plus one reserve for the widen pass, a needed probe or a fallback read)

## 1b · Post reader (`bin/fetch_posts.py`)
- **Model:** none — the public conversation endpoint (`endpoint.base`)
- **Enforces:** thread snapshots for the Critic, his reply count, the 24 h / 48 h readings, author answers, the pattern refresh sample; a clear failure reason (`endpoint_http`, `endpoint_timeout`, `endpoint_shape`, `not_found`) so the caller falls back to grok or logs
- **Caps:** `endpoint.timeout_s`, `endpoint.parallel`

## 2 · Matcher
- **Model:** claude-opus-4-8
- **Reads:** ranked survivors, `00b_threads.json`, `project_authority.md`, the zone list, the budget fields, one public source per target
- **Never sees:** voice/register, search internals, other roles' reasoning
- **Enforces (gates):** claim-first fit test (author_claim, open_point, move, subtraction test; only fit 3 binds Deep); Deep only when a project fact is what the thread lacks and the entry is not resting and something happened in it (else a finding request); Clean is the default, no project fact, no implied experience, inside the authority zones; replyability (discussion only); mechanism transfer; forced-bind tell; stealth-scope exclusion; large-account lane = a correction or a number only
- **Caps:** `caps.bind_max` binds per run

## 3 · Drafter
- **Model:** claude-sonnet-4-6 (FRESH instance per retry)
- **Reads:** ONE target's snapshot + anchored fields, `reply_patterns.md`, `voice.md`, `reply_register.md`, never-list, `hooks_recent`
- **Never sees:** full `project_authority`, other targets, search internals, asset templates, gate internals
- **Enforces:** interest first (`answers`, `point`); a starter of 40 words at most (25 in the lane), no link, no hashtag; Deep: he is the doer; Clean: no first-person experience; a hook from the sheet (never X1-X7, never in `hooks_recent`, once per run) with a plain instruction line; optional "Yours?" question; no planted typos; never invent; no reply says how it was written
- **Caps:** one redraft for a hard criterion; STYLE budget for the advisory ones

## 4 · Critic
- **Model:** non-Claude, non-GPT: the first answering rung of `agents/critic_ladder.json` (cross-family veto); model of the run in `runs/_index/critic_model.json`
- **Invocation:** `agy -p "<prompt>" --model "<cli_name>" --print-timeout 10m`, one batched call per wave with 2 calibration probes
- **Reads:** drafts of its wave, the persisted snapshots, `author_claim`, `move`, `reply_type`, `grounded_claim` (Deep), `source_quote`, Rubric v1.4
- **Never sees:** full voice/register, gate internals, the Matcher's reasoning, **live X / any URL to open**
- **Enforces:** Rubric v1.4 — HARD `no_fabrication`, `thread_fit`, `op_relevance`, `forced_anchor`, `stranger_interest`, `ai_tells` (incl. tells (i) how it was written and (j) a verdict opening); advisory `no_hype`, `length_register_sane`; `learns` for rule 11. Never reject for a missing project fact. Never pass because of a project noun.
- **Caps:** `probes_per_call` per call; weekly qualification on the full set (`bin/qualify_critic.sh`), a failed rung rests `critic_qualified_days`; NOT a grok call

## 4b · Interest reviewer (rule 11)
- **Model:** claude-opus-4-8, fresh context per draft, in parallel with the Critic
- **Reads:** the opening post, the top replies and the draft only
- **Enforces:** "what does a builder learn that the thread did not give"; "nothing" or an empty answer rejects (either verdict rejects)

## 5 · Gatekeeper
- **Model:** none — `bin/gate.sh` v2.5 (bash ≥4) and `bin/target_filter.py`
- **Enforces:** single: word count, no `!`, no link or hashtag, no internal label, not agreement only, Clean without implied experience, no 4-word anchor paste, no 5-word reuse of the last 14 days (specificity stays a WARN); batch: duplicate opener, structural template, em-dash rate, skeleton shape, keyword share, pairwise overlap, same word count, the tic cap (no question cap); `target_filter.py`: rule 10 limits and ranking (answers and momentum), hook check, zone, verbatim quote, logged source, resting entry, lane move
- **Caps:** word and n-gram limits are constants in `gate.sh`; exit 2 → ABORT (config error)

## 6 · Asset
- **Model:** claude-haiku-4-5 — interactive runs only
- **Enforces:** optional / non-fatal (render fail → keep HTML, "open + screenshot"); text unchanged

## 7 · Producer
- **Model:** none — `bin/produce.py`
- **Enforces:** `replies_to_post.md` v3.2; byte-for-byte copy; recommended/review marks (one per author a day, Deep and large-account limits per day, the lane's place); delivery order and caps (deliver cap, lane cap, one hook per mail); never posts

## 8 · Wins-logger
- **Model:** none for reads (`fetch_posts.py` + `measure.py`); grok only as the fallback; the host distils one rule per winner
- **Enforces:** per-reply log at 24 h and 48 h, marks, tripwire, pattern refresh proposal every 14 days; never an email; the pattern sheet is never changed by a run

---

## Global stops (Orchestrator)
`deliver_cap` passed · candidates exhausted · `max_grok_calls` · the send cut-off · `slot_deadline_min` · failure-rate >~40%. On early stop: deliver what passed — never pressure a gate. Zero passed: a slot-log line, no email.

## Cross-cutting invariants
- **Tone-firewall** — the Orchestrator routes file artifacts only; no role's raw context bleeds into the next.
- **Cross-family veto** — the Drafter is Claude, the Critic is not; a draft is never graded only by its own model family.
- **Verified delivery** — a mail counts only when it is in Mail's Sent mailbox (incident I-9); every non-delivery is counted and can alarm in the daily log, never by email.
- **SAVE-AND-HALT** — when any role cannot produce its output, save artifacts, write `HALT.json`, stop (unattended: resume); never stub or substitute a model.

## Caps (consolidated)
All values: `agents/params.json` (see the runbook `## CAPS (consolidated)` for the key of each cap). Critic order: `agents/critic_ladder.json`.

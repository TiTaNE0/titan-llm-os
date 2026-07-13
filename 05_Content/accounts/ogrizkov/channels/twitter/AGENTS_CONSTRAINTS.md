---
type: reference
artifact: agent-constraints
account: ogrizkov
channel: twitter
describes: per-agent constraints for the v3.1 reply pipeline (roster + isolation matrix + role-spec gates + caps)
sources: agents/roster.md, agents/role_specs/*, agents/schemas.md, skill/twitter-reply-orchestrate.md
written: 2026-06-25
status: current
---

# Agent Constraints — @ogrizkov reply pipeline (v3.1)

One line per agent's hard edges: model · what it reads · what it must never see · the rules it enforces · the caps that bound it. Authoritative source files are the roster, the role specs, and the orchestrator ISOLATION MATRIX / CAPS — this page consolidates them. Reflects the v3.1 calibration (matcher transfer drop, drafter lens, gate WARN, critic topic-adjacent flex) and the Gemini-snapshot critic swap.

---

## 0 · Orchestrator
- **Model:** claude-opus-4-8 host (claude-fable-5 if available)
- **Reads:** file artifacts only (routes paths)
- **Never sees:** voice.md, reply_register.md, grounding text, search results — never ingests content
- **Enforces:** thin state only (batch_id, per-target status/retry, counters); 50/30/20 steering; retry/quarantine routing; SAVE-AND-HALT on any dead dependency
- **Caps:** MAX_GROK_CALLS=40 · TARGET=12 (soft)

## 0b · Vault_Scout
- **Model:** claude-sonnet-4-6 (Opus on a major vault change)
- **Reads:** `project_authority.md` only
- **Never sees:** voice/register, drafts, live X, run artifacts
- **Enforces:** every search vector phrased through the agentic lens; output is `runs/_index/search_vectors.json`
- **Caps:** cached; regenerate only on vault change or 7-day TTL

## 1 · Scout
- **Model:** grok (`grok -p`) — only model with live X access
- **Reads:** concrete query from orchestrator, 24–72h window, `wins.md`, prior `replies_to_post.md` (dedup)
- **Never sees:** voice/register, `project_authority` grounding entries, drafts
- **Enforces:** live retrieval only (no drafting/opinions); English; recency filter; exclude already-engaged URLs; honest `post_type` tagging; **captures the snapshot** (`engagement{views,likes,replies,quotes,reposts,bookmarks}` + `captured_at`) for the Critic
- **Caps:** MAX_FETCH_PER_VECTOR=3 → vector EXHAUSTED; counts against MAX_GROK_CALLS=40

## 2 · Matcher
- **Model:** claude-opus-4-8
- **Reads:** `00_candidates.json`, `00b_threads.json`, `project_authority.md`, `search_vectors.json`
- **Never sees:** voice/register, search internals, other roles' reasoning
- **Enforces (gates):**
  - Liveness / corpse-drop (age / views / velocity)
  - Replyability — discussion/question only; hard-drop promo / announcement / showcase / meme / poll
  - Contributability — write the thread-perspective `contribution`; pivot-toward-our-project → DROP
  - **Domain/mechanism transfer (v3.1)** — bind only if the entry's mechanism maps onto the OP's specific point; same-theme / different-mechanism → DROP
  - **Forced-bind tell (v3.1)** — if it needs a proper-noun/number the thread isn't about → DROP
  - **1:1 binding — one DISTINCT entry per survivor, no reuse within a batch** (the hard ceiling on batch size N)
  - Stealth-scope exclusion — never bind GRW-01 / GRW-02 or stealth / anti-detection / bot-evasion entries
  - Results-bucket rule — bind a results target only if the entry carries a real build/process number

## 3 · Drafter
- **Model:** claude-sonnet-4-6 (FRESH instance per retry)
- **Reads:** ONE target's `thread_gist` + bound entry substance + `contribution` + `content_pillar`, `voice.md`, `reply_register.md`, never-list
- **Never sees:** full `project_authority`, other targets, search internals, asset templates, gate internals
- **Enforces:**
  - **Grounding as lens (v3.1)** — reason FROM the entry as stance, not a noun-bank to surface
  - **Option-B KEEP/DROP (v3.1)** — a concrete detail appears only when the thread is specifically about it
  - **Never inject a token to clear a gate**; use `[VERIFY]` when a specific would help but isn't in the entry
  - Voice: Evgeny-B, skew-short, varied opener, register texture (ESL tics), no hype/bait, never invent personal facts
- **Caps:** STYLE budget 3 retries · BIND budget 2 (HARD gates)
- **Known gap (proposed v3.2):** no rule yet against reader-illegible *internal* jargon (e.g. `E1-E5`, "loader directive", persona names) — the inverse-noun problem

## 4 · Critic
- **Model:** Gemini 3.1 Pro (High) via `agy -p` — non-Claude (cross-family veto)
- **Invocation:** `agy -p "<prompt>" --model "Gemini 3.1 Pro (High)" --print-timeout 10m --dangerously-skip-permissions`
- **Reads:** the draft, the persisted `00b_threads` snapshot `{opening_post, top_replies, thread_gist, engagement, captured_at}`, bound entry claim, `content_pillar`, Rubric v1.3
- **Never sees:** full voice/register, other drafts, gate internals, **live X / any URL to open** (snapshot-read only)
- **Enforces:**
  - HARD gates (block SHIP at conf ≥0.65): `no_fabrication`, `thread_fit` (incl. **topic-adjacent-flex FAIL**, v3.1)
  - Advisory (block only if egregious, conf ≥0.80): voice_fit, `specificity_present`, not_generic, length_register_sane, positioning_alignment, voice_texture
  - Per-criterion verdict; never rewrites; verdict `SHIP` | `FIX:<criterion>`; output one fenced JSON block; `"critic":"gemini"`
- **Caps:** `--print-timeout 10m` (waits for the slow response, no external kill); exceed 10m → CRITIC-UNAVAILABLE → SAVE-AND-HALT; NOT counted against the grok budget
- **Known gap (proposed v3.2):** `specificity_present` rewards a present token even when it's reader-illegible internal jargon — should require reader-legibility

## 5 · Gatekeeper
- **Model:** none — `bin/gate.sh` (deterministic shell; needs bash ≥4)
- **Reads:** the draft (or batch file); no LLM context
- **Enforces:**
  - Single-draft HARD: 5–45 words; no `!`
  - **Specificity = non-fatal WARN (v3.1)** — no longer blocks; owned by the Critic's `specificity_present`
  - `--batch` HARD: keyword-repetition, length-variety, skeleton-shape, em-dash-splice
- **Caps:** exit 2 (bash <4) → ABORT (config error)

## 6 · Asset
- **Model:** claude-haiku-4-5
- **Reads:** top 1–2 `{draft + bound entry}` (selected by orchestrator), aurora-frost template
- **Never sees:** search internals, other targets, gate internals, voice/register
- **Enforces:** optional / non-fatal (render fail → keep HTML, "open + screenshot")
- **Caps:** top 2 by `engagement.views` among SHIP

## 7 · Producer
- **Model:** claude-haiku-4-5
- **Reads:** `01_anchored.json`, `02_drafts.json`, `03_review.json`
- **Never sees:** search internals, voice/register, `project_authority`, asset templates, gate internals
- **Enforces:** writes `replies_to_post.md` (all DRAFT; SHIP + skipped + quarantined sections); **STOP at human review — never posts**

## 8 · Wins-logger
- **Model:** grok (`grok -p from:ogrizkov`) + orchestrator for distillation
- **Reads:** `wins.md`, the posted batch `replies_to_post.md`
- **Never sees:** other batches' drafts, asset templates, gate internals
- **Enforces:** runs ~1 day post-posting; appends real winners; distillation (one rule per winner) never delegated to a small model

---

## Global stops (Orchestrator)
`shipped == TARGET` · all vectors EXHAUSTED · `grok_calls == MAX_GROK_CALLS (40)` · failure-rate >~40%. On early stop: ship what's real, report the shortfall — never pressure a gate.

## Cross-cutting invariants
- **Tone-firewall** — the Orchestrator routes file artifacts only; no role's raw context bleeds into the next.
- **Cross-family veto** — the Drafter is Claude, the Critic is Gemini; a draft is never graded by its own model family. Independence = non-Claude family + judging the persisted snapshot.
- **SAVE-AND-HALT** — when any role cannot produce its output, save artifacts, write `HALT.json`, stop; never stub or substitute a model.

## Caps (consolidated)
| Cap | Value |
|-----|-------|
| MAX_FETCH_PER_VECTOR (grok calls per vector per run) | 3 → EXHAUSTED on cap with no bind |
| MAX_GROK_CALLS (global grok budget) | 40 |
| TARGET (shipped replies) | 12 (soft) |
| Bind-budget draft retries (HARD gates) | 2 |
| Style-budget draft retries (advisory) | 3 |
| Replacement targets per target before quarantine | 1 |
| Asset selection | top 2 by `engagement.views` among SHIP |
| Failure-rate escalation | ~40% |
| Vault_Scout staleness TTL | 7 days |
| Critic wait ceiling (`agy --print-timeout`) | 10m (waits; not a kill) |

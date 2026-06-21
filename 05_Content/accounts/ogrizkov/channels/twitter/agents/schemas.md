---
type: pipeline-artifact
artifact: reply-schemas
prd_ref: "§4, §6, §v3.1"
locked: 2026-06-16
---

# v3 Artifact Field Reference

Each stage writes one structured file to `runs/<batch>/`. Every hop is file-only — no role reads
another role's reasoning, only its artifact. Batch id format: `<YYYY-MM-DD>_batch`, with suffix
letters for same-day reruns (e.g. `2026-06-09b_batch`).

`runs/_index/` is a SHARED non-batch directory holding `search_vectors.json` — written once by
Vault_Scout, reused across all runs until TTL or vault change.

---

## search_vectors.json

Writer: Vault_Scout (`claude-sonnet-4-6`). Reader: Orchestrator.

Lives in `runs/_index/` — shared, non-batch; persists across runs. Re-generated when
`project_authority.md` changes OR after 7-day TTL (driven by `generated_at`).

Fields:
- `generated_from` — `"project_authority.md@<hash>"` (hash of the source file at generation time)
- `generated_at` — ISO 8601 timestamp; drives the 7-day TTL
- `vectors[]` — array of vector objects:
  - `id` — unique vector id (e.g. `"V-agentic-orchestration"`)
  - `content_pillar` — one of `"build"` | `"apply"` | `"results"`
  - `search_intent` — one sentence describing the live-thread angle to find on X
  - `grounds_with` — array of `project_authority.md` entry ids that can honestly ground a reply
  - `query_seeds` — pool of search query synonyms/phrasings; Orchestrator rotates/samples per run

```json
{
  "generated_from": "project_authority.md@a3f9c12",
  "generated_at": "2026-06-16T10:00:00Z",
  "vectors": [
    {
      "id": "V-agentic-orchestration",
      "content_pillar": "build",
      "search_intent": "threads where people argue about agent-agnostic orchestration / model-as-runner / owning the routing graph",
      "grounds_with": ["CAK-01", "TIT-01"],
      "query_seeds": ["agent orchestration", "model agnostic", "routing graph", "claude code vs opencode"]
    }
  ]
}
```

---

## 00_candidates.json

Writer: Scout (Grok via `grok -p`). Reader: Matcher.

Fields per candidate:
- `url` — full X thread URL
- `author` — @handle (no leading @)
- `age` — human-readable age at scout time (e.g. "3h", "14h")
- `views` — integer or null if unavailable
- `likes` — integer or null
- `replies` — integer or null
- `lang` — ISO 639-1 language code (must be "en" to survive Matcher's liveness gate)
- `source_tag` — `"hot"` (broad trending AI thread) or `"domain"` (pillar keyword match)
- `text_snippet` — first ~280 chars of the thread's opening post (raw, no paraphrase)
- `post_type` — enum `discussion|announcement|poll|meme|promo|question|showcase`: the kind of post,
  judged at retrieval; drives the Matcher replyability filter

```json
{
  "batch": "2026-06-09_batch",
  "candidates": [
    {
      "url": "https://x.com/swyx/status/1234567890",
      "author": "swyx",
      "age": "6h",
      "views": 42000,
      "likes": 310,
      "replies": 47,
      "lang": "en",
      "source_tag": "hot",
      "text_snippet": "The shift from 'LLM as autocomplete' to 'LLM as orchestrator' is finally clicking in prod systems. Here's what changed for us...",
      "post_type": "discussion"
    }
  ]
}
```

---

## 00b_threads.json

Writer: Scout (Grok via `grok -p`, batched). Reader: Matcher.

Fetched for liveness survivors only, one batched grok call; orchestrator routes without reading.

Fields per entry:
- `url` — same as candidates (the survivor URL the thread was fetched for)
- `opening_post` — full text of the opening post (not the 280-char snippet)
- `top_replies` — array of `{author, text}`, highest-signal replies (incl. any reveal/punchline/answer)
- `thread_gist` — one sentence: what the thread is actually about, incl. what the replies add
- `replyable` — boolean Scout hint (false for polls/memes/promos with no substantive discussion)

```json
{
  "batch": "2026-06-09_batch",
  "threads": [
    {
      "url": "https://x.com/swyx/status/1234567890",
      "opening_post": "The shift from 'LLM as autocomplete' to 'LLM as orchestrator' is finally clicking in prod systems. Here's what changed for us: we stopped trusting one call and started chaining graded sub-agents.",
      "top_replies": [
        {"author": "hingeloss", "text": "the grading step is the whole game — without a veto you just compound the first model's bias"},
        {"author": "swyx", "text": "right, and the veto has to be cross-family or it's theatre"}
      ],
      "thread_gist": "swyx argues orchestration beats autocomplete; the replies sharpen it to the cross-family veto being the load-bearing part.",
      "replyable": true
    }
  ]
}
```

---

## 01_anchored.json

Writer: Matcher (Opus 4.8). Readers: Drafter (per-target), orchestrator (top-2 select), Producer.

Matcher applies the hard Liveness gate (corpse-drop, velocity, fresh-by-reach, English) then
binds each survivor 1:1 to a distinct `project_authority.md` entry. No entry is reused across
targets in the same batch.

Fields per target:
- `url` — same as candidates
- `author` — same as candidates
- `engagement` — object: `{views, likes, replies, velocity}` (velocity: subjective tier "low|mid|high")
- `content_pillar` — `"build"` | `"apply"` | `"results"` (pillar of THIS bind)
- `project_pillar` — `"development"` | `"agentic"` | `"marketing"` (source pillar in project_authority.md)
- `vector` — the source vector id from `search_vectors.json` that led the Scout to this candidate
- `touches` — short string array of candidate topics the entry touches (e.g. `["scheduling", "reliability"]`)
- `ground_with` — the exact `project_authority.md` entry id bound to this target
- `why_live` — one-sentence liveness rationale (age + velocity)
- `entry_substance` — the bound entry's core claim/fact (copied verbatim from authority)
- `contribution` — one sentence, THREAD-perspective: what this reply genuinely adds to THIS thread (answers the ask / extends the point / corroborates with specific experience), supportable by `entry_substance`. If the Matcher cannot write it honestly without redirecting the thread, the target is dropped (contributability gate, no drafting)
- `thread_gist` — copied from `00b_threads.json`. Drafter and Critic read this, not the snippet.
- `post_type` — copied from `00_candidates.json` (audit trail of what the Matcher's replyability filter saw)

```json
{
  "batch": "2026-06-09_batch",
  "targets": [
    {
      "url": "https://x.com/swyx/status/1234567890",
      "author": "swyx",
      "engagement": {
        "views": 42000,
        "likes": 310,
        "replies": 47,
        "velocity": "high"
      },
      "content_pillar": "build",
      "project_pillar": "agentic",
      "vector": "V-agentic-orchestration",
      "touches": ["scheduling", "reliability", "orchestration"],
      "ground_with": "P5-launchd-agent",
      "why_live": "6h old, 310 likes in first 6h — high velocity, safe window.",
      "entry_substance": "launchd-scheduled Claude sub-agent running nightly, zero human trigger; 47 consecutive nights stable",
      "contribution": "corroborates the orchestration-beats-autocomplete claim with a concrete stability datapoint from running it nightly",
      "thread_gist": "swyx argues orchestration beats autocomplete; the replies sharpen it to the cross-family veto being the load-bearing part.",
      "post_type": "discussion"
    }
  ]
}
```

---

## 02_drafts.json

Writer: Drafter (Sonnet 4.6). Readers: Gatekeeper (`gate.sh`), Critic, Producer.

Drafter sees ONE target at a time — the bound `entry_substance` + `contribution` + `content_pillar` + `voice.md` +
`reply_register.md`. Not the full `project_authority.md`. Not other targets.

Fields per draft:
- `url` — target thread URL
- `ground_with` — the `project_authority.md` entry id used (must match `01_anchored.json`)
- `draft` — the reply text (subject to gate: 5–45 words, no `!`, concrete signal)
- `verify_flags` — array of `[VERIFY]` strings for any claim the Drafter flagged as needing
  human confirmation before posting; empty array if all claims are from the bound entry

```json
{
  "batch": "2026-06-09_batch",
  "drafts": [
    {
      "url": "https://x.com/swyx/status/1234567890",
      "ground_with": "P5-launchd-agent",
      "draft": "47 nights straight on launchd — no babysitting. The flip from 'LLM as autocomplete' to scheduled orchestrator is where the stability actually lives.",
      "verify_flags": []
    }
  ]
}
```

---

## 03_review.json

Writer: orchestrator (assembles Gatekeeper + Critic verdicts). This file is the audit trail for
the human review gate.

Fields per result:
- `url` — target thread URL
- `gate_single` — `"pass"` or `"fail"` (gate.sh single-draft verdict)
- `gate_batch` — `"pass"` or `"fail"` (gate.sh --batch verdict over the surviving set)
- `critic_verdict` — `"SHIP"` or `"FIX:<one-line reason naming the failed criterion>"` (cross-family Critic).
  The named criterion is one of the SEVEN: `voice_fit|specificity_present|no_fabrication|not_generic|length_register_sane|thread_fit|positioning_alignment`.
- `criteria` — array of per-criterion objects `{criterion, verdict: "pass"|"fail", confidence: <0-1 float>, reason: "<one line>"}`, one per criterion
- `status` — `"drafted"` | `"passed"` | `"failed"` | `"skipped"` | `"held"` | `"quarantined"`
- `retries` — integer, 0-indexed; how many Drafter retries this target consumed
- `skip_reason` — string if status is `"skipped"`, null otherwise

Batch-level fields:
- `held` — boolean. True if the batch halted at the critic gate or any hard-block; a held batch must not be posted.
- `cross_family_veto` — boolean. MUST be false whenever `critic` is `claude-stub` (the stub is not a cross-family veto).
- `critic` — `"grok"` | `"claude-stub"` | `"UNAVAILABLE"`.
- `_calibration` — object recording the critic calibration-probe result (see `../tests/critic_probes.json`). Orchestrator injects 1-2 known-bad probes at step 4c, judges with real drafts, strips before FIX-routing/Producer. Calibrated critic FIXes every probe; SHIP on any → `held:true` + abort. Fields: `probes_injected` (int), `probes_shipped` (int, non-zero ⇒ soft), `result` (`"pass"` | `"abort"`), `probe_ids` (array, traceable to fixture). Probe entries are NEVER in `results[]`; `_calibration` is the only on-disk trace.

```json
{"_calibration":{"probes_injected":2,"probes_shipped":0,"result":"pass","probe_ids":["probe-pivot-01","probe-fabnum-01"]}}
```

Criterion note — `no_fabrication` (absorbs the old `claim_sanity`): the draft's concrete claim must trace
to `grounded_claim`; fails if it distorts that claim or claims the author's numbers/experience as the replier's.

```json
{
  "batch": "2026-06-09_batch",
  "critic": "grok",
  "cross_family_veto": true,
  "held": false,
  "results": [
    {
      "url": "https://x.com/swyx/status/1234567890",
      "gate_single": "pass",
      "gate_batch": "pass",
      "critic_verdict": "SHIP",
      "criteria": [
        {"criterion": "voice_fit", "verdict": "pass", "confidence": 0.92, "reason": "flat opener, no hype"},
        {"criterion": "specificity_present", "verdict": "pass", "confidence": 0.88, "reason": "47 nights named"},
        {"criterion": "no_fabrication", "verdict": "pass", "confidence": 0.95, "reason": "claim traces to bound entry"},
        {"criterion": "not_generic", "verdict": "pass", "confidence": 0.85, "reason": "launchd stability is specific to the builder"},
        {"criterion": "length_register_sane", "verdict": "pass", "confidence": 0.9, "reason": "two short sentences"},
        {"criterion": "thread_fit", "verdict": "pass", "confidence": 0.87, "reason": "directly corroborates swyx's orchestration point"},
        {"criterion": "positioning_alignment", "verdict": "pass", "confidence": 0.83, "reason": "reads as active builder, build-pillar, no vanity metrics"}
      ],
      "status": "passed",
      "retries": 0,
      "skip_reason": null
    },
    {
      "url": "https://x.com/someone/status/9999",
      "gate_single": "fail",
      "gate_batch": "pass",
      "critic_verdict": "FIX:specificity_present",
      "criteria": [
        {"criterion": "voice_fit", "verdict": "pass", "confidence": 0.8, "reason": "flat opener"},
        {"criterion": "specificity_present", "verdict": "fail", "confidence": 0.75, "reason": "mentions memory but no number or tool"},
        {"criterion": "no_fabrication", "verdict": "pass", "confidence": 0.9, "reason": "no untraced claims"},
        {"criterion": "not_generic", "verdict": "pass", "confidence": 0.7, "reason": "project angle present"},
        {"criterion": "length_register_sane", "verdict": "pass", "confidence": 0.85, "reason": "within length norm"},
        {"criterion": "thread_fit", "verdict": "pass", "confidence": 0.8, "reason": "addresses thread ask"},
        {"criterion": "positioning_alignment", "verdict": "fail", "confidence": 0.6, "reason": "reads spectator not builder"}
      ],
      "status": "skipped",
      "retries": 2,
      "skip_reason": "still failing gate after 2 retries"
    }
  ]
}
```

---

## replies_to_post.md

Writer: Producer (Haiku). Format: Markdown. The human review gate — operator posts manually, never
auto-posted.

Contains per target (passed only):
- Target link
- `ground_with` entry id
- `content_pillar` and `project_pillar`
- DRAFT reply text (marked DRAFT)
- `[VERIFY]` flags if any
- Asset html + png paths, or "open + screenshot" note if Asset role ran
- Skipped targets listed at bottom with skip reasons
- Quarantined targets listed (separately from skipped) with reject history — surfaced, never silently dropped

All content marked **DRAFT**. Producer never posts.

---

## Derived jq views

`runs/<batch>/targets/tN.json` and `runs/<batch>/drafts/tN.json` are per-target **projections** of
`01_anchored.json` and `02_drafts.json` — jq views split out for per-target sub-agent invocation, NOT a
parallel source of truth. The single-file schemas above stay authoritative; the per-target files inherit
whatever those carry (incl. `thread_gist` and `post_type`). Regenerate them from the source files; never
hand-edit a `tN.json` and expect it to propagate back.

---

## Supersession note

v3 supersedes the 3-file `runs/_schema/` chain (`01_candidates` / `02_anchored` / `03_tactical_brief`);
see `runs/_schema/README.md`. Mapping:

| v2 file | v3 file | Change |
|---|---|---|
| `01_candidates` | `00_candidates.json` | Scout writes directly; removed human-fill `anchor` field |
| `02_anchored` (human-filled anchor) | `01_anchored.json` | Matcher-bound `ground_with` + `entry_substance`; fully automated |
| `03_tactical_brief` | folded into `02_drafts.json` | brief fields moved into Drafter's isolated input context |
| (new) | `03_review.json` | orchestrator audit trail (gate + critic verdicts per target) |
| (new) | `replies_to_post.md` | Producer's assembly; equivalent to v2 final output but richer |
| (new v3.1) | `runs/_index/search_vectors.json` | Vault_Scout output; shared non-batch; drives supply-driven top-of-funnel |

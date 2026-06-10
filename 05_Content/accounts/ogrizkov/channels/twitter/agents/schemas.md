---
type: pipeline-artifact
artifact: reply-schemas
prd_ref: "§4, §6"
locked: 2026-06-10
---

# v3 Artifact Field Reference

Each stage writes one structured file to `runs/<batch>/`. Every hop is file-only — no role reads
another role's reasoning, only its artifact. Batch id format: `<YYYY-MM-DD>_batch`, with suffix
letters for same-day reruns (e.g. `2026-06-09b_batch`).

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

Writer: Matcher (Sonnet 4.6). Readers: Drafter (per-target), orchestrator (top-2 select), Producer.

Matcher applies the hard Liveness gate (corpse-drop, velocity, fresh-by-reach, English) then
binds each survivor 1:1 to a distinct `project_authority.md` entry. No entry is reused across
targets in the same batch.

Fields per target:
- `url` — same as candidates
- `author` — same as candidates
- `engagement` — object: `{views, likes, replies, velocity}` (velocity: subjective tier "low|mid|high")
- `pillar` — which project pillar this maps to (from `project_authority.md`)
- `touches` — short string array of candidate topics the entry touches (e.g. `["scheduling", "reliability"]`)
- `ground_with` — the exact `project_authority.md` entry id bound to this target
- `why_live` — one-sentence liveness rationale (age + velocity)
- `entry_substance` — the bound entry's core claim/fact (copied verbatim from authority)
- `entry_angle` — how the Drafter should enter from this entry (one clause, no drafting)
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
      "pillar": "agentic-systems",
      "touches": ["scheduling", "reliability", "orchestration"],
      "ground_with": "P5-launchd-agent",
      "why_live": "6h old, 310 likes in first 6h — high velocity, safe window.",
      "entry_substance": "launchd-scheduled Claude sub-agent running nightly, zero human trigger; 47 consecutive nights stable",
      "entry_angle": "lead with the scheduler stability number, not the orchestration concept",
      "thread_gist": "swyx argues orchestration beats autocomplete; the replies sharpen it to the cross-family veto being the load-bearing part.",
      "post_type": "discussion"
    }
  ]
}
```

---

## 02_drafts.json

Writer: Drafter (Sonnet 4.6). Readers: Gatekeeper (`gate.sh`), Critic, Producer.

Drafter sees ONE target at a time — the bound `entry_substance` + `entry_angle` + `voice.md` +
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
  The named criterion is one of the SIX: `voice_fit|specificity_present|no_fabrication|not_generic|length_register_sane|thread_fit`.
- `status` — `"drafted"` | `"passed"` | `"failed"` | `"skipped"` | `"held"`
- `retries` — integer, 0-indexed; how many Drafter retries this target consumed
- `skip_reason` — string if status is `"skipped"`, null otherwise

Batch-level fields:
- `held` — boolean. True if the batch halted at the critic gate or any hard-block; a held batch must not be posted.
- `cross_family_veto` — boolean. MUST be false whenever `critic` is `claude-stub` (the stub is not a cross-family veto).
- `critic` — `"grok"` | `"claude-stub"` | `"UNAVAILABLE"`.

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
      "status": "passed",
      "retries": 0,
      "skip_reason": null
    },
    {
      "url": "https://x.com/someone/status/9999",
      "gate_single": "fail",
      "gate_batch": "pass",
      "critic_verdict": "FIX:specificity_present — mentions 'memory' but no number or tool",
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
- DRAFT reply text (marked DRAFT)
- `[VERIFY]` flags if any
- Asset html + png paths, or "open + screenshot" note if Asset role ran
- Skipped targets listed at bottom with skip reasons

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

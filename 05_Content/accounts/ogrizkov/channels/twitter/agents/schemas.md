---
type: pipeline-artifact
artifact: reply-schemas
prd_ref: "§4, §6, §v3.1, v3.2 (spec D6)"
locked: 2026-11-23
---

# v3.2 Artifact Field Reference

Each stage writes one structured file to `runs/<batch>/`. Every hop is file-only — no role reads
another role's reasoning, only its artifact. Batch id format (v3.2): `SLOT_ID_batch`, a second
attempt `SLOT_ID_a2_batch`, with `SLOT_ID` = `YYYY-MM-DD_HHMM` (Israel date and the slot's scheduled
start, from `bin/slot_state.py slot-id`), e.g. `2026-11-24_1530_batch`. The ignore rule
`runs/*_batch/` matches these names; the old suffix-letter form (`2026-11-22_batcha`) is not ignored.

`runs/_index/` is a SHARED non-batch directory: `search_vectors.json` (Vault_Scout), and the run-time
state of the scripts (slot log, ledger, delivery state, sent markers, critic model, authority zones;
see `bin/slot_state.py`). It is created at run time, never by a build.

---

## search_vectors.json

Writer: Vault_Scout (`claude-sonnet-4-6`). Reader: Orchestrator → Scout call B.

Lives in `runs/_index/` — shared, non-batch; persists across runs. Re-generated when
`project_authority.md` or `runs/_index/authority_zones.json` changes OR after 7-day TTL (driven by `generated_at`).

Fields:
- `generated_from` — `"project_authority.md@<hash>"` (hash of the source file at generation time)
- `generated_at` — ISO 8601 timestamp; drives the 7-day TTL
- `vectors[]` — array of vector objects:
  - `id` — unique vector id (e.g. `"V-agentic-orchestration"`)
  - `kind` — `"project"` or `"topic"`
  - `zone` — topic vectors: one authority zone from `authority_zones.json`
  - `content_pillar` — one of `"build"` | `"apply"` | `"results"`
  - `search_intent` — one sentence describing the live-thread angle to find on X
  - `grounds_with` — project vectors: `project_authority.md` entry ids that can honestly ground a reply; topic vectors: empty
  - `answers` / `contests` — project vectors: questions the entry answers / claims it confirms or refutes
  - `query_seeds` — pool of search query phrasings; Orchestrator rotates/samples per run

```json
{
  "generated_from": "project_authority.md@a3f9c12",
  "generated_at": "2026-11-23T10:00:00Z",
  "vectors": [
    {
      "id": "V-agentic-orchestration",
      "kind": "project",
      "content_pillar": "build",
      "search_intent": "threads where people argue about agent-agnostic orchestration / model-as-runner / owning the routing graph",
      "grounds_with": ["CAK-01", "TIT-01"],
      "answers": ["can I swap Claude Code for OpenCode without losing my setup"],
      "contests": ["your agent setup is locked to one vendor"],
      "query_seeds": ["agent orchestration", "model agnostic", "claude code vs opencode"]
    },
    {
      "id": "V-topic-rate-limits",
      "kind": "topic",
      "zone": "rate limits and quirks of providers",
      "content_pillar": "apply",
      "search_intent": "people posting claims or questions about provider rate limits on coding agents",
      "grounds_with": [],
      "query_seeds": ["hit the rate limit", "usage limits reset", "why is my quota gone"]
    }
  ]
}
```

---

## 00_candidates.json

Writer: Scout (Grok via `grok -p`, discovery only). Reader: `bin/target_filter.py prefilter`.

Fields per candidate:
- `url` — full X thread URL
- `author` — @handle (no leading @)
- `author_followers` — int (required; a candidate without it is cut `no_followers`)
- `posted_at` — ISO-8601 UTC (required; without it: `no_posted_at`)
- `views` — integer or null; feeds the momentum signal (a post with no view count has no momentum)
- `likes` — integer or null
- `replies` — integer or null
- `lang` — ISO 639-1 language code (must be "en")
- `source` — `"watchlist"`, `"large"` or the vector id
- `matched_quote` — the sentence in the post that asks or asserts what the vector looked for
- `source_tag` — `"hot"` or `"domain"` (legacy)
- `text_snippet` — first ~280 chars of the opening post (raw, no paraphrase)
- `post_type` — enum `discussion|announcement|poll|meme|promo|question|showcase|listicle|giveaway|connect|growth_tool`;
  everything but discussion, question and showcase is cut by `target_filter.py` (`post_type`)

```json
{
  "batch": "2026-11-24_1530_batch",
  "candidates": [
    {
      "url": "https://x.com/swyx/status/1234567890",
      "author": "swyx",
      "author_followers": 12000,
      "posted_at": "2026-11-24T12:55:00Z",
      "views": 4200,
      "likes": 31,
      "replies": 17,
      "lang": "en",
      "source": "V-agentic-orchestration",
      "matched_quote": "we stopped trusting one call and started chaining graded sub-agents",
      "source_tag": "domain",
      "text_snippet": "The shift from 'LLM as autocomplete' to 'LLM as orchestrator' is finally clicking in prod systems. Here's what changed for us...",
      "post_type": "discussion"
    }
  ]
}
```

---

## 00b_threads.json

Writer: `bin/fetch_posts.py thread` over the public endpoint (one batched grok call only as the fallback). Reader: `target_filter.py rank`, Matcher, Drafter, Critic, interest reviewer.

Fields per entry:
- `url` — the survivor URL the thread was read for
- `opening_post` — full text of the opening post (not the 280-char snippet)
- `top_replies` — array of `{author, text, url}`, the top replies as ranked by the endpoint (the author's own replies excluded)
- `engagement` — `{views, likes, replies, quotes, reposts, bookmarks}`, each int|null. Raw counts only.
- `captured_at` — ISO-8601 read time; the staleness window the Critic accepts (PRD §178-182).
- `op_replies_in_thread` — int: replies by the post's author in the thread (the "answers" signal)
- `author_followers`, `posted_at` — filled from the endpoint
- `thread_gist` is no longer written here: the Matcher writes it into `01_anchored.json` from the snapshot.

This artifact is the Critic's judging snapshot. The Critic NEVER opens the URL; it judges from this snapshot.

```json
{
  "batch": "2026-11-24_1530_batch",
  "threads": [
    {
      "url": "https://x.com/swyx/status/1234567890",
      "opening_post": "The shift from 'LLM as autocomplete' to 'LLM as orchestrator' is finally clicking in prod systems. Here's what changed for us: we stopped trusting one call and started chaining graded sub-agents.",
      "top_replies": [
        {"author": "@hingeloss", "text": "the grading step is the whole game — without a veto you just compound the first model's bias", "url": "https://x.com/hingeloss/status/1234567899"}
      ],
      "engagement": {
        "views": 4200,
        "likes": 31,
        "replies": 17,
        "quotes": 2,
        "reposts": 5,
        "bookmarks": null
      },
      "captured_at": "2026-11-24T13:45:00Z",
      "op_replies_in_thread": 2,
      "author_followers": 12000,
      "posted_at": "2026-11-24T12:55:00Z"
    }
  ]
}
```

---

## 01_anchored.json

Writer: Matcher (Opus 4.8). Readers: Drafter (per-target), `target_filter.py check-item`, `produce.py`, `slot_state.py record`.

The Matcher decides what the thread lacks first (claim-first fit test), then whether a project fact
is that thing (Deep) or not (Clean, the default). Fields per target:
- `url`, `author`, `engagement` — as in the snapshot
- `reply_to_url` — the post the reply goes under (top-level by default; the author's own follow-up or a named person's reply)
- `author_followers`, `tier` (1, 2, or 3 for the large-account lane), `posted_at`, `age_min_at_capture`, `parent_views_at_capture`, `momentum` (bool), `rank` (0-based rank order)
- `content_pillar`, `project_pillar`, `vector`, `post_type`
- `thread_gist` — one sentence written by the Matcher from the snapshot
- `author_claim` — the claim or question addressed, a quote of 15 words or fewer
- `open_point` — what the thread has not settled
- `move` — `answers_question|contradicts|counter_example|measures_same_variable|adds_boundary_condition|failure_story|practitioner_question`
- `reply_type` — `deep` | `clean`
- `claim_origin` — `project_fact|thread|public_source|question`
- `zone` — the authority zone of a Clean item
- `fit` — 0-3 (only fit 3 binds Deep)
- `contribution` — the one checkable thing the reply adds, written first with no project noun or number
- `ground_with`, `entry_substance` — Deep: the bound entry id and its substance (verbatim); Clean: null
- `his_words` — the entry's `his_words` line when it has one, else null
- `source_url`, `source_quote` (exact sentence, 40 words or fewer), `basis` (one line) — public_source only

```json
{
  "batch": "2026-11-24_1530_batch",
  "targets": [
    {
      "url": "https://x.com/swyx/status/1234567890",
      "reply_to_url": "https://x.com/swyx/status/1234567890",
      "author": "swyx",
      "author_followers": 12000,
      "tier": 1,
      "posted_at": "2026-11-24T12:55:00Z",
      "age_min_at_capture": 50,
      "parent_views_at_capture": 4200,
      "momentum": true,
      "rank": 0,
      "engagement": {"views": 4200, "likes": 31, "replies": 17},
      "content_pillar": "build",
      "project_pillar": null,
      "vector": "V-topic-rate-limits",
      "post_type": "discussion",
      "thread_gist": "swyx argues orchestration beats autocomplete; the replies say the veto is the load-bearing part.",
      "author_claim": "we stopped trusting one call and started chaining graded sub-agents",
      "open_point": "nobody says what grades the grader",
      "move": "practitioner_question",
      "reply_type": "clean",
      "claim_origin": "question",
      "zone": "AI tooling and workflows",
      "fit": 3,
      "contribution": "asks which model family grades the sub-agents, the point the replies leave open",
      "ground_with": null,
      "entry_substance": null,
      "his_words": null,
      "source_url": null,
      "source_quote": null,
      "basis": null
    }
  ]
}
```

---

## 02_drafts.json

Writer: Drafter (Sonnet 4.6). Readers: Gatekeeper (`gate.sh`), `target_filter.py check-item`, Critic, interest reviewer, `produce.py`.

Drafter sees ONE target at a time (see `role_specs/drafter.md`). Fields per draft:
- `url` — target thread URL
- `reply_type` — `deep` | `clean`
- `ground_with` — Deep: the entry id (must match `01_anchored.json`); Clean: null
- `answers` — the quoted line the reply answers, verbatim from the opening post or a top reply
- `point` — one line, 12 words or fewer: what the reply adds
- `hook` — `{id, name, instruction}`: the hook id and short name from `reply_patterns.md`, and one plain line (15 words or fewer, no id) that tells him how to open
- `draft` — the reply: finished text in his voice that he posts as it is (gate: 5–40 words, 25 in the large-account lane; no `!`, no link, no hashtag)
- `yours` — optional: one short question to him about his own experience on this exact point
- `verify_flags` — array of `[VERIFY]` strings; empty array if none
- or `{"url", "skip": "no turn"}` / `{"url", "skip": "no hook"}`

```json
{
  "batch": "2026-11-24_1530_batch",
  "drafts": [
    {
      "url": "https://x.com/swyx/status/1234567890",
      "reply_type": "clean",
      "ground_with": null,
      "answers": "we stopped trusting one call and started chaining graded sub-agents",
      "point": "Which model family grades the sub-agents",
      "hook": {"id": "H1", "name": "Question first, one concrete detail", "instruction": "Ask which model grades the chained sub-agents."},
      "draft": "Which model grades the chained sub-agents, the same family that wrote them or a different one?",
      "yours": "Have you run a grader from another model family yourself?",
      "verify_flags": []
    },
    {"url": "https://x.com/someone/status/9999", "skip": "no hook"}
  ]
}
```

---

## 03_review.json

Writer: orchestrator (assembles Gatekeeper, check-item, Critic and interest-review verdicts). This file is the audit trail.

Fields per result:
- `url` — target thread URL
- `gate_single` — `"pass"` | `"fail"` (gate.sh single-draft verdict)
- `gate_item` — `"pass"` or the `target_filter.py check-item` reason code
- `gate_batch` — `"pass"` | `"fail"` (gate.sh --batch over the passed set)
- `critic_verdict` — `"SHIP"` or `"FIX:<criterion>"`. The criteria are the eight of rubric v1.4:
  `no_fabrication|thread_fit|op_relevance|forced_anchor|stranger_interest|ai_tells` (hard) and `no_hype|length_register_sane` (advisory).
- `criteria` — array of `{criterion, verdict: "pass"|"fail", confidence: <0-1 float>, reason}`, one per criterion
- `op_point`, `takeaway`, `tells` — written by the Critic before its verdicts
- `interest` — `{critic_learns, reviewer: {model, learns}, verdict: "pass"|"reject"}` (rule 11; either "nothing" rejects)
- `status` — `"drafted"` | `"passed"` | `"failed"` | `"skipped"` | `"held"` | `"quarantined"` | `"dropped"`
- `drop_reason` — when `status` is `"dropped"` (e.g. `forced_anchor`, `op_relevance`, `interest`, `hook_banned`)
- `retries` — integer; `skip_reason` — string if skipped, else null

Batch-level fields:
- `held` — boolean. True if the batch halted at the critic gate or any hard-block; a held batch is not mailed.
- `cross_family_veto` — boolean. MUST be false whenever `critic` is `claude-stub`.
- `critic` / `critic_model` — the telemetry id of the run's critic (from `runs/_index/critic_model.json`), `"claude-stub"` or `"UNAVAILABLE"`.
- `_calibration` — the per-call probe result: `probes_injected`, `probes_shipped`, `result` (`"pass"` | `"abort"`), `probe_ids` (from `bin/qualify_critic.sh --pick`), evaluated by `qualify_critic.sh --evaluate`. Probe entries are NEVER in `results[]`.

```json
{"_calibration":{"probes_injected":2,"probes_shipped":0,"result":"pass","probe_ids":["probe-forced-anchor-01","probe-good-01"]}}
```

```json
{
  "batch": "2026-11-24_1530_batch",
  "critic": "<telemetry id from critic_model.json>",
  "cross_family_veto": true,
  "held": false,
  "results": [
    {
      "url": "https://x.com/swyx/status/1234567890",
      "gate_single": "pass",
      "gate_item": "pass",
      "gate_batch": "pass",
      "critic_verdict": "SHIP",
      "op_point": "chaining graded sub-agents beats one call",
      "takeaway": "whether the grader shares the writer's model family",
      "tells": [],
      "criteria": [
        {"criterion": "no_fabrication", "verdict": "pass", "confidence": 0.95, "reason": "a question, no claim"},
        {"criterion": "thread_fit", "verdict": "pass", "confidence": 0.87, "reason": "asks about the post's own mechanism"},
        {"criterion": "op_relevance", "verdict": "pass", "confidence": 0.9, "reason": "aimed at op_point"},
        {"criterion": "forced_anchor", "verdict": "pass", "confidence": 0.9, "reason": "no own-work clause"},
        {"criterion": "stranger_interest", "verdict": "pass", "confidence": 0.8, "reason": "names a concrete open point"},
        {"criterion": "ai_tells", "verdict": "pass", "confidence": 0.8, "reason": "no tells"},
        {"criterion": "no_hype", "verdict": "pass", "confidence": 0.92, "reason": "flat"},
        {"criterion": "length_register_sane", "verdict": "pass", "confidence": 0.9, "reason": "one sentence"}
      ],
      "interest": {"critic_learns": "that grader family is the open variable", "reviewer": {"model": "claude-opus-4-8", "learns": "the replies never say who grades"}, "verdict": "pass"},
      "status": "passed",
      "retries": 0,
      "skip_reason": null
    },
    {
      "url": "https://x.com/someone/status/9999",
      "gate_single": "pass",
      "gate_item": "pass",
      "gate_batch": "pass",
      "critic_verdict": "FIX:forced_anchor",
      "status": "dropped",
      "drop_reason": "forced_anchor",
      "retries": 0,
      "skip_reason": null
    }
  ]
}
```

---

## replies_to_post.md (v3.2)

Writer: `bin/produce.py`. Format: Markdown. The review file the mail is built from (`bin/email_replies.py`); the operator posts manually, never auto-posted.

Header lines: `slot:`, `mode:` (trial|live), `stage:`, `post_today:` (the number of items marked recommended), `post_reason:`, `post_short:` (why `post_today` is below the budget's, e.g. "only 1 item passed"; empty otherwise), `today_more:`, `stage_note:`, `items:`, `critic:`, `calibration:`, `status_line:`, and `status: HELD - DO NOT POST` when held.

Per delivered item under `### N. URL`: `- author:`, `- followers:`, `- tier:`, `- mark:` (recommended or review), `- lane:` (large, on large-account items only), `- type:`, `- claim:`, `- bound:`, `- views:` (the post's views at capture), `- posted_at:`, `- age_min:`, `- HOOK:` (id, a middle dot, short name; for the logs, never shown in the mail), `- OPEN:` (the instruction line), `- QUOTE:`, `- POINT:`, `- DRAFT:`, optional `- YOURS:`, for `claim: public_source` `- SOURCE:` and `- BASIS:`, optional `- VERIFY:`.

Then `## Skipped` (skipped, dropped and over-cap items with reasons) and `## Quarantined` (reject history). Only the text before `## Skipped` / `## Quarantined` is ever mailed.

The mail shows per item only the number, the badge ("Post this" or "For review", plus "Large account"), one line with @author, followers, post age and views, the reply (`- DRAFT:`), VERIFY notes when present, the post-by time and the "Open post" button. `- HOOK:`, `- OPEN:`, `- POINT:`, `- QUOTE:`, `- YOURS:`, `- SOURCE:` and `- BASIS:` stay in this file and the logs for measurement and are not mailed.

---

## Derived jq views

`runs/<batch>/targets/tN.json` and `runs/<batch>/drafts/tN.json` are per-target **projections** of
`01_anchored.json` and `02_drafts.json` — jq views split out for per-target sub-agent invocation, NOT a
parallel source of truth. The single-file schemas above stay authoritative; the per-target files inherit
whatever those carry (incl. `thread_gist`, `post_type` and the v3.2 fields). Regenerate them from the source files; never
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

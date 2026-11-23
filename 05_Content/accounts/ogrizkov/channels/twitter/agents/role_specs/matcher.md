---
type: pipeline-artifact
artifact: reply-role-matcher
tier: 2
model: "claude-opus-4-8"
prd_ref: "§4.2, §v3.1.3, v3.2 (REVIEW R2 edit 1, DECISION section 2)"
locked: 2026-11-23
---

# Matcher — fit judgment + reply type (Deep or Clean)

Decide first what the thread lacks, then whether a project fact is that thing. Grounds; never writes replies.

Why Opus not Sonnet: the fit judgment is the highest-leverage judgment in the pipeline — a wrong bind poisons every downstream draft of that target. The deterministic limits (rule 10: age bands, reply counts, tiers, the large-account lane, already delivered) run BEFORE the Matcher in `bin/target_filter.py prefilter` and `rank`, so the expensive judgment never sees a dead or out-of-limit candidate.

## Contract

Reads:
- `runs/<batch>/00_candidates.json` survivors in rank order (from `target_filter.py rank`), per wave
- `runs/<batch>/00b_threads.json` (snapshots read by `bin/fetch_posts.py`)
- `../../project_authority.md` ONLY for grounding
- The budget fields it needs: `resting_entries`, the large-account lane flag (tier 3) and `reuse:` cooldowns
- `runs/_index/authority_zones.json` (the zone list; never `voice.md`)
- For a `public_source` claim: at most one public source per target that the Matcher opens itself

Writes: `runs/<batch>/01_anchored.json` — per target the fields of `agents/schemas.md` (01_anchored.json, v3.2): `url`, `reply_to_url`, `author`, `author_followers`, `tier`, `posted_at`, `age_min_at_capture`, `parent_views_at_capture`, `momentum`, `engagement`, `content_pillar`, `project_pillar`, `vector`, `thread_gist` (written here, from the snapshot), `post_type`, `author_claim`, `open_point`, `move`, `reply_type`, `claim_origin`, `zone`, `fit`, `contribution`, `ground_with`, `entry_substance`, `his_words`, `source_url`, `source_quote`, `basis`, `rank`. Every drop is recorded with a reason (`runs/<batch>/_matcher_drops.json`).

## Must-not-see

`../../../../voice.md`, `../../reply_register.md`, search internals, any other role's reasoning, drafts, asset templates.

## Claim-first fit test

```
Step A (before opening project_authority.md): write author_claim, the one claim
  or question to address, with a quote of 15 words or fewer from the OP or a
  named reply; and open_point, what the thread has not settled.
Step B: move ∈ {answers_question, contradicts, counter_example,
  measures_same_variable, adds_boundary_condition, failure_story,
  practitioner_question}.
  "Corroborates" and "extends" are not moves.
  answers_question: the quote is a literal question and the entry holds the
    answer, including the how.
  measures_same_variable: the entry's number measures the variable in
    author_claim, not a neighbouring one.
Step C (subtraction): rewrite the contribution with no project noun or number.
  If what remains is the OP's thesis or already in top_replies, DROP no_fit.
Emit fit 0-3. Only fit=3 binds (Deep). No candidate is owed a bind.
```

`contribution` keeps its field name with the meaning of Step C: the one checkable thing the reply adds, written first, with no project noun or number.

## Reply types (Deep and Clean)

Decide what the thread lacks first: a mechanism, a number, a boundary case, a counterexample or a failure mode. Only then check whether a project fact is that thing.

- **Yes: Deep.** The entry is not resting (`resting_entries` and its `reuse:` days) and it passes the Deep bind rule: something happened in it (past tense with a consequence, or a measured number) or it has a `finding:` line. An entry that only describes how his system is built does not bind. When that rule blocks a Deep bind that otherwise fit, append one line to `runs/_analytics/finding_requests.md` (date, entry id, thread URL, the thread's question); the main session then asks the operator for one `finding` line. Deep needs fit 3. At most 1 Deep a day is recommended for posting (`produce.py` sets the marks; a second Deep item is delivered for review).
- **No: Clean, the default path.** No project fact and no implied experience. `claim_origin` is `thread` (the point follows from the snapshot by plain reasoning), `public_source` or `question` (a point that cannot be verified becomes a question). The item names its `zone` from `authority_zones.json`; a Clean item outside the authority zones is dropped (`outside_zones`). `ground_with` and `entry_substance` are null.
- **public_source:** open at most one public source per target (official docs, a repository file, a paper, a vendor changelog; never another X post or a login page), save the page text to `runs/<batch>/sources/tN.txt`, and record `source_url`, `source_quote` (the exact sentence, 40 words or fewer) and `basis` (one line). `bin/target_filter.py check-item` verifies the quote against the saved page.
- **Nothing to add:** drop with a reason. "Obvious but relevant" fails.
- There is no limit like "max 2 per batch" on Clean items; Clean is the normal case.
- Large-account lane (tier 3, accounts above 125,000 followers, posts under 60 minutes old): a correction or a number only (`move` contradicts or measures_same_variable); anything else is dropped.
- Top-level by default; `reply_to_url` may point at the author's own follow-up or at a named person's reply.

## Hard boundaries

- Rule 10 limits are applied before the Matcher by `bin/target_filter.py`; the Matcher never re-admits a cut candidate. Band rule: every candidate of the 0-90 minute band is processed first; a 91-210 minute candidate only when no fresh candidate has passed in this run.
- Replyability gate (distinct from groundability — 2026-06-16 lesson: launches/promos are not conversations). **Reply ONLY to genuine discussion. HARD-DROP any target whose `post_type` is `promo`, `meme`, `poll`, `announcement`, `showcase`, `listicle`, `giveaway`, `connect` or `growth_tool`** — replying to them reads as congratulations or a self-promo hijack, never an additive contribution. The ONLY exception: a launch/announcement that has spawned a genuine *technical debate in its replies* that the reply can substantively join — and then bind against that debate, not the announcement. Groundable ≠ replyable. When in doubt, DROP.
- **Stealth-scope exclusion (hard-drop):** NEVER bind GRW-01, GRW-02, or any entry whose tags include `stealth`, `anti-detection`, or `bot-evasion`, or whose `reply_scope` is `excluded` — drop such candidates even if otherwise contributable. Anti-detection / bot-evasion substance is not for public reply grounding; a wrong bind here is a reputational landmine, not a poisoned draft.
- Bind 1:1 (Deep): one DISTINCT `project_authority` entry per target; no entry reused within a batch; resting entries never bind. Bind against the snapshot, not the snippet.
- Contributability (the bind condition): the `contribution` is written first from the THREAD's perspective, with no project noun or number (Step C), and it must answer `author_claim` through the chosen `move`. If the honest sentence requires redirecting the thread toward the entry's topic, the bind is a pivot — DROP. **(Domain/Mechanism Transfer — 2026-06-23 lesson: topic-adjacent ≠ mechanism-maps):** bind only if the entry's specific mechanism transfers onto what the OP is actually discussing; same theme + different mechanism/domain = DROP. **(Forced-bind tell — 2026-06-23):** if the point can only be made concrete by introducing a proper noun or number the thread itself does not use, the bind is forced — DROP at bind time with a recorded reason. **(Over-drop guard — load-bearing):** a cross-domain bind is CORRECT when the mechanism is genuinely analogous AND the thread already uses the anchoring vocabulary — DEV-01 (RabbitMQ/STOMP) on a distributed-systems idempotency thread BINDS. Worked negatives: cyber_razz/DEV-09 (TTS-cost ↛ LLM-cost: audio-synthesis credit economy ≠ token pricing, DROP), arvidkahl/DEV-08 (xcodebuild ↛ web-product: iOS build harness ≠ web CI, DROP), danpopenko/DEV-05 (PWA ↛ game-visuals: service-worker domain ≠ game visual debugging, DROP).
- Tag content_pillar (build|apply|results, THIS target), project_pillar (Deep: the entry's pillar), vector (source vector id or `watchlist`/`large`).
- Does NOT balance the batch — pillar mix is a tie-breaker only (E18), applied by `target_filter.py`; the Matcher never sees all candidates (preserves §9 isolation).
- Results-bucket rule: a Deep results target binds only if the bound entry carries a real build/process number; never vanity metrics.
- Replacement: a dropped target is replaced by the next candidate in rank order; no extra discovery call.
- A wrong bind poisons the target's whole downstream chain — no speculative or partial-fit binds.

# Reply quality review, 2026-11-22: specialist panel

Input: [[SCHEDULED_RUNS_ISSUES]] (Q-3 AI voice, Q-4 boring and forced replies, incidents, risks), batch `runs/2026-11-22_batcha/`.
Panel (read-only, independent, no file edits): R1 X reply strategist (Fable), R2 relevance and Matcher specialist (Fable), R3 voice ghostwriter (Fable), R4 critic and gate designer (Fable), R5 unattended reliability engineer (Opus). Full reports are verbatim in §5.
Status: **proposals only. Nothing in the pipeline has changed.** Implementation is tracked as a board task.

## 1. Diagnosis (all four quality specialists agree)

The replies are boring because the pipeline is built to produce "me too, plus my project":
1. **Matcher accepts agreement as a contribution.** 5 of 9 binds start with "Corroborates"; those scored fit 1 of 3. Binds that "answer" a question scored 2-3. (R1, R2, R3; verified in `01_anchored.json`.)
2. **Critic rewards forcing the project in.** `specificity_present`, `not_generic` and `positioning_alignment` fail a reply without his project nouns. In round 1 it failed a real question to the OP ("Did any of your four hide until real inputs got noisier?"); the redrafts became anchor recitals (#3, #8). Its `voice_fit` only means "no hype", so it cannot fail an AI voice. Neon saw the tells ("E1-E5 is slightly cryptic", "phrased as a maxim") and passed them because the rubric told it to. The critic is also handed the Matcher's `claimed_contribution` (advocate's brief). (R4; verified.)
3. **Drafter sees only a one-line gist,** is told to "draft the contribution sentence", and the batch gate forces half the batch to 12 words or fewer (5 of 8 are exactly 12). (R3, R4.)
4. **Targets are stale or wrong.** 5 of 8 shipped were 27-44 h old; one is a promo article; one is reply number 78. Only martynov014, nateherk and yeemio were worth replying to. The best-matching posts (craigbalding, lmacvittie) were cut for low reply count. (R1, R2.)
5. **Quota pressure.** TARGET=5 acts as a minimum; an empty slot triggers new attempts. 10 a day from ~31 entries on a 7-day reuse means the same 5 facts repeat (2026-11-01 and 2026-11-22 batches). (R1, R2, R3.)
6. **Stale material.** `project_authority.md` was last changed in June; entries describe features, not what happened. Recent real stories (green check on a dead model, critic passing 8 of 8 on voice) are missing. (R1, R2, R3.)
7. **Fake ESL.** Planted tics on native-clean grammar read as a costume. (R3, R4, Fable Appendix A.)
8. Calibration probes are cartoon spam with fake snapshots; a weak Flash critic would pass them. (R4.)

## 2. Consolidated edit plan

Priority order: fit and targets first, then critic and gate, then drafting and voice, then reliability. Each item names its source report.

### P0: substance (what the reply says)
| # | Change | Files | Source | Verify |
|---|--------|-------|--------|--------|
| E1 | Claim-first fit test: Matcher writes `author_claim` (quote ≤15 words) and `open_point` BEFORE opening the authority file; must pick a `move` ∈ {answers_question, contradicts, counter_example, measures_same_variable, adds_boundary_condition, failure_story, practitioner_question}; "corroborates"/"extends" are drops. Subtraction test: remove project nouns and numbers; if what remains is the OP's thesis or a top reply, DROP. Only fit 3 binds. | `agents/role_specs/matcher.md`, `agents/schemas.md` | R1, R2, R3 | Replay batcha: ≤3-4 binds, no "Corroborates" |
| E2 | TARGET becomes a ceiling, no minimum. 0 shipped is a correct outcome (log line, no email, no retry). Self-heal only for infrastructure failures. Cap per slot: 3 (R1, R3) or 5 (R2) — **operator decides**. | `skill/twitter-reply-orchestrate.md`, scheduled `SKILL.md` | R1, R2, R3 | shipped ≤ cap; 0-ship slot uses 1 attempt |
| E3 | Freshness and liveness: age at capture ≤8 h (≤3 h under 1k views), drop threads over 40 replies, keep exact-match posts regardless of reply count; record a reason for every shortlist cut; add `author_followers`, `op_replies_in_thread`, reply URLs. | `agents/role_specs/scout.md`, `matcher.md`, shell pre-filter | R1, R2 | Replay keeps martynov014, nateherk, yeemio; craigbalding/lmacvittie survive |
| E4 | Critic rubric v1.4: replace `specificity_present`, `not_generic`, `positioning_alignment`, `voice_texture` with HARD `op_relevance`, `forced_anchor` (no redraft, drop), `stranger_interest` (must write a `takeaway`), `ai_tells` (listed tells a-h); rename `voice_fit` → `no_hype`. Allow a question path where specifics come from the OP's post. Stop passing `claimed_contribution`; pass `author_claim` and `move`. Exact text in R4 §2.1. | `agents/role_specs/critic.md`, runbook 4c | R4, R2, R1 | `grep -c claimed_contribution _critic_prompt.txt` = 0; probes below |
| E5 | Real calibration probes on frozen snapshots, fixed set every call, per-criterion `expect`: batcha #1 and #6 must fail `ai_tells`, a forced-anchor probe, a boring "same here" probe, and `probe-good-01` that must SHIP. | `tests/critic_probes.json`, runbook 4c | R4, R2, R1 | all probes match per criterion |
| E6 | Forced-anchor or op-relevance fail drops the target; never redraft it. | runbook 4d | R4 | redraft count for those = 0 |
| E7 | Drafter reads the target's `opening_post` and `top_replies`, fills `answers` (quoted line it replies to) and `turn` (what it adds that the thread lacks); may return `{"skip":"no turn"}`. Deletion test: if it reads fine with the OP deleted, skip. | `agents/role_specs/drafter.md` (Reads, Hard boundaries) | R3 | rerun batcha: ≥2 skips; `answers` greps in snapshot |
| E8 | Length follows the turn: usually 2-3 plain sentences, 15-40 words; one line only for a single fact. Remove `needshort`/`maxlong` from the batch gate in the same change. | `drafter.md` l.12-14, `bin/gate.sh` l.86-105, `skill/twitter-reply-draft.md` | R3, R1 (R4 notes the 12-word fill) | batch gate passes R3 rewrites |

### P0/P1: voice
| # | Change | Files | Source |
|---|--------|-------|--------|
| E9 | He is the doer in every reply ("I ran", or his dropped-I form "Still running"); a system part as subject is a changelog line. No run of >3 words from `entry_substance`/`contribution` (numbers with units and tool names exempt). Gloss or drop internal labels (E1-E5, macro, vault, kernel, injection, delta, boot sequence, cross-family). Numbers keep unit and referent. No aphorisms. End on a statement; a question only if it names two specifics he would use. Do not plant typos, calques or dropped articles. Few-shot: batcha #3/#6/#8 BAD vs R3 rewrites GOOD, #1 as SKIP. | `drafter.md` l.40-41 (FORM ROTATION, REGISTER TEXTURE) | R3 |
| E10 | Texture comes from him: use an entry's `his_words` line verbatim-ish; otherwise write plain. Planted tics ≤1 each per batch, none repeated in consecutive batches. Replace "`E1-E5` stays" with "write 'five classes of errors'". | `reply_register.md` | R3, R4 |
| E11 | New rule: with no draft of his, do not imitate his mistakes. Add his Gemma-4 post verbatim as a golden example. | `../../voice.md` `<decision_rules>`, `<golden_examples>` | R3 |
| E12 | Deterministic gate v2.5 (additive): 4-word run vs anchor (`--anchor`), jargon deny-list, closing `?` after an earlier sentence, batch: no-I/my drafts ≤ ceil(n/4), ≤2 drafts with the same word count, any one tic ≤ max(2, n/3) (R4) or ≤1 (R3) — pick one. New fixtures + `verify_gate.sh` cases; `aren;t` must pass. | `bin/gate.sh`, `bin/verify_gate.sh`, `tests/fixtures/` | R4, R3 |
| E13 | Producer copies drafts byte-for-byte, never flags `;`; better, replace the Haiku Producer with a script (also removes R-14). | `agents/role_specs/producer.md` | R4 |

### P1: material (operator input needed)
| # | Change | Files | Source |
|---|--------|-------|--------|
| E14 | Each authority entry gets `finding:` (what he learned) and/or `his_words:` (one raw sentence, never edited); `shape: story|design` and a `tension:` line. Design entries back only a disagreement or question. Entries without a finding are not bindable. Add recent stories (dead-model green check, critic 8/8 pass, refute-mandate critic). **Operator writes ~31 one-liners once, ~15-30 min.** | `project_authority.md` | R1, R2, R3 |
| E15 | Reuse cooldown 7 → 30 days. | `project_authority.md` | R1 |
| E16 | Search by question and claim, not topic: vectors carry `answers[]` and `contests[]`; Scout returns `matched_quote`. | `agents/role_specs/vault_scout.md`, `scout.md` | R2 |
| E17 | Narrow "no vault fact" path: `surface: none` allowed only for contradicts, boundary condition or a one-line-answerable question; max 2 per batch. | `matcher.md`, `critic.md`, schema | R2 |
| E18 | Pillar mix is a tie-breaker only. | runbook §2, `matcher.md` | R2 |
| E19 | Wins logger daily: views, likes, author replied, per move type; store the text he actually posted next to the draft (free few-shots). | `runs/_analytics/wins.md`, wins step | R1, R3 |
| E20 | Fallback critic must be qualified on the full labelled set within 7 days (`bin/qualify_critic.sh`), else hold silently. | scheduled `SKILL.md`, runbook 4c | R4 |

### Reliability (R5)
| # | Change | Pri |
|---|--------|-----|
| E21 | `bin/preflight.sh`: live grok and agy probes down the ladder (winner to `runs/_index/critic_model.json`), Mail automation check without sending, Outbox empty, branch `main` and clean, lock, vector freshness. `verify_gemini_swap.sh` stays a doc lint only. | P0 |
| E22 | `email_replies.py`: parse only before `## Skipped` (today a `### N.` line in Skipped/Quarantined would be mailed — verified structure); catch `TimeoutExpired` → exit 4; per-slot sent marker, never send twice; check Outbox/Sent before retry. | P0 |
| E23 | Run lock (`mkdir` lock, stale after 2 h) and branch guard; consider a worktree outside iCloud (schedule change → operator tests first). | P0 |
| E24 | Single source of truth: `## UNATTENDED MODE` in the runbook plus `agents/critic_ladder.json`; `SKILL.md` shrinks to mode, cap and email command. | P0 |
| E25 | Always-on slot log `runs/_index/scheduler_log.jsonl` (today the file does not exist — verified); next preflight detects missed slots; after 4 empty slots, one line on the board, never email. | P0 |
| E26 | `run_traced.sh --timeout` (perl alarm), `outcome=no_block` when no fenced JSON. | P1 |
| E27 | Speed: P-1 is misdiagnosed (scouts already parallel); fix the two huge thread fetches: one grok call per URL in parallel, start per vector. | P1 |
| E28 | Cost cap: 2 attempts, 75 min per slot, `MAX_GROK_CALLS=20`, 4 attempts a day; trace Claude sub-agent tokens; `runs/_index/spend.jsonl`. | P1 |
| E29 | 17:50 wake (operator sets it, system setting). | P1 |
| E30 | 24/7 host: not now; revisit after ~14 logged slots. | P2 |

## 3. Conflicts between specialists (operator decides)
1. **Cap per slot:** 3 (R1, R3) vs 5 as ceiling (R2). R1 also cites `strategy.md` "2-4 pieces a week, avoid looking like a reply guy".
2. **Tic cap:** ≤1 per batch, no repeat across batches (R3) vs ≤ max(2, n/3) (R4).
3. **Slot timing:** R1 says 08:00 Israel = 01:00 US East, so the morning slot finds stale posts; proposes mid-afternoon. Schedule change → test first.
4. **Expected yield:** with E1-E8 the ship rate drops from 8/9 to about 1-4 per slot. Some slots will be empty (no email). Confirm that is acceptable.
5. **Exposing the pipeline publicly** in replies (yeemio: "critic passed 8 of 8, two reviewers flagged three"): R1/R3 mark [ASK HIM].
6. **5-word operator seed** (Fable Appendix A): R3 says not worth it (breaks unattended runs); use `his_words` lines (E14) instead.

## 4. Rewrites of the 8 batcha drafts (R3, facts from files only)
Not for posting as-is: [ASK HIM]/[VERIFY] items need his input, and most targets are now stale (R1). They serve as GOOD few-shot examples and as calibration material.

1. Sumanth_077: skip unless he supplies his first-dropped item. `Same question I had at session start: what gets thrown away first. I cap how much the agent loads and keep a written order of what to drop when it doesn't fit. Accuracy holding is good news. I'd check what their compaction drops first.` [ASK HIM]
2. martynov014: `You described my rules file. I wrote five classes of agent errors there, and not all of them are wired into the commands yet. Until they are, it's the same wish list, just sorted.`
3. DanielSmidstrup: `An audit before prod. Mine blocked the deploy with 3 critical problems, and one wasn't broken code at all: demo mode was still on, so confidence was hardcoded to 100%.` [ASK HIM: did the agent leave demo mode on?]
4. itsscatto: `In my voice bot one credit is not one price. The same request costs 1 credit when the local model does it and 25 when it goes to the paid API. So the heavy user spends his own credits faster.`
5. kevinlu310: `Point 2 matches what I saw. I ran 3 sub-agents on my iOS app's localization, one language each, and each got only the strings that changed. 2,253 translations merged, the old ones untouched. There was no handoff, so nothing to lose in a summary.` [VERIFY]
6. nateherk: `A tip next to yours: keep nothing important in the chat. My agents write the state to markdown files and read it back at start, so a compact takes nothing I need. Side effect: I can switch from Claude Code to OpenCode and the work continues.` [VERIFY]
7. yeemio: `For the part a hash can't check, I keep the judge on another model family: Claude writes, a non-Claude model scores. It helps, but it's not a hash. Last run it passed 8 of 8, and two other reviewers flagged three.` [ASK HIM: OK to say publicly?]
8. sristhi_saha: `One of mine sat for weeks. Coordinates were rounded to 3 decimals before the request, about a 110m grid, so the app missed the real nearest address 30-50% of the time. It came out only when a later change cut coordinate noise to 5m.` [ASK HIM: agent-written?]

R1 alternatives (what a strong reply would do instead) are in R1 §2.

## Adjacent bugs reported (not fixed)
- `verify_gate.sh` never runs `same_skeleton.md` or `varied_form.md`; check 0h untested. `--lenient` in `gate.sh` is dead. `schemas.md` says SEVEN criteria, critic emits eight. `critic.md` lists other batch drafts as must-not-see, but the batched call shows all nine. (R4)
- `account.md` points to `voice_evgeny.md`, which does not exist; the file is `voice.md`. (R3)
- 22 of 25 shortlist cuts have no recorded reason. (R2)

## 5. Full specialist reports (verbatim)

### R1. X reply strategist (Fable)

Read-only review, nothing edited. All paths are relative to `/Users/titane0/Library/Mobile Documents/iCloud~md~obsidian/Documents/Mission_Control/05_Content/accounts/ogrizkov/channels/twitter/`.

## 1. Verdict

1. The complaint is correct and built in. The Matcher accepts "corroborates" as a contribution (5 of 9 binds in `01_anchored.json`), and the Critic fails any reply without his project nouns, so every reply is "me too, plus my setup".
2. Targets were wrong before drafting: 5 of 8 were 27–44h old, one is a promo article, one a 77-reply pile. Only martynov014, nateherk and yeemio deserved a reply, and each got the wrong one.
3. Fix order: reply type and skip rule, freshness, three per slot, fresh story anchors; voice gates (Q-3) come after. Ten a day from about 28 June-era facts is the bot risk.

## 2. Per post

| Post | Worth it? | What an interesting reply would do |
|---|---|---|
| 1. Sumanth_077, NVIDIA paper recap, 27h, 32k views | No at top level: day-old broadcast, author absent | Answer @OmiidSayfun's "step 40 needs step 3, re-read or gone?": his sessions start cold, state lives in files, load capped at 30% of the window (CAK-06 evidence line). [ASK HIM: what gets dropped first, and one time it hurt] |
| 2. martynov014, hooks vs CLAUDE.md, 8h, 7.8k | Yes, best topic fit | Counter-example to "hooks don't ask, they check": his verify script asserted a model name, the model was removed, and the check stayed green on a dead model (I-1). [ASK HIM: ok to post] |
| 3. DanielSmidstrup, "what catches agent breakage", 30h | No: reply number 78 | If early, tell the story: the pre-prod audit found confidence hardcoded to 100% from demo mode. [ASK HIM: agent-written code? were tests green? who ran the audit?] |
| 4. itsscatto, pricing article, 44h, 6 likes | No: ends in a pitch for his subreddit list; DEV-09 on LLM cost is `matcher.md`'s own worked negative | At most, answer @Adojz's "caps or metering": credits weighted by backend, local 1x, ElevenLabs 25x. [ASK HIM: does the bot have paying users?] |
| 5. kevinlu310, 7-failures listicle, 37h, 406 views | No: old listicle; a similar one was dropped the same run | Bounded disagreement: point 2 is about handoffs, not agent count. Three parallel agents, 2,253 strings, no overwrites. [ASK HIM: zero handoffs between them?] |
| 6. nateherk, auto-compact 400k, under 1h | Yes, best timing | He asked for tips, so give one. [ASK HIM: do you restart from the last log file instead of compacting? your setting?] |
| 7. yeemio, deterministic final gate, 2h, author answering | Yes | A question from his own text: "authorizationGranted is always false, so what flips it?" Or his own data against the draft's sermon: the cross-family judge passed 8 of 8 on voice, two reviews flagged 3 as AI. [ASK HIM: exposes the pipeline] |
| 8. sristhi_saha, "how often subtle bugs", 35h, 226 views | No: dead, his best story wasted | Add the twist: hidden for weeks, found only when an unrelated change tightened GPS noise. [ASK HIM: was the rounding agent-written? she asks about agent bugs] |

Skipped marcos_placona was the best conversation in the pool (first-hand, author answering everyone); it died on a bad bind.

## 3. Proposed edits

1. **P0, `agents/role_specs/matcher.md` contributability gate (line 36), plus `agents/schemas.md`.** Replace "answers / extends / corroborates" with a required `move`: disagree, name the condition where the claim fails, a number the thread lacks, failure story, practitioner question, or direct answer to an asked question. "Corroborates" becomes a drop.
   - Why: 5 of 9 contributions start "Corroborates"; `drafting_contract.md` gate 3 already bans agreement-only.
   - Verify: re-run on batcha's `00b_threads.json`; expect at most 4 binds and no "Corroborates".

2. **P0, `agents/role_specs/critic.md` rubric (`specificity_present`, `not_generic`, `positioning_alignment`), plus the Matcher 1:1 bind.** Allow a question path where the specifics come from the author's post and the anchor is only a lens.
   - Why: in `03_review_r1.json` the Critic failed "Did any of your four hide until real inputs got noisier?" for dropping the grounded claim. The retries became headlines #3 and #8.
   - Verify: replay both round-1 questions; a question naming the author's specifics ships.

3. **P0, `agents/role_specs/scout.md` contract, plus the Matcher liveness gate.** Age at capture at most 8h, or 3h under 1k views; drop threads with over 40 replies. Add `author_followers`, `op_replies_in_thread` and reply URLs, so a reply can target a sub-reply.
   - Why: 5 of 8 shipped were 27–44h old, and 40 of 57 candidates had under 300 views. My understanding, unverified for 2026, is that a reply the author answers gets lifted; a late one does not.
   - Verify: replaying batcha keeps only martynov014, nateherk and yeemio.

4. **P0, scheduled-task prompt (`TARGET=5`) and `skill/twitter-reply-orchestrate.md` stop conditions.** Hard cap of 3 per slot, no minimum, ranked by move. Raise `reuse` in `project_authority.md` from 7 to 30 days.
   - Why: `strategy.md` says 2–4 pieces a week and "avoid looking like a reply guy"; the schedule allows 10 a day, and batcha shipped 8. Six of its 8 anchors repeat the 2026-11-01 batch with the same facts.
   - Verify: shipped at most 3; no anchor repeats within 30 days.

5. **P1, `project_authority.md` schema.** Add `shape: story|design` and a `tension:` line (expected, happened, number, changed). Design entries may back only a disagreement or a question. Add story entries from recent incidents, each [ASK HIM]: the green check on a dead model, the judge that passed 8 of 8, the refute-mandate judge inventing a new objection each re-judge.
   - Why: the file was last updated 2026-06-09. All three reviews' AI-flagged drafts sit on design anchors (#1, #6, #7); the best-rated (#5, #8) sit on stories.
   - Verify: every new entry has a number and a tension line.

6. **P1, `bin/gate.sh --batch` checks 0b/0c and "Skew short" in `skill/twitter-reply-draft.md`.** Replace the batch quota with shape per move: a question up to 15 words; a story or disagreement in two beats, 18–40 words.
   - Why: the four drafts under 12 words (#2, #4, #7, #8) are unreadable to a stranger. This reverses a June lesson. [ASK HIM]
   - Verify: a reader given only the post and the reply can say what happened.

7. **P1, `agents/role_specs/critic.md`, new hard gate `interest`, plus `tests/critic_probes.json`.** Fail a reply the author has no reason to answer. Plant batcha #1 and #7 as probes.
   - Why: the Critic passed `not_generic` 9 of 9 with reasons like "directly complements".
   - Verify: both probes come back FIX.

8. **P1, `runs/_analytics/wins.md` and the Wins-logger step.** Run it daily; log views, likes and whether the author replied, per move type.
   - Why: the log has been empty since 2026-06-09, so "interesting" is never measured.
   - Verify: rows appear within 48h.

9. **P2, schedule.** 08:00 Israel is 01:00 US East, so that slot finds stale posts. Propose a mid-afternoon slot. [ASK HIM; test first]

## 4. What not to change

- The no-invention rule and `[VERIFY]`; the `no_fabrication` gate caught an invented "never simulator".
- Posting by hand, and email only for real replies.
- The Matcher's promo and showcase drop and the stealth exclusion; its 23 recorded drops were right.
- The Drafter's "entry is a lens, not a noun bank" rule; it is correct, the Critic overrides it.
- Snapshot judging and calibration probes.
- Do not widen search to hit a count, and do not add texture gates before the substance is fixed.

Not verified: author follower counts (absent from the schema), so reach is judged from views only. Nothing was re-run.

### R2. Matcher relevance specialist (Fable)

## 1. Verdict

- Of 9 bindings, 1 genuinely answers the thread, 3 are passable, and 5 are "me too, plus my project". The Critic shipped 8 of them.
- The fit rules already exist in `matcher.md` (contributability, forced-bind tell) and were not obeyed. More prose will not help; the fix has to be structural.
- The pipeline is built to maximise binds: topic-level search, a "corroborates" escape hatch, a Critic that is handed the Matcher's pitch, and a zero-ship slot treated as a failure.

## 2. Binding scorecard

| Target | Author's claim | Anchor | Fit | Why |
|---|---|---|---|---|
| itsscatto | Credits and hard caps protect margin; replies object that a credit only bounds cost if each unit's cost is bounded | DEV-09, credits weighted 1x vs 25x | 3 | Answers an open objection with a mechanism that transfers. The draft then compressed it into something unreadable. |
| DanielSmidstrup | Asks what you use to catch what the agent broke | DEV-03, pre-prod audit | 2 | Answers the literal question. The entry has the catch but not the method, so the reply cannot say what to use. |
| sristhi_saha | Asks how often an agent shipped something subtly broken | DEV-06, lat/lng rounding bug | 2 | Right bug class, real numbers. The entry never says an agent wrote the bug, so it needs a [VERIFY]. |
| nateherk | Auto-compact at 400k; asks for other tips; a reply says compaction loses the reasons | CAK-01, intelligence lives in vault files | 2 | It is a tip and meets the objection. The opener is another replier's line, and "keep decisions in files" is the niche's commonest advice. |
| Sumanth_077 | Paper: frequent compaction keeps accuracy; replies ask what survives to step 40 | CAK-06, session-start injection budget | 1 | Different mechanism (boot injection vs mid-run compaction). "From the other side" is the pivot admitting itself. |
| martynov014 | A CLAUDE.md rule is a request, a hook is a check | CAK-04, E1-E5 defined but not wired | 1 | He is the author's negative example. The anchor is a gap, so there is no experience behind it. The forced-bind tell (a proper noun the thread does not use) fired and was ignored. |
| kevinlu310 | 7-point listicle; thread is discussing point 1, silent failures | DEV-07, 2,253 translations | 1 | Agrees with point 2 using numbers that do not measure the claim. Found via the judge-model vector, so a pure rescue bind. |
| yeemio | Final gate should be a hash, not an LLM; thread settles on tests plus a human | MKT-02, cross-family critic | 1 | Re-proposes an LLM judge as a maxim with no evidence. |
| marcos_placona | Asks whether your agent's handoff has a "not verified" line | DEV-05, PWA offline bug | 1 | Does not answer the question. The Critic killed it, after a draft and two critic rounds. |

Three patterns in the data:
- **The contribution verb predicts fit.** "Answers" scored 3 and 2. "Corroborates" scored 1, 1, 1, 1, 2.
- **5 of 9 binds used an entry outside the vector's `grounds_with`.** Retrieval returned topic neighbours and the Matcher rescued them from the full authority file.
- **The best-matching posts were cut.** craigbalding and lmacvittie made the exact cross-family claim MKT-02 addresses; both had 1 reply and did not survive the shortlist. MKT-02 was then stretched onto yeemio.

## 3. Proposed edits

All paths are under `/Users/titane0/Library/Mobile Documents/iCloud~md~obsidian/Documents/Mission_Control/05_Content/accounts/ogrizkov/channels/twitter/`.

**1. P0: claim-first fit test.** `agents/role_specs/matcher.md` (Contributability gate) and `agents/schemas.md` (01_anchored.json). Replace the free-text `contribution` with:
```
Step A (before opening project_authority.md): write author_claim, the one claim
  or question to address, with a quote of 15 words or fewer from the OP or a
  named reply; and open_point, what the thread has not settled.
Step B: move ∈ {answers_question, contradicts, counter_example,
  measures_same_variable, adds_boundary_condition}.
  "Corroborates" and "extends" are not moves.
  answers_question: the quote is a literal question and the entry holds the
    answer, including the how.
  measures_same_variable: the entry's number measures the variable in
    author_claim, not a neighbouring one.
Step C (subtraction): rewrite the contribution with no project noun or number.
  If what remains is the OP's thesis or already in top_replies, DROP no_fit.
Emit fit 0-3. Only fit=3 binds. No candidate is owed a bind.
```
- Why: the Matcher currently writes the contribution with the entry in hand, which is rationalisation. `drafting_contract.md` gate 3 ("no agreement-only, skip") is not wired into any role.
- Verify: replay batcha; expect 3 binds or fewer. Save the 9 as fixtures with expected fit.

**2. P0: TARGET becomes a ceiling.** `skill/twitter-reply-orchestrate.md` (section 3 and CAPS) and `~/.claude/scheduled-tasks/twitter-reply-pipeline/SKILL.md`.
```
MAX_SHIP = 5 (ceiling). MIN_SHIP = 0. Rank binds by fit, then views; draft only
the top MAX_SHIP. A slot that ships 0 is a correct outcome: one line in
scheduler_log.md, no email.
```
Delete "Batch ends with 0 shipped: start a fresh attempt". Keep self-heal for infrastructure failures only.
- Why: TARGET 5 produced 9 bound and 8 shipped, and an empty slot triggers up to two more runs hunting for something to say.
- Verify: shipped is 5 or fewer; a zero-ship slot uses one attempt. Expect 1-3 replies per slot.

**3. P0: Critic must catch "me too".** `agents/role_specs/critic.md` (inputs, thread_fit) and `tests/critic_probes.json`.
- Stop passing `claimed_contribution`; pass `author_claim` and `move` instead.
- Add to thread_fit: "FAIL if, with the replier's project nouns and numbers removed, the reply only restates the OP or a top reply."
- Add probes `probe-metoo-01` (batcha #1 verbatim) and `probe-gap-01` (batcha #2).
- Why: thread_fit passed 8 of 9 at 0.78-0.92, and `not_generic` rewards inserting the anchor. The existing probes cover pivot, fabrication and promo, not this failure.
- Verify: both probes return FIX; re-judging batcha fails at least 4.

**4. P1: search by question and claim, not topic.** `agents/role_specs/vault_scout.md` (Vector rule) and `agents/role_specs/scout.md`.
```
Each vector carries answers[] (questions an entry answers, answer present in the
entry) and contests[] (claims people post that the entry confirms or refutes
with its own evidence). query_seeds are phrasings of these only. An entry with
neither gets no vector.
Scout: return a candidate only with matched_quote, the sentence in the post
that asks or asserts it.
```
- Verify: share of binds where `ground_with` is in the vector's `grounds_with` rises from 4/9 to at least 80%.

**5. P1: reply count is not liveness for exact hits.** `matcher.md` liveness gate and the shell pre-filter: "Keep a post with an exact `matched_quote` if age is 24h or less and post_type is discussion or question, regardless of reply count."
- Verify: craigbalding and lmacvittie survive a replay.
- I could not confirm the exact cut rule: 22 of the 25 shortlist cuts have no recorded reason. Record one per cut.

**6. P1: allow a reply with no vault fact, narrowly.** `matcher.md`, `critic.md`; add `surface: fact|none` to the schema.
```
surface=none: no project noun or number in the reply. Allowed only for
contradicts, adds_boundary_condition, or a question the author can answer in
one line. The entry stays in ground_with as the reason he holds the view.
Critic skips specificity_present and checks the point is absent from
top_replies. Max 2 per batch.
```
- Why: `drafter.md` already permits opinion-only, but the Critic punishes it.
- Not free-floating opinions with no entry behind them. That breaks `drafting_contract.md` gate 1, and #7, the one fact-free draft, was rated AI by both reviewers.

**7. P1: entries need a finding.** `project_authority.md` (Schema): add `finding:`, one operator-written line on what he learned. Entries without one are not bindable. `honest-gap` entries bind only when the thread asks who has not solved X.
- Why: CAK-01, CAK-06 and DEV-09 are feature descriptions, and a description can only yield "I built that too".
- This costs the operator about 30 one-liners once, and also gives Q-3 real phrasing.

**8. P2: pillar mix is a tie-breaker only.** `orchestrate.md` section 2 and `matcher.md`. realpython was cut as "Strong CAK-03 fit... pillar mix" while fit-1 binds shipped. The Matcher also balanced the batch, which its own spec forbids.

## 4. What not to change

- Never-invent, [VERIFY], and the stealth exclusion.
- The promo/announcement hard-drop.
- Vault-first search itself. Starting from his experience is right; the fault is topic-level vectors. Do not go back to hot-thread search.
- One distinct entry per batch, with cooldowns.
- The calibration-probe mechanism and role isolation.
- Do not add voice gates to fix Q-4. Fit is upstream of voice.
- Do not relax fit when a slot comes up empty.

### R3. Voice ghostwriter (Fable)

## 1. Verdict

- The replies are boring because of the rules, not the model: the Drafter sees only a one-line `thread_gist`, is told to "draft the `contribution` sentence" (5 of 9 start with "Corroborates", i.e. "me too"), and `gate.sh` forces half the batch to 12 words or fewer. 5 of 9 batcha drafts are exactly 12 words.
- Fable's gates fix copy-paste and jargon but not boredom. A reply is interesting when it answers one specific line in the thread with something that happened to him and that the thread does not already have.
- Stop faking ESL. Plain first-person English plus his own raw words stored once per entry beats planted `;` typos.

Evidence on voice is thin: there is no archive of his real replies and `runs/_analytics/wins.md` is empty. I grounded on the ~10 verbatim posts in `analysis/2026-05-18_account_review.md`. His top post (60 likes, 13,362 views) is 35 words, drops the "I" ("Still running…", "Tested it heavily…") and ends on a dry question. His architecture thread got 0-1 likes.

## 2. The 8 rewrites

Facts are from `01_anchored.json`, `project_authority.md` and Q-3 only. None of these pass the current batch gate (all are over 18 words); see edit 3.

1. **Sumanth_077**: skip unless he supplies one fact. `Same question I had at session start: what gets thrown away first. I cap how much the agent loads and keep a written order of what to drop when it doesn't fit. Accuracy holding is good news. I'd check what their compaction drops first.` [ASK HIM: what is first on your drop list? That fact makes this worth posting.]
2. **martynov014**: `You described my rules file. I wrote five classes of agent errors there, and not all of them are wired into the commands yet. Until they are, it's the same wish list, just sorted.`
3. **DanielSmidstrup**: `An audit before prod. Mine blocked the deploy with 3 critical problems, and one wasn't broken code at all: demo mode was still on, so confidence was hardcoded to 100%.` [ASK HIM: did the agent leave demo mode on?]
4. **itsscatto**: `In my voice bot one credit is not one price. The same request costs 1 credit when the local model does it and 25 when it goes to the paid API. So the heavy user spends his own credits faster.`
5. **kevinlu310**: `Point 2 matches what I saw. I ran 3 sub-agents on my iOS app's localization, one language each, and each got only the strings that changed. 2,253 translations merged, the old ones untouched. There was no handoff, so nothing to lose in a summary.` [VERIFY: "only the strings that changed" as a gloss of "scoped delta"; "no handoff"]
6. **nateherk**: `A tip next to yours: keep nothing important in the chat. My agents write the state to markdown files and read it back at start, so a compact takes nothing I need. Side effect: I can switch from Claude Code to OpenCode and the work continues.` [VERIFY: "state", "work continues"]
7. **yeemio**: `For the part a hash can't check, I keep the judge on another model family: Claude writes, a non-Claude model scores. It helps, but it's not a hash. Last run it passed 8 of 8, and two other reviewers flagged three.` [ASK HIM: OK to say this publicly? If not, end at "not a hash".] The original draft prescribed a cross-family judge as the answer; batcha itself (Q-3) shows it is not.
8. **sristhi_saha**: `One of mine sat for weeks. Coordinates were rounded to 3 decimals before the request, about a 110m grid, so the app missed the real nearest address 30-50% of the time. It came out only when a later change cut coordinate noise to 5m.` [ASK HIM: did the agent write the rounding? If yes, make the agent the subject.]

**Fable's Appendix A rewrites:** not good enough. They are the same "me too" content with cleaner wording. I would post only #2 and #8, and #8 drops the best part (how the bug surfaced). #1 and #3 add invented ESL ("a priority what to drop first", "Pre-prod audit for me"), which `voice.md` bans as caricature. #7 is still a prescriptive aphorism.

## 3. Proposed edits

1. **P0, `agents/role_specs/drafter.md`, Contract → Reads (line 19).** Add: `That target's opening_post and top_replies from 00b_threads.json.`
   - Why: nobody can react to a person's sentence from a one-line summary.
   - Verify: the `answers` field (edit 2) greps verbatim in the snapshot.

2. **P0, `drafter.md`, Hard boundaries, replacing "Draft the `contribution` sentence … optionally extend with a question to the OP" (line 37).**
   > "INTEREST FIRST. Before writing, fill two fields. `answers`: the one sentence in the thread you reply to, quoted. `turn`: in 12 words or fewer, what your reply adds that this thread does not have: something that happened to him (past tense, with a consequence), an admitted gap, or a number that changes the claim. 'I have this too' is not a turn. A `contribution` that starts with 'Corroborates' is agreement until you find the turn. If the entry only describes how his system is built and nothing happened in it, write `{"skip": "no turn"}`. Deletion test: if the reply reads fine with the OP's post deleted, it is a post about himself. Skip."
   - Why: this is Q-4. It enforces `drafting_contract.md` gate 3, which v3 never checks.
   - Verify: rerun batcha and expect at least 2 skips. The orchestrator must accept a skip (outside my scope).

3. **P0, `drafter.md` lines 12 and 14, plus `bin/gate.sh` lines 86-105.** Replace "skew-short … ≥half of batch ≤12 words" with:
   > "Length follows the turn: usually two or three plain sentences, 15-40 words. One line only when the whole reply is one fact."
   - Remove `needshort` and `maxlong` in the same change, or the gate rejects every rewrite above.
   - Verify: the batch gate passes section 2.

4. **P0, `drafter.md`, replacing the FORM ROTATION and REGISTER TEXTURE bullets (lines 40-41).**
   > "He does something in every reply: 'I ran', 'I wrote', or his own dropped-I form ('Went for coffee', 'Still running'). A sentence whose subject is a part of his system ('Injection has…', 'Pre-prod audit blocked…') is a changelog line: rewrite it with him as the doer. Say the fact in new words: no run of more than 3 words from `entry_substance` or `contribution`, except numbers with their unit and tool names. Replace words a stranger to his repo cannot decode (E1-E5, macro, vault, kernel, injection, delta, boot sequence, cross-family) with what the thing is. Every number keeps its unit and what it counts. No general truth with no person and no time in it ('X is what Y loses'). End on a statement. A question is allowed only if it names two specifics and he would use the answer; never 'do you…?' added after a statement. Do not plant typos, calques or dropped articles."
   - Why: his real posts drop "I" often, so Fable's "subjectless" test is wrong. The tell is a thing as the subject.
   - "Lead with a question back to the OP" produced 3 bare questions in the 2026-11-01 batch and #6's bait question.
   - Few-shot: batcha originals #3, #6 and #8 as BAD, rewrites 3, 6 and 8 as GOOD, and #1 as the SKIP example.

5. **P0, `reply_register.md`, replacing "The texture" list and the first two guardrails.**
   > "Texture comes from him, not from you. If the entry has a `his_words` line, keep his word order and his mistakes; fix only what breaks meaning. If it has none, write plain: short sentences, common words, no connector phrases ('instead of', 'from the other side'). Planted tics per batch: `;` apostrophe at most 1, ` - ` at most 1, lowercase opener at most 1, invented misspellings 0, and never the same tic in two batches in a row. A dropped final period on a one-sentence reply is normal and not counted; with two or more sentences keep the periods."
   - In "Never touch the signal", replace `E1-E5 stays` with: "`E1-E5` is an internal label, not signal: write 'five classes of errors'."
   - Why: his profile shows all batches together, so 2 per batch is about 60 `;` typos a month.
   - Verify: grep counts in `gate.sh --batch`.

6. **P1, `voice.md`, `<decision_rules>` and `<golden_examples>`.** Add the rule:
   > "When there is no draft of his, do not imitate his mistakes. Use the entry's `his_words`; otherwise write plain. Imitated ESL is caricature, same as an inserted 'ofc'."
   - Add his Gemma-4 post verbatim as a golden example, with why: he acts in every sentence, the verdict is four words, the closing question is dry and aimed at a system.
   - Why: the pipeline generates from scratch and the file has no rule for that case.

7. **P1, `project_authority.md`, each entry.** Add an optional `his_words:` line: one raw sentence from him on what happened and what surprised him, never edited.
   - Cost: 31 entries, about 15 minutes, once.
   - Second free source: store the text he actually posted next to each draft in the log-wins step, and use the diffs as few-shots.

8. **P1, `bin/gate.sh --batch`.** Add four deterministic checks: the 3-word run against the anchor, the jargon deny-list, a closing `?` after do/does/did/are/is/have, and the tic counts.
   - On batcha the run check flags #1 (7 words), #3 (8) and #5 (10) but passes #6 and #7 (2 each), which both reviewers called AI. It is necessary, not sufficient.
   - `critic.md:96` defines `voice_fit` as "broadly flat, no hype", so the Critic cannot fail an AI voice. It needs a `turn_present` criterion (outside my scope).

9. **P2, TARGET.** 10 replies a day is 70 a week from 31 entries on a 7-day reuse. The same five facts appear in both the 2026-11-01 and 2026-11-22 batches. Ship 3 or fewer per run.

**Fable's four gates:**

| Gate | Verdict | Change |
|---|---|---|
| Paraphrase cap | Right, incomplete | Cover `contribution` too; exempt numbers and tool names (wording in edit 4) |
| Stranger legibility | Right, P0 | Wording in edit 4; fix the `E1-E5 stays` conflict (edit 5) |
| Shape variety | Wrong mechanism | The Drafter cannot see sibling drafts; make it a per-draft doer rule plus a batch gate |
| Texture-tic cap | Right direction | 1 per batch, not 2, and no repeat across consecutive batches |

**The 5-word seed:** not worth it. It means reading 10 threads before any draft exists, twice a day, and it breaks the unattended run. Use edit 7 instead.

## 4. What not to change

- Never-invent and `[VERIFY]`.
- The KEEP-vs-DROP noun-injection rule.
- One target per invocation, fresh on retry.
- The three gates in `drafting_contract.md` (enforce them, don't rewrite them).
- The anti-mannerism block in `voice.md`.
- The `;` typo as an allowed tic, kept rare.
- `skill/twitter-reply-draft.md`: superseded, leave it.

Adjacent bug, not fixed: `account.md` points to `voice_evgeny.md`, which does not exist; the file is `voice.md`.

I skipped the OS bootstrap and telemetry because this was a read-only task.

Files are in /Users/titane0/Library/Mobile Documents/iCloud~md~obsidian/Documents/Mission_Control/05_Content/accounts/ogrizkov/channels/twitter/ (`voice.md` and `account.md` are two levels up in /Users/titane0/Library/Mobile Documents/iCloud~md~obsidian/Documents/Mission_Control/05_Content/accounts/ogrizkov/).

### R4. Critic and gate designer (Fable)

## 1. Verdict

1. The critic did not miss these drafts; Rubric v1.3 forbids failing them. `voice_fit` is defined as "no hype", `voice_texture` passes on any single tic, and advisory fails need "egregious" at 0.80 or above. Neon's own reasons noted "E1-E5 is slightly cryptic to outsiders", "phrased as a maxim" and "fairly tidy", then passed.
2. The loop manufactures the forced replies. In round 1 the critic failed two real questions to the OP ("Did any of your four hide until real inputs got noisier?") on `not_generic`, `specificity_present` and `positioning_alignment`; the redrafts became anchor recitals (#3, #8). The critic is also handed the Matcher's `claimed_contribution`, which is the advocate's brief.
3. Calibration only checks for a pulse. Probes carry `x.com/probe/status/100000…`, `snapshot:null` and "(none provided)", are cartoon spam, and any FIX counts: probe-pivot-01 "passed" while the critic passed both criteria its `why_bad` says must fail. A Flash model clears that.

Measured on batcha (I ran these; thresholds are fitted to this one batch of 8, so check them against `runs/2026-11-01_batch` before freezing):
- `gate.sh --batch` on `_gate_shipped.txt` returns BATCH PASS.
- Longest verbatim run against `entry_substance`: #1 = 7 words, #3 = 8, #5 = 10; every other draft is 3 or fewer.
- 5 of 8 have no I/my; 5 of 8 are exactly 12 words (the gate's `<=12` "short" threshold is being filled to the cap); 6 of 8 have no terminal punctuation.
- `tests/fixtures/same_skeleton.md` (July) already contains "strictly scoped delta" and "explicit drop priority". The same anchor phrases have been recited for five months.

## 2. Proposed edits

**1. P0. `agents/role_specs/critic.md`, Rubric (v1.4) and output schema.** Replace `specificity_present`, `not_generic`, `positioning_alignment` and `voice_texture` with the four below; rename `voice_fit` to `no_hype`. Require `op_point`, `takeaway` and `tells[]` in the output before any verdict. Exact text:

- **op_relevance (HARD)**: "First write `op_point`: the one claim or question the OP makes, from opening_post only. FAIL if the reply's main clause is about the replier's own system and connects to `op_point` only through shared topic words. FAIL if the reply could be posted unchanged under any other thread on this theme. A reply aimed at a top reply passes only if it addresses that reply's point."
- **forced_anchor (HARD, bind-bad, no redraft)**: "Delete every clause about the replier's own work. If nothing addressed to the OP remains, FAIL: it is a status update. If something remains, the own-work clause must be the evidence for it. Swap test: if a different project detail of the same kind would serve equally well, the detail is decoration, FAIL. 'Same here, mine was X' FAILS unless X adds a cause, number or consequence the thread does not have."
- **stranger_interest (HARD)**: "You read this thread and have never heard of the replier. Write `takeaway`: one thing you now know, doubt or want to ask that opening_post and top_replies did not give you. FAIL if `takeaway` is empty, restates the thread, or is only 'the replier has a system'. FAIL if the point depends on a term you cannot decode (E1-E5, vault, injection, macro). Interesting means new to this thread, not clever. One specific question the OP can answer PASSES."
- **ai_tells (HARD at 2 or more tells, or 1 tell in a reply of 14 words or fewer)**: "List in `tells[]`: (a) noun-stack spec phrasing with no first-person verb; (b) abstract connector ('from the other side', 'the real X'); (c) closing contrast clause ('instead of…', ', not…'); (d) aphorism or 'should' with no stated own practice; (e) restate, my setup, question; (f) closing question the replier does not need answered; (g) subjectless headline; (h) 'we/our' from a solo builder. `;` contractions and dropped periods are not evidence of human typing; ignore them."

Why: these are the operator's complaint (Q-4) and the reviewers' tells (Q-3), written as tests a judge can run instead of a vibe.
Test: probes in edit 3.

**2. P0. `critic.md` Inputs, and runbook step 4c.** Stop passing `claimed_contribution` to the critic.
Why: it anchors the judge on the Matcher's argument for the bind.
Test: `grep -c claimed_contribution _critic_prompt.txt` returns 0.

**3. P0. `tests/critic_probes.json` and runbook 4c EVALUATE.** Give every probe a real frozen snapshot from a past `00b_threads.json` and a realistic URL. Add `expect` and `expect_fail`. Send a fixed set on every call, not a random 1-2. Pass only if each named criterion matches.
- `probe-ai-specsheet-01`: batcha #1 verbatim on the Sumanth snapshot. Must fail `ai_tells`.
- `probe-template-question-01`: batcha #6 verbatim on the nateherk snapshot. Must fail `ai_tells`.
- `probe-forced-anchor-01`: sristhi snapshot ("how many times…"). Draft: "I keep decisions in files, not in chat, my agent reads 8 boot steps before any work. Subtle bugs got rarer". Must fail `forced_anchor`.
- `probe-boring-01`: Daniel snapshot. Draft: "Same here, tests pass and it is still broken. I run the suite and then check by hand before merge". Must fail `stranger_interest`.
- `probe-good-01` (must SHIP, guards against the v1.2 over-refute ditch): "Mine was lat/lng rounded to 3 decimals. It missed the nearest address 30-50% of the time, for weeks" on the sristhi snapshot.

**4. P0. `bin/gate.sh` v2.5 (additive), with new fixtures and `verify_gate.sh` cases.**
```
single, new --anchor <file>   # entry_substance + contribution
  norm = lowercase, strip punctuation
  FAIL if any 4-word run of the draft occurs in the anchor
single: FAIL on JARGON='E[0-9]-E[0-9]|vault|macro|persona|kernel|injection|loader directive'
single: FAIL if draft ends in '?' and has an earlier '. ' or ' - '
batch:  FAIL if drafts lacking \b(I|I;m|I'm|I've|my|mine|me)\b > ceil(n/4)
batch:  FAIL if more than 2 drafts share one word count
batch:  FAIL if any one tic (no terminal punctuation, x;x, ' - ', lowercase opener) > max(2, n/3)
```
Why: all of these are countable, so a model should not be judging them. On batcha they flag #1, #2, #3, #5 and #6 individually, and the batch fails three ways.
Tests:
- `batcha_shipped.md` must fail the batch checks.
- `anchor_paste_fail.txt` (#1 plus the CAK-06 entry) must fail.
- Fable's rewrite of #1 must pass.
- A lone single-sentence question must pass.
- `aren;t` must pass.

Dependency: `reply_register.md` ("`E1-E5` stays") and `drafter.md` say the opposite of the jargon rule. Change them in the same commit, or the Drafter and the gate will fight.

**5. P1. Fallback ladder: `~/.claude/scheduled-tasks/twitter-reply-pipeline/SKILL.md` lines 18-20 and runbook 4c.** Add `bin/qualify_critic.sh <model>`: run the full labelled set (edit 3 probes plus the batcha 8 with reviewer-consensus labels). Require zero must-fail items shipped and at least 10 of 12 agreement. Write the result to `runs/_index/critic_qualified.json`. The ladder may only use a model qualified within the last 7 days; otherwise hold the batch silently.
Why: this closes R-11. The same bar then applies to every model, and one that cannot hold it does not judge.
Test: a stub model that SHIPs everything must be rejected.

**6. P1. `agents/role_specs/producer.md`, Hard boundaries.** Add: "Copy `draft` byte-for-byte. Never correct, annotate or flag draft text; `;` inside a contraction is intentional. `[VERIFY]` comes only from `verify_flags`." Better: replace the Haiku Producer with a script. It is a three-file JSON join, and a script also removes R-14.
Test: a fixture with `aren;t` produces DRAFT lines identical to `02_drafts.json`, with no line matching `/encoding|typo|artifact/i`.

**7. P1. Runbook 4d routing.** A `forced_anchor` or `op_relevance` fail drops the target; it is never redrafted. Tell the Drafter that "short" means 4-12 words and not to fill to 12.
Why: redrafting a forced bind only adds more anchor.

Expect the ship rate to fall from 8 of 9 to roughly 2-4. No judge fixes "an entry looking for a thread"; the root cause is the Matcher's must-bind rule, which is outside my scope.

Adjacent bugs, not fixed:
- `verify_gate.sh` never runs `same_skeleton.md` or `varied_form.md`, so check 0h is untested.
- `--lenient` in `gate.sh` is a dead flag.
- `schemas.md` says "SEVEN" criteria; the critic emits eight.
- `critic.md` lists "other drafts in the batch" under must-not-see, but the batched call shows the critic all nine.

## 3. What NOT to change

- `no_fabrication` and the topic-adjacent-flex clause of `thread_fit`. Both worked: they caught the invented "never simulator" and the marcos draft.
- Cross-family judging, snapshot-read, and binary per-criterion verdicts. Do not add a 1-10 interest score.
- The critic model. Neon saw the tells; the rubric told it to pass them.
- Do not return to the pure-refute mandate. `probe-good-01` is the guard against that.
- Do not add a `;` typo check, and do not demand more texture. More tics on clean grammar is a costume.
- Do not n-gram-block numbers or tool names. The 4-word rule already spares them.

Files, all under `/Users/titane0/Library/Mobile Documents/iCloud~md~obsidian/Documents/Mission_Control/05_Content/accounts/ogrizkov/channels/twitter/`:
- `agents/role_specs/critic.md`
- `agents/role_specs/producer.md`
- `agents/role_specs/drafter.md`
- `reply_register.md`
- `tests/critic_probes.json`
- `bin/gate.sh`
- `bin/verify_gate.sh`
- `skill/twitter-reply-orchestrate.md`

Plus `/Users/titane0/.claude/scheduled-tasks/twitter-reply-pipeline/SKILL.md`.

### R5. Unattended reliability engineer (Opus)

## 1. Verdict
- The pipeline produces replies, but it is not safe to leave unattended yet. Failures are silent by design, nothing checks the live CLIs before a run, and the email path has two ways to break the "only real replies" rule (duplicate sends, and non-shipped drafts getting into the mail).
- P-1 is misdiagnosed. In the batcha telemetry the 8 scout calls ran in parallel (all ended 16:35-16:37, durations 198-342 s) and the 2 thread fetches also ran in parallel (both started about 16:37:51). Wall time was about 31 min: grok about 16, critic about 7, Claude stages about 7. The real speed problems are two huge thread-fetch calls (one 513 s with about 15.6k output tokens) and no timeouts at all.
- Fix order: lock and branch guard, live preflight, email idempotency, one self-heal policy, then speed and cost.

## 2. Top-5 risks (likelihood × impact)
1. **R-8 + R-1, silent missed slots.** `runs/_index/scheduler_log.md` does not exist; the 18:11 halt was never logged there. There is no wake for 18:00. Likely weekly; nobody notices.
2. **R-7, classifier blocks osascript → Mail in a scheduled run.** Never exercised (I-3 and I-6 show the pattern). The whole slot is lost after all the spend.
3. **R-4 + R-9, model churn plus two policies.** The runbook hard-codes Neon in PROBE and says HALT; the scheduled prompt says use the ladder. This already caused I-1 within 3 weeks.
4. **R-12 + R-14, duplicate or wrong email.** No lock, no sent-marker. Also `parse()` splits on `^### ` across the whole file, so a quarantined or skipped entry with a `### N. url` / `- DRAFT:` line would be mailed as ready to post. The hard requirement is broken here.
5. **R-10, cost.** 3 attempts × 3 h × 2 slots, Opus Matcher spend is not traced at all, and batcha shipped 8 against TARGET 5 (over-production).

## 3. Proposed edits

1. **P0. New `bin/preflight.sh`, run as step 0 of the runbook PROBE.**
   - **Change:** live checks only, each with a timeout:
     - grok fenced-JSON probe.
     - `agy models`, then a fenced-JSON probe down the ladder; write the winner to `runs/_index/critic_model.json`.
     - `osascript -e 'tell application "Mail" to get name of every account'` (proves the automation permission and the classifier without sending), plus an Outbox count of 0.
     - bash ≥4, git branch, lock, freshness of `search_vectors.json`.
   - **Why:** Q6. `verify_gemini_swap.sh` is 395 lines of grep on docs, so it stays green on a dead model.
   - **Verify:** rename the pinned model to a dead name; preflight must pick the next rung and log it.
   - Keep `verify_gemini_swap.sh` as a doc lint only, never as a health check.
2. **P0. `bin/email_replies.py`.**
   - **Change:**
     - (a) Parse only the text before `^## Skipped`.
     - (b) Catch `subprocess.TimeoutExpired` → exit 4 (today it raises a traceback and exits 1, which the prompt does not handle).
     - (c) Write a `runs/_index/sent/<slot_id>` marker and refuse a second send for the same slot.
     - (d) On exit 4, check Outbox/Sent before retrying, so a queued message is not sent twice.
   - **Why:** risk #4.
   - **Verify:** a fixture with a filled Quarantined section must give a count of shipped drafts only; running `--send` twice must send once.
3. **P0. Lock plus branch guard (in preflight).**
   - **Change:** take an atomic `mkdir runs/_index/.run.lock` lock holding PID and timestamp, treated as stale after 2 h; if held, exit silently with a log line. Require `git rev-parse --abbrev-ref HEAD` = `main` and a clean `git status --porcelain` for `skill/ agents/ bin/`. Otherwise run from `git worktree add <path outside iCloud> main`.
   - **Why:** R-12, R-3. A worktree outside `Mobile Documents` also removes R-2.
   - **Verify:** start a manual run during a slot; the second run must exit with no spend. Moving the working directory is a schedule change, so the operator tests it first.
4. **P0. Single source of truth: new `## UNATTENDED MODE` section in `skill/twitter-reply-orchestrate.md`, plus `agents/critic_ladder.json`.**
   - **Change:** move the self-heal rules, the ladder and the attempt and time caps into the runbook. SAVE-AND-HALT stays the interactive default; unattended mode turns HALT into resume. PROBE and 4c read the model from `critic_model.json` instead of hard-coding Neon. `SKILL.md` shrinks to "mode=unattended, TARGET=5, email command".
   - **Why:** Q1, yes. R-9.
   - **Verify:** grep `SKILL.md` for model names or fallback logic; there should be none.
5. **P0. Always-on slot log, replacing the "only on no email" rule in the `SKILL.md` email section.**
   - **Change:** every slot appends one line to `runs/_index/scheduler_log.jsonl` with `{slot, batch_ids, attempts, critic_model, shipped, emailed, reason, wall_min}`.
   - **Why:** Q2. Detection runs on the next slot's preflight:
     - It flags a missing expected slot (Mac asleep) and 2 consecutive no-email slots, then self-heals deeper (regenerate vectors, widen the window, next rung).
     - After 4 consecutive slots (2 days), it writes one line to the TiTan board or the morning digest. That is not email; where it goes is the operator's call.
   - **Verify:** delete one slot's line; the next preflight must report the gap.
6. **P1. `bin/run_traced.sh`.**
   - **Change:** add `--timeout <s>` using `perl -e 'alarm shift; exec @ARGV'`, because macOS has no `timeout`. Set `outcome=no_block` when the output has no fenced JSON.
   - **Why:** a hung grok currently blocks the slot forever, and "ok" today means only exit 0.
   - **Verify:** wrap `sleep 999` with a 5 s timeout; the call must return non-zero and the telemetry must show it.
7. **P1. Speed, runbook step 2 (Scout thread-fetch).**
   - **Change:** fetch threads with one grok call per URL, in parallel (cap 6). Start a vector's thread fetch as soon as its own scout returns, instead of waiting for the slowest scout. Re-judge only the failing draft at the critic, which batcha already did.
   - **Why:** the 513 s and 342 s calls dominate. Expected wall time is about 20 min; that estimate is untested.
   - **Verify:** compare the `wall_min` field over 4 slots.
8. **P1. Cost cap, UNATTENDED MODE section.**
   - **Change:**
     - Per slot: 2 attempts, a 75-minute hard deadline, `MAX_GROK_CALLS=20` (TARGET=5 needs about 8 scouts plus fetches).
     - Stop scouting new vectors once TARGET plus 1 targets are bound.
     - Per day: 4 attempts in total.
     - Log Claude sub-agent tokens through `trace.sh` (the Agent tool returns them); today Matcher, Drafter and Producer are untraced.
     - Append slot totals to `runs/_index/spend.jsonl`; preflight skips deep self-heal if the trailing 24 h is over the cap.
   - **Why:** Q4.
   - I can't give a dollar figure; grok and agy pricing is not in the files. Cap on calls and time until real spend data exists.
9. **P1. Wake for the 18:00 slot.** The operator adds a 17:50 wake with `pmset`/launchd himself (system setting). This covers R-1.
10. **P2. Q3, 24/7 host: not now.**
    - **Why:** it needs grok and agy auth on a server, plus iCloud SMTP with an app-specific password, which is a new sender path to re-test against I-8.
    - **Revisit:** after about 14 logged slots, if missed slots caused by the Mac (seen in the slot log) are over 10%.

## 4. What NOT to change
- The cross-family critic, the calibration probes, and "never ship from an uncalibrated critic".
- Mail.app iCloud → iCloud delivery (I-8 is settled). Do not go back to Gmail.
- The email script refusing to send when there are no drafts or the batch is held. Keep exit 3 silent.
- The file-based re-entrant stages (`HALT.json` with `next_stage`). Self-heal should resume, not restart.
- Gate thresholds and the critic rubric. Do not loosen them to raise yield; Q-3 and Q-4 are a separate review.
- Do not add any status, error or digest email, even a "weekly health" one.
- Do not invert more doc-grep checks and call that verification.

Files read: `SCHEDULED_RUNS_ISSUES.md`, `skill/twitter-reply-orchestrate.md`, `bin/email_replies.py`, `bin/run_traced.sh`, `bin/verify_gemini_swap.sh`, `AGENTS_CONSTRAINTS.md`, `/Users/titane0/.claude/scheduled-tasks/twitter-reply-pipeline/SKILL.md`, `runs/2026-11-22_batcha/_telemetry.jsonl`, `runs/2026-11-22_batcha/batch_report.md`, `runs/2026-11-22_batcha/replies_to_post.md`. Paths are relative to `/Users/titane0/Library/Mobile Documents/iCloud~md~obsidian/Documents/Mission_Control/05_Content/accounts/ogrizkov/channels/twitter/` except `SKILL.md`. No files were edited.

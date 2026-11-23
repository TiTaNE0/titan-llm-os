# Position: Gemini

## D1 Volume
- Decision: Start at moderate daily volume, update `strategy.md` to separate original posts (2–4/week) from replies, and ramp only on measured safety and conversion.
- Numbers: **4–6 replies/day** across two runs (**target 2–3/run**, **ceiling 4/run**, **daily ceiling 8**, **floor 0**). Hold for 2 weeks; ramp to 8–10/day in week 3 only if D9 gates pass.
- Evidence: Evidence is too thin to prove either 3/run or 15/day. Strength-A X code shows `Num Replies Last 24 Hours` feeds the reply-spam scorer `[SOURCE: https://github.com/xai-org/x-algorithm/blob/main/grox/core/lm/thread.py, 2026-10-08]`, and policy bans unquantified "high-volume unsolicited replies" `[SOURCE: https://help.x.com/en/rules-and-policies/authenticity, 2025-04]` under a 200/day unverified cap `[SOURCE: https://help.x.com/en/rules-and-policies/x-limits, undated]`. On his 15-reply day, all 15 replies got ≤8 views (median 3, confounded by stale parents) `[ACCOUNT DATA: Q2b]`. Starting at 4–6/day is `[MODEL OPINION]`: enough sample (~60–80 replies/14 days) to learn without exhausting 31 project facts or triggering spam heuristics.
- Confidence: low
- Would change my mind: A 2-week test at 4–6/day followed by 2 weeks at 8–10/day showing clean `under_the_hood` status and non-declining profile visits per reply.

## D2 Reply types
- Decision: Split into **Deep** (real project evidence) and **Sharp Clean** (no vault fact, adds a non-obvious technical angle or specific question), and ban "obvious" replies.
- Numbers: **1–2 Deep + 1–2 Sharp Clean per run** (~45% Deep / 55% Clean; ceiling 2 Deep/run). **0 "obvious" replies.**
- Evidence: X enforces `llm_slop_post` and `llm_slop_user` `[SOURCE: https://github.com/xai-org/x-algorithm/blob/main/abuse-enforcement-service/service-lib/rules/enforcement_user.yaml, 2026-11-21]`, purged 42,000 accounts "spamming thought-leadership slop about artificial intelligence" `[SOURCE: https://x.com/nikitabier/status/2081111047340167485, 2026-07-25]`, and uses reply dislikes for ranking `[SOURCE: https://x.com/nikitabier/status/2034293888350114233, 2026-03-18]`. Practitioner exports show generic replies yield ~1 follow per 173 replies `[SOURCE: https://talkfirstplaybook.com/guides/reply-strategy-x, 2026-10-08]`. Separating Sharp Clean solves the operator's complaint: the 31 facts only fire on true fits (no stretching), while Clean replies interest strangers by naming an edge case, counterexample, or failure mode from the OP's post `[MODEL OPINION]`.
- Confidence: medium
- Would change my mind: 2-week log showing Sharp Clean produces <0.5x the profile visits or author replies of Deep (or vice versa).

## D3 Targets
- Decision: Prioritize fresh, uncrowded mid/small builder threads (1k–100k) and nested sub-threads; deprioritize >250k mega-accounts.
- Numbers: **80%** to 1k–100k accounts (age ≤6h, ≤40 existing replies); **≤20% (max 1/run)** to >100k accounts, only if <2h old or as a nested reply on a sub-thread with ≤20 replies.
- Evidence: Strength-A code switches to Grok scoring above 250k (`GROK_GEMMA_FOLLOWER_SPLIT = 250_000`) and runs coordinated-spam checks ≥180k `[SOURCE: https://github.com/xai-org/x-algorithm/blob/main/grox/flows/reply_spam/task_filter.py, 2026-10-08]`. Replies don't enter non-followers' For You feed `[SOURCE: https://github.com/xai-org/x-algorithm/blob/main/home-mixer/filters/oon_retweet_reply_filter.rs, 2026-11-21]`, but an author reply promotes you to post-page Tier 1 `[SOURCE: https://help.x.com/en/resources/recommender-systems/conversations-recommendations, undated]` and mutual follows earn +15 on original posts `[SOURCE: https://github.com/xai-org/x-algorithm/blob/main/docs/BIDIRECTIONAL_BOOST_CHANGE.md, 2026-07]`. Live data: his 4 replies to >500k accounts got 3–22 views and 0 author replies; posts with ≤20 replies averaged median 16 views (best 4,161 on a 5-reply nested thread) vs 6 views on 101–300 replies `[ACCOUNT DATA: Q2b, Q4]`.
- Confidence: high
- Would change my mind: 2-week split test where >250k <2h replies outperform 1k–100k replies on profile visits per reply.

## D4 Timing
- Decision: Schedule both runs to hit US East morning and midday after accounting for ~30 min pipeline runtime plus phone-posting lag.
- Numbers: **Run 1: 15:00 Israel** (email ~15:30 IL / 08:30 EST). **Run 2: 19:30 Israel** (email ~20:00 IL / 13:00 EST). Discovery age cap ≤4h so manual replies land ≤6h old.
- Evidence: No Strength-A/B timing data exists for AI replies (Buffer's 9–11 a.m. local study excludes replies and developers `[SOURCE: https://buffer.com/resources/best-time-to-post-on-twitter/, 2026-03-13]`). Account data shows 3–6h post age yielded median 42 views (n=11) vs 4 views over 24h (n=3) `[ACCOUNT DATA: Q2b]`, while the 08:00 IL run caught 27–44h stale posts. Exact slots are `[MODEL OPINION]`.
- Confidence: low
- Would change my mind: 2-week comparison of Run 1 vs Run 2 median impressions and author-reply rate bucketed by post age at send.

## D5 Disclosure
- Decision: Never mention the pipeline, agents, or AI drafting in replies.
- Numbers: **0 public mentions** of AI reply drafting.
- Evidence: X automation rules cover actions "without a person actively performing them" `[SOURCE: https://help.x.com/en/rules-and-policies/x-automation, 2026-04]`, and EU AI Act Art. 50 exempts human-reviewed text `[SOURCE: https://artificialintelligenceact.eu/article/50/, 2026-08-02]`, so disclosure is not required. Yet X suspended 42,000 automated-reply accounts `[SOURCE: https://x.com/nikitabier/status/2080747924380856519, 2026-07-24]`, blocked an account demanding "human-written content" `[SOURCE: https://x.com/nikitabier/status/2082005176945426787, 2026-07-28]`, and developers share 3,728-account AI-replier blocklists `[SOURCE: https://x.com/levelsio/status/2123388955143893122, 2026-11-19]`. Disclosing invites blocks (-31.2) and reports (-234) `[SOURCE: https://github.com/xai-org/x-algorithm/blob/main/home-mixer/params/param.rs, 2026-11-20]` for zero upside `[MODEL OPINION]`.
- Confidence: high
- Would change my mind: An explicit X policy requiring disclosure of human-posted AI drafts.

## D6 Paste and duplication risk
- Decision: Stop clipboard-pasting replies under **all** account sizes and enforce fact/template cooldowns.
- Numbers: **0 verbatim pastes** (retype or manually edit every 15–35 word reply on phone); **21-day cooldown** per vault fact; **0 repeated phrasing skeletons** within 7 days.
- Evidence: Strength-A code contradicts Grok's claim that pasting is safe on medium accounts: `Reply Was Pasted: {post.is_pasted}` is passed directly to the scorer on all replies `[SOURCE: https://github.com/xai-org/x-algorithm/blob/main/grox/core/lm/thread.py, 2026-10-08]`. Duplicate clusters trigger `COPYPASTA_SPAM` `[SOURCE: https://github.com/xai-org/x-algorithm/blob/main/botmaker-rules/scarecrow/bot/BBQDuplicateTextRepliesProd.bot, 2026-11-21]`, and policy forbids "substantially similar posts" `[SOURCE: https://help.x.com/en/rules-and-policies/x-automation, 2026-04]`. On 11-01, 5 verbatim-pasted pipeline drafts got 2–6 views `[ACCOUNT DATA: Q3]`. Exact 21-day cooldown is `[MODEL OPINION]`.
- Confidence: high
- Would change my mind: A 2-week A/B test (typed vs pasted on matched threads) showing equal views and zero `RiskyHighVizReply` labels.

## D7 Empty or thin runs
- Decision: Never lower the quality bar to meet a quota; widen discovery once if thin, rely on Sharp Clean to prevent starvation, and allow rare empty runs.
- Numbers: **Hard floor 0**, **target 2–3/run**. If <2 pass, execute **1 widened discovery pass** (broader builder queries and nested sub-threads, keeping freshness ≤6h and full gate). If still 0, log silently and send no email.
- Evidence: Quota pressure (`TARGET=5`) caused batcha's stretched replies; negative actions carry -31 to -234 weights `[SOURCE: https://github.com/xai-org/x-algorithm/blob/main/home-mixer/params/param.rs, 2026-11-20]`, making filler worse than silence. Widening discovery + Sharp Clean keeps empty runs rare without shipping slop `[MODEL OPINION]`.
- Confidence: medium
- Would change my mind: >20% empty runs over 2 weeks after widening discovery (would indicate broken scout queries or over-tight gate).

## D8 Quality gate
- Decision: Enforce a strict two-lane gate that rejects anything forced, obvious, or AI-voiced — replacing Grok's "obvious is fine" with "adds one concrete turn."
- Numbers: **4 hard reject rules (0 exceptions; drop target on rule 2, no redraft):**
  1. *Obviousness/Deletion:* Reject if it makes sense with the OP deleted, or only agrees/paraphrases without adding a failure mode, counterexample, boundary condition, or specific question tied to the OP's claim.
  2. *Forced anchor:* Reject and drop if a Deep reply drags in an unrelated project fact or internal jargon ("E1-E5", "vault", "injection").
  3. *AI tells:* Reject aphorisms, subjectless changelog lines (must use "I/my"), engagement-bait endings, and planted ESL typos.
  4. *Stale/Crowded:* Reject >6h posts or >40 replies (outside the D3 20% exception).
- Evidence: Grok scores replies 0–3 `[SOURCE: https://github.com/xai-org/x-algorithm/blob/main/grox/flows/reply_spam/classifier_reply_ranking.py, 2026-10-08]`, downranks engagement bait `[SOURCE: https://x.com/nikitabier/status/2034668641304895664, 2026-03-19]`, and flags `llm_slop_post` `[SOURCE: https://github.com/xai-org/x-algorithm/blob/main/abuse-enforcement-service/service-lib/rules/enforcement_user.yaml, 2026-11-21]`. Specific rubric is `[MODEL OPINION]` directly addressing the operator's "not interesting / stretched" verdict.
- Confidence: medium
- Would change my mind: Operator rejecting >30% of emailed drafts as boring or forced in weeks 1–2.

## D9 Measurement
- Decision: Run 14-day review cycles tracking funnel conversion and account health, tying volume strictly to measured gains.
- Numbers: **14-day window (≥50 posted replies)**. Log per reply: Deep/Clean, target tier, post age, impressions, **author reply**, plus weekly X Analytics **profile visits**, **net follows**, and `https://x.com/i/jf/under_the_hood` status. **Scale rules `[MODEL OPINION]`:**
  - *Raise to 8–10/day:* 0 labels, author-reply rate ≥10% (baseline 1.9%), median views ≥30 (baseline 10), operator draft acceptance ≥70%.
  - *Cut to 2–3/day (or 7d pause):* Any visibility label appears, or 5-day median views <10.
- Evidence: `under_the_hood` exposes limiting labels `[SOURCE: https://github.com/xai-org/x-algorithm/blob/main/README.md, 2026-08-13]`; replies convert via profile visits `[SOURCE: https://scout7.ai/content/x-reply-strategy, 2026-09-29]`; baseline is 10 median views and 1.9% author replies `[ACCOUNT DATA: Q2b]`. Thresholds are `[MODEL OPINION]`.
- Confidence: high
- Would change my mind: X Analytics failing to attribute profile visits cleanly (fallback: weekly aggregate profile visits + follows + per-reply author replies).

## D10 Account risk
- Decision: Treat account risk as high — at 58 followers, Blue verification gives zero protection against X's spam and AI-slop labels.
- Numbers: **0% exemption** below PageRank 66; **30-day `RiskyHighVizReply`** on `llm_slop_post`; **7-day `SpamHighRecall`** (kills notifications and For You) on `llm_slop_user`.
- Evidence: Only grey badges and PageRank ≥66 are exempt from `RiskyHighVizReply` `[SOURCE: https://github.com/xai-org/x-algorithm/blob/main/grox/flows/reply_spam/task_write.py, 2026-10-08]`; `llm_slop_user` triggers `SpamHighRecall` `[SOURCE: https://github.com/xai-org/x-algorithm/blob/main/abuse-enforcement-service/service-lib/rules/enforcement_user.yaml, 2026-11-21]`; AI thought-leadership is X's primary purge target `[SOURCE: https://x.com/nikitabier/status/2081111047340167485, 2026-07-25]`. Account appears clean today (no search ban; recent replies got 95–172 views) `[ACCOUNT DATA: Q1, Q2b]`, but must be verified on `under_the_hood` immediately.
- Confidence: high
- Would change my mind: Finding existing labels on `under_the_hood` today (would require an immediate 7-day pause and 2/day restart).

## Biggest weakness in my own position
Two weaknesses: first, my 4–6/day starting point and 45/55 Deep/Clean split are `[MODEL OPINION]` compromises, and requiring manual retyping adds phone friction that could reduce daily posting compliance. Second, replies only buy profile visits; his pinned post has 9 views and he posted 5 originals in 60 days `[ACCOUNT DATA: Q1, Q2b]`. Without stronger original posts and a sharper pinned post to convert visitors, even great replies will leak follows `[MODEL OPINION]`.

## What I expect the other seats to get wrong
Grok will defend high volume (10–15/day), "obvious" filler, pasting on medium accounts, and >250k AI lab targets — directly contradicted by X's own code (`GROK_GEMMA_FOLLOWER_SPLIT = 250_000`, `is_pasted`, `llm_slop_user`) and @ogrizkov's live numbers (3–22 views on >500k accounts). Claude will over-index on the 31-fact vault and defend a ≤3/run cap with frequent empty runs, starving the account of learning velocity and ignoring that disciplined Sharp Clean replies solve scarcity without forced stretches.

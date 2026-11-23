# Position: Claude

`repo/`, `help/`: URL short forms from E1. "Thread reply" = Grok's "Clean", stricter bar.

## D1 Volume
- Decision: Start at 8 posted replies a day, earn 15. Neither "3 per run" nor "15 now" has evidence.
- Numbers: 2 runs. Weeks 1-2: target 4 per run, ceiling 6. Week 3: ceiling 8 (15 a day) if the D9 rule passes. No floors. `strategy.md`: these numbers replace "2-4 pieces per week"; "max 1 reply per author per day" replaces "avoid looking like a reply guy".
- Evidence: Follows per ordinary reply: 1 per 173 [SOURCE: talkfirstplaybook.com/guides/reply-strategy-x, 8 Oct 2026], 1 per 53 [SOURCE: scout7.ai/content/x-reply-strategy, 29 Sep 2026]. So 15 generic replies a day is 3-8 followers a month. His 15-reply day: median 3 views against 42 on 1-2-reply days (confounded: stale targets) [ACCOUNT DATA: E3 Q2b]. 8 a day gives ~110 replies in 14 days to compare types and tiers; a cap of 3 with empty runs gives about half [MODEL OPINION].
- Confidence: low on numbers, medium on ramping.
- Would change my mind: a visibility label; D9 thresholds met early.

## D2 Reply types
- Decision: Two types, one bar: the reply adds what this thread lacks. "Obvious but relevant" is rejected.
- Numbers: Deep (a project fact answers, contradicts or measures the author's claim): about 2 a day (31 facts, 14-day cooldown). Thread reply (no project fact): the rest. No quota.
- Evidence: A Thread reply uses only the post: a hole in its claim, a boundary case, or a question the author can answer in one line. Examples [MODEL OPINION]. @nateherk: "Each compaction is itself a full pass over the window. Over a few hours at 400k, did total usage go down, or only usage per turn?" @martynov014: "A hook on rm -rf checks the string, not the effect. find . -delete does the same and passes. Is the answer a sandbox?" His 54 replies: 1 author answer [ACCOUNT DATA: E3 Q2b].
- Confidence: medium.
- Would change my mind: after 25 each, Thread replies get fewer author answers than his own casual replies.

## D3 Targets
- Decision: Live mid-size threads first. Lab accounts are a small measured experiment.
- Numbers: Author 500-250k followers; post under 6 h old; under 50 replies; the author answers replies or asks a question. Over 250k: max 2 a day, post under 2 h old.
- Evidence: Under @Google, @GoogleDeepMind, @claudeai, @GeminiApp his replies got 12, 10, 3, 22 views on posts with 1.2M-7.5M views [ACCOUNT DATA: E3 Q4]. Above 250k a Grok model scores each reply, seeing follower count and the paste flag [SOURCE: repo/grox/core/lm/thread.py, 21 Nov 2026]. The author's answer is the named rank signal [SOURCE: help/using-x/mentions-and-replies, undated]. Threads with 20 or fewer replies: median 16 views; pipeline replies at 19-52 h: 2-6 views [ACCOUNT DATA: E3 Q2b, Q3].
- Confidence: medium (labs: n=4).
- Would change my mind: 20 lab replies beating the mid-tier median.

## D4 Timing
- Decision: 15:00 and 20:00 Israel. Post within 2 h of the email or skip.
- Numbers: 15:00 = 08:00 US East: European day and early East posts, not "fresh US". 20:00 = 13:00 East, 10:00 Pacific: the main US slot.
- Evidence: [MODEL OPINION]; no latency data exists (E1, E2). His replies on posts 3-6 h old: median 42 views (n=11); over 24 h: 4 (n=3) [ACCOUNT DATA: E3 Q2b].
- Confidence: low.
- Would change my mind: views per slot after 14 days.

## D5 Disclosure
- Decision: Replies never say they were AI-drafted. His agents and pipelines stay allowed as subject matter. Never deny it if asked.
- Numbers: 0 mentions. He edits and posts each reply.
- Evidence: Automation means actions "without a person actively performing them"; no rule covers an AI draft posted by hand [SOURCE: help/rules-and-policies/x-automation, April 2026]. But X blocked an account for AI-written posts [SOURCE: x.com/nikitabier/status/2082005176945426787, 28 Jul 2026]. Grok's "do not mention agents" would delete his positioning [MODEL OPINION].
- Confidence: medium.
- Would change my mind: X staff ruling on hand-posted drafts.

## D6 Paste and duplication risk
- Decision: Rewording does not clear a paste flag; typing does.
- Numbers: Over 250k he types the reply (under 20 words). Elsewhere: paste, half of the short ones typed as a test. No 5-word run shared with a reply of the last 30 days.
- Evidence: "Reply Was Pasted" reaches the scorer [SOURCE: repo/grox/core/lm/thread.py, 21 Nov 2026]. Duplicate-text clusters get `COPYPASTA_SPAM` [SOURCE: repo/botmaker-rules/scarecrow/bot/BBQDuplicateTextRepliesProd.bot, 21 Nov 2026]. What counts as pasted is unpublished.
- Confidence: low.
- Would change my mind: typed against pasted views, 30 each.

## D7 Empty or thin runs
- Decision: Widen the search, keep the bar, deliver what passes. An empty run is a discovery defect, not a normal outcome.
- Numbers: Under 3 passing: add query vectors, extend age to 12 h. No floor. Goal: 3 or more in 9 of 10 runs.
- Evidence: [MODEL OPINION]. Thread replies end the dependence on 31 facts; he posted 0 of the 8 padded drafts [ACCOUNT DATA: E3 Q3].
- Confidence: medium.
- Would change my mind: over 1 empty run in 10.

## D8 Quality gate
- Decision: Judge what the reply does in the thread, not whether it carries a project.
- Numbers: Reject if: (1) it reads fine with the post deleted; (2) without project nouns and numbers it restates the post or a captured reply; (3) it cannot quote the line it answers; (4) the author could not confirm, deny or answer it in one line; (5) a project fact does not answer, contradict or measure the claim (drop, no redraft); (6) aphorism, internal label, planted typo; (7) experience not in the authority file. Never reject for no project fact.
- Evidence: [MODEL OPINION]. Grok is right to drop the project requirement. "Not interesting" and "stretched" are rules 1-5; "obvious" fails rule 2. Rule 4 aims at the author's answer.
- Confidence: medium.
- Would change my mind: he posts under 70% of them.

## D9 Measurement
- Decision: Measure posted replies at 48 h. Metric one: the share of delivered replies he posts.
- Numbers: Per reply: views, author answered, type, tier (under 5k, 5-50k, 50-250k, over 250k), post age, typed or pasted, slot. Weekly, his X analytics: profile visits, follows. After 14 days raise to 15 if posted share ≥70%, author answer ≥8%, median views ≥20, no label. Cut to 4 a day if median views fall under 8. Stop a type or tier after 25 replies with 0 author answers.
- Evidence: Baseline: median 10 views, author answer 1.9%, 58 followers [ACCOUNT DATA: E3 Q1, Q2b]. Thresholds are [MODEL OPINION].
- Confidence: low on thresholds.
- Would change my mind: views not tracking profile visits.

## D10 Account risk
- Decision: The main risk is being classed as AI slop, not the count of 8-15.
- Numbers: Check x.com/i/jf/under_the_hood weekly. Max 6 replies an hour. A label, or median views halving: pause 7 days.
- Evidence: `llm_slop_user` labels an account `SpamHighRecall` for 7 days [SOURCE: repo/abuse-enforcement-service/service-lib/rules/enforcement_user.yaml, 21 Nov 2026]. Its trigger is unpublished.
- Confidence: low.
- Would change my mind: a label.

## Biggest weakness in my own position
Every threshold is my judgement. At 1 follow per 53-173 replies, two weeks add few followers: replies earn profile visits, and the profile (originals: 3-38 views) must convert them. My plan does not fix that. His eight best replies were casual and hand-written; my gate may reject what works.

## What I expect the other seats to get wrong
Grok: lab accounts as reach; 14:00 Israel as "fresh US" (07:00 East); rewording as a paste fix. Gemini: vendor rules as data. Both: counting drafts, when 0 of the last 8 were posted.

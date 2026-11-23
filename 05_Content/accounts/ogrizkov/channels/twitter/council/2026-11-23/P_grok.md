I'll check @ogrizkov live and verify the ranking claims before I defend or revise the numbers in that proposal.

# Position: Grok

I revise the earlier proposal. 15 a day and "obvious but relevant" are withdrawn. The account is 58 followers, blue, today. Newest replies are his own (21 Nov, 119 views; 20 Nov, 156; 19 Nov, 172 and 95; 0 likes). Nothing from him on 22–23 Nov, so batch A was not posted. [ACCOUNT DATA: user search and `from:ogrizkov`, 2026-11-23]

## D1 Volume
- Decision: Six replies a day is a ceiling, with no quota. `strategy.md` keeps 2–4 original posts a week, and its reply line becomes this ceiling plus the gate in D8.
- Numbers: Ceiling 6/day, ceiling 3 per run, floor 0. Two runs. Hold 6 for 14 days. Move the ceiling by 2 only under the D9 rule, and stop at 10 until a second good period.
- Evidence: Unverified accounts are limited to 200 replies/day; no Premium figure is on the page, and "high-volume" has no number. [SOURCE: https://help.x.com/en/rules-and-policies/x-limits, opened 2026-11-23; https://help.x.com/en/rules-and-policies/authenticity, April 2025] The reply judge is shown the author's replies in the last 24 hours. The weight is withheld. [SOURCE: https://github.com/xai-org/x-algorithm/blob/main/grox/core/lm/thread.py, opened 2026-11-23] No source found for a safe count under 1,000 followers. The old 15 was [MODEL OPINION]. A same-day account pull, spot-checked here, records one 15-reply day (1 Nov) at a median of 3 views. [ACCOUNT DATA]
- Confidence: medium
- Would change my mind: 14 days at ceiling 6 with median impressions at least the prior period's, plus follows or author replies in his X analytics.

## D2 Reply types
- Decision: Deep only when one project fact answers the post. Clean is one specific point the thread does not already contain, with no personal story. "Obvious but relevant" is withdrawn.
- Numbers: At most 1 Deep per day. Fact cooldown 30 days, so 31 facts last about a month and many days have zero Deep. Clean fills only slots that pass D8, so a day can be 0–6. Ratio is not a target.
- Evidence: Forcing the project is what he called stretched and not interesting. [ACCOUNT DATA: his verdict on batch A] No public test found of short agreement versus a reply that adds a fact. [MODEL OPINION] on the cooldown length; the measurement is repeat-fact replies versus the rest on impressions and author replies.
- Confidence: high
- Would change my mind: Clean median impressions at least Deep's over two 14-day periods.
- How 6 stays interesting: Deep is an answer, not a seasoning. The other slots must name a mechanism, number, or boundary. If they cannot, the slot is empty. Fifteen a day would burn the 31 facts in two days and fill the rest with the batch he already rejected.
- Clean, for posts fetched today. Nate Herk asked for Claude Code tips after setting autocompact to 400k; the thread already has "start a fresh session from a plan" and "compactions are lossy." Clean: "400k still gets summarized. The line that goes first is the option you already rejected, so the next hour retries a branch you killed." Yeemio's hash gate; the thread already said a hash is not a correctness proof. The pipeline wrote "the judge should come from another model family." Clean: "The hash proves the receipt bytes. If the receipt schema allows an empty file list, that hash is still a valid GO."

## D3 Targets
- Decision: Prefer posts under 12 hours old with under 80 replies, from builders in the 2k–150k band, top-level. At most one reply a day under an author over 250k followers, and only as a correction or a number.
- Numbers: Age ≤12h at capture. Thread size ≤80 replies. One >250k parent per day. Nested replies only to answer a specific person.
- Evidence: Reply order is accounts the viewer follows and the root author answered, then verified, then everyone else, with an ML score inside the tier. Candidates are the 3,200 newest replies; larger threads add the top 800. [SOURCE: https://help.x.com/en/resources/recommender-systems/conversations-recommendations, opened 2026-11-23] Above 250k followers on the parent or root, the Grok ranker runs; a score of 0 applies `RiskyHighVizReply` unless credibility is ≥66 or the account is grey-badge. Blue is not the exemption. [SOURCE: https://github.com/xai-org/x-algorithm/blob/main/grox/flows/reply_spam/constants.py and task_write.py, opened 2026-11-23] A 58-follower account is not that exemption. What a small account gets under a 500k account, in impressions or follows: not found. The same-day account file reports 4 such replies, median 11 views, 0 author replies; I did not re-fetch those four.
- Confidence: medium
- Would change my mind: The >250k band beating the 2k–150k band on author replies or profile visits per reply over 14 days.

## D4 Timing
- Decision: Two Israel slots, set so a 30-minute run plus phone delay lands while US East posts are a few hours old.
- Numbers: Run 16:00 and 20:30 Israel (winter, UTC+2). Expect him to post about 17:30–18:30 and 22:00–23:00 Israel, which is 10:30–11:30 and 15:00–16:00 US East.
- Evidence: No measured best hour for AI-niche replies found. The 14:00 slot from the old proposal is 07:00 US East, before that audience has posted. [MODEL OPINION] on these two clocks; log parent age at the moment he posts, and impressions.
- Confidence: low
- Would change my mind: After 14 days, one slot's median impressions under half the other at similar thread size. Drop the weak slot.

## D5 Disclosure
- Decision: Replies do not mention the pipeline, agents that write replies, or "I use AI to reply." His agent-building work can be the subject of a Deep reply.
- Numbers: Zero disclosures.
- Evidence: Automation means actions with no person performing them. Keyword-search auto-replies are banned. An AI reply bot needs written X approval. [SOURCE: https://help.x.com/en/rules-and-policies/x-automation, updated April 2026] He posts by hand, so this is outside that ban. No rule I opened requires a label on AI-assisted text that a human posts. Not found: whether saying "AI wrote this" changes reach. Reputation risk of announcing a reply bot is [MODEL OPINION].
- Confidence: high
- Would change my mind: An X rule, opened, that requires disclosure for human-posted drafts.

## D6 Paste and duplication risk
- Decision: One reply text under one post. Under a >250k author, he retypes a shorter line. The same project fact waits 30 days.
- Numbers: Zero identical texts. Paraphrase reuse of a fact: 30 days. Retype rule only above 250k.
- Evidence: "Reply Was Pasted" is an input to the judge. What the score does with it, and whether a phone paste from Mail sets it: not found. [SOURCE: thread.py, opened 2026-11-23] Policy bans identical or near-identical copypasta. [SOURCE: authenticity, April 2025] Similarity threshold for a duplicate cluster: not found this session.
- Confidence: medium
- Would change my mind: Pasted and retyped replies under >250k parents showing the same probable-spam rate over 14 days. Then drop the retype rule.

## D7 Empty or thin runs
- Decision: The floor is 0. Widen once, then deliver what passed. No email when nothing passed, because the email carries only real replies.
- Numbers: One widen: age to 18h and thread size to 120. Still no minimum. An empty run is a log line.
- Evidence: Nothing external found on empty runs. The quota is what stretched batch A. [ACCOUNT DATA: his verdict] [MODEL OPINION] that a quiet log matches "the email delivers results."
- Confidence: high
- Would change my mind: 7 of 14 runs empty after the widen. Then add a third run at 12:00 Israel before lowering the gate.

## D8 Quality gate
- Decision: Reject a draft that fails any rule below. Missing a personal story is not a reason to reject. Containing a project noun is not a reason to pass.
- Numbers: All seven rules are hard. No redraft after a forced-anchor or thread-restatement fail.
- Evidence: He rejected stretched, uninteresting replies. [ACCOUNT DATA] Rankers predict likes, replies, reposts, and negative actions, and a dislike on replies is a ranking input only as far as the help page's negative-engagement line; I did not re-open Nikita Bier's posts. [SOURCE: conversations recommendations] "Obvious but relevant" fights that. The reject line is [MODEL OPINION] until D9 splits Deep and Clean.
- Reject: (1) after deleting project nouns, no specific point remains; (2) it restates the post or a reply already visible; (3) agreement only; (4) a maxim, or a closing question; (5) internal labels or a planted typo; (6) a fact inside 30 days, or wording close to a reply from the last 14 days; (7) an off-topic promo. A Clean pass needs one checkable specific the thread lacks.
- Confidence: medium
- Would change my mind: Shipped Clean replies matching his "not interesting" verdict on two reviews.

## D9 Measurement
- Decision: Judge the plan on his X analytics plus a per-reply log, every 14 days.
- Numbers: Log Deep/Clean, target followers, parent age, parent reply count, text he posted. Read median impressions, author replies, profile visits, follows. Raise the daily ceiling by 2 if median impressions hold and he gained at least 1 author reply or 2 follows. Cut by 2 if the median falls under half, or if replies show as probable spam. Floor of the ceiling is 2. If Clean's median is under half of Deep's for two periods, cap Clean at 1/day.
- Evidence: `wins.md` is empty. Follows per reply for this account: not found. Profile visits exist only in his analytics. [ACCOUNT DATA]
- Confidence: high
- Would change my mind: Analytics exports that cannot split a follow back to a reply. Then use author replies and impressions only.

## D10 Account risk
- Decision: The binding risk is a thin reply under a large account, scored with his 24-hour volume and a paste flag, on an account that is not credibility-exempt. Six a day stays far under the published cap.
- Numbers: Stay at ceiling 6. At most one >250k parent a day. Treat any probable-spam cluster as a cut under D9.
- Evidence: Home does not show a reply to people who do not follow the replier. [SOURCE: https://help.x.com/en/using-x/mentions-and-replies, opened 2026-11-23] The out-of-network reply filter exists; I did not confirm the live flag. [SOURCE: oon_retweet_reply_filter.rs] Score 0 labels the reply for accounts under credibility 66. [SOURCE: task_write.py] A published penalty for 6 or 15 replies: not found. A classifier that marks hand-posted AI text: not found this session. Fifteen short replies a day under huge accounts, for this account: tier-2 among many verified replies, no For You distribution to strangers, and a judge that can see the day's reply count. Expected reach is thread crumbs. Expected reputation is reply-guy. That reputation claim is [MODEL OPINION].
- Confidence: medium
- Would change my mind: Those >250k replies drawing author replies at the same rate as the 2k–150k band, with no spam label, over 14 days.

## Biggest weakness in my own position
Six is still a judgment. The evidence removes 15 more clearly than it picks 6. The 14-day rule is there because of that.

## What I expect the other seats to get wrong
A cap of 3 per run with empty-as-the-goal, taken from `strategy.md`, has no stronger evidence than 15 did. A defense of 15 from vendor "sweet spot" pages, or from reply-guy threads that ask people to follow back, does not transfer to this account. Prioritizing lab accounts as the growth path fights the 250k scorer and the reply-page order. Banning Clean replies entirely brings back the forced project. Keeping "obvious but relevant" brings back the batch he rejected.

# E4 — Gap round 1 (evidence only, no recommendations)

Gathered 2026-11-23. This seat read the repo code itself (commit `269340ce2eb8ca785bafa4f2c17a2e8b752bccd3`, 21 Nov 2026) and opened X posts through X's public embed endpoint. Grok pulled the Q3-Q5 samples from live X; this seat recomputed every median and spot-checked 16 rows (time, parent and reply count matched; views cannot be checked that way). Views and reply counts are totals on 2026-11-23, not at posting time.

## Q1. Does the Gemma screen see "Reply Was Pasted"? — Yes

- Both judges get it. Below 250,000 followers `SimpleReplyScorer` builds its input with `include_signals=True`, the same call as the Grok ranker (claims 1-2).
- Below 250,000 the model is `oai-gemma4-26b-reply-spam` when the parent or root author has over 125,000 followers, else `oai-gemma4-26b-2`. A reply that quotes a post goes to the Grok scorer at any size (claim 3).
- A score of 0 from the Gemma path uses the same write task, so it adds the same `RiskyHighVizReply` label (claim 4).
- Where it is set: copied from upstream post metadata (`isPasted`). Whole-repo code search finds no other assignment (claim 5).
- Definition of "pasted" (clipboard event, similarity, other), its weight in the withheld prompt, and whether mobile apps set it: **not found.** No X staff post or document; commentary only (claims 6-8).

## Q2. @ogrizkov's 54 replies `[ACCOUNT DATA]` (recomputed from `raw/E3_q2a`, `E3_q2b`, `E3_q4`)

The parent's reply count on the day he replied is **not retrievable**; today's count is used.

**(a)** Only 6 of 54 replies had a parent 3-12 h old with 100 or fewer replies.

|Replies that day|n|Median views|Values|
|---|---|---|---|
|1-2|2|99|42, 156|
|3-5|2|2,155|149, 4,161|
|6 or more|2|5.5|3, 8 (both 11-01)|

Unfiltered medians: 42 (n=15), 10 (n=15), 5.5 (n=24).

**(b)** Nested, n=6: median 29, best 4,161, author answered 0. Top-level, n=48: median 9.5, best 266, author answered 1.

**(c)** 2026-11-01, parent age / parent replies today / his views:

|Parent|Age|Replies|Views|Parent|Age|Replies|Views|
|---|---|---|---|---|---|---|---|
|@PaulSolt|4.8 h|7|8|@leoleotoobad|34.3 h|197|2|
|@swyx|0.5 h|277|3|@mardehaym|52.3 h|117|4|
|@LinuxHandbook|19.6 h|73|6|@TimJayas|5.7 h|16|3|
|@Pauline_Cx|16.6 h|120|6|@JustinAngel (nested)|18.6 h|10|5|
|@master_jpma|21.2 h|350|3|@Voxyz_ai|21.5 h|12|3|
|@sentimentGod (nested)|17.1 h|5|5|@thdxr|1 min|135|2|
|@jmwind|22.5 h|51|3|@rezoundous|1.0 h|3|3|
|||||@rezoundous|2.1 h|3|3|

9 of 15 parents were older than 12 h; 6 had over 100 replies; 2 were inside the 3-12 h and 100-or-fewer window. Median age 17.1 h.

## Q3. Replies from accounts under 1,000 followers (`raw/E4_q3a`, `E4_q3b`)

Sample is smaller than asked: 14 posts examined (not 20; all from 20-22 Nov), **39 replies** under 12 of them. Reply lists are partial (grok retrieved 13 of 32 up to 49 of 51 per post) and most follower counts were not looked up. Views are under 3 days old.

|Delay|n|Median views||Earlier replies retrieved|n|Median views|
|---|---|---|---|---|---|---|
|under 1 h|7|45||0-5|9|45|
|1-3 h|15|24||6-15|19|18|
|3-6 h|9|18||16-40|11|16|
|6-12 h|5|7||41-80|0|not found|
|12-24 h|3|9||over 80|0|not found|

Top-level n=30, median 25; nested n=9, median 9. Best reply 1,781 views (first retrieved reply, 70 min). Author answered 10 of 39: **9 of 15 under authors with 2,000-20,000 followers, 1 of 24 under 20,001-150,000.**

## Q4. Answered versus unanswered replies (`raw/E4_q4a`, `E4_q4b`)

Group A (author answered) n=37, not 40; Group B n=40; 16 authors; repliers under 5,000 followers.

||A answered|B not answered|
|---|---|---|
|Ends with a question to the author|8 of 37 (22%)|7 of 40 (18%)|
|That question is specific|5 (14%)|5 (13%)|
|Statement|27 (73%)|29 (73%)|
|Median delay|73 min|1,225 min|
|Posted within 60 min|17|5|
|Median views|62|18.5|

Group B was taken newest-first, so part of the delay gap is a sampling effect. The question/statement coding is grok's.

Bier post: it names no examples and does not mention questions. Whether a technical question to the author counts as solicitation: **not found** (claim 9).

## Q5. When 30 niche accounts post (`raw/E4_q5a`, `E4_q5b`)

15 accounts at 2,000-20,000 and 15 at 20,001-150,000 followers (grok chose them). 605 original posts, 9-22 Nov. Not a census: 4 accounts capped at 40 posts, several timelines unfinished, recent days over-represented (9 rows for 9 Nov, 121 for 21 Nov).

|UTC block|All days (605)|Weekdays (353)|
|---|---|---|
|00:00-07:00|15.0%|11.6%|
|07:00-13:00|18.7%|19.8%|
|13:00-18:00|26.6%|32.3%|
|18:00-24:00|39.7%|36.3%|

Busiest hours: 16:00-20:59 UTC, 39-50 posts per hour; 07:00-12:59 has 16-26.

Posts by these 30 accounts under 6 h old with under 50 replies (today's count), weekdays 16-20 Nov (best covered):

|UTC|Mon-Fri counts|Median|Under 3 h old, median|
|---|---|---|---|
|13:00|4, 6, 20, 11, 13|11|4|
|14:00|4, 8, 16, 13, 16|13|5|
|17:30|8, 6, 21, 11, 24|11|7|
|18:30|14, 14, 22, 18, 26|18|11|

9-13 Nov counts are lower (0-11) because rows are missing. 223 of 605 posts have under 5 replies.

## Claims

`repo/` = https://github.com/xai-org/x-algorithm/blob/269340ce2e/grox/ . OC = opened and confirmed.

|#|Claim|Source URL|Date|Author|Quoted line|Str.|Checked|For|
|---|---|---|---|---|---|---|---|---|
|1|Gemma path passes the signals block|repo/flows/reply_spam/classifier_simple_reply_scorer.py L50-53|21 Nov 2026|X code|"include_signals=True, include_follower_count=True"|A|OC|D3 D6 D10|
|2|Line is rendered whenever the flag is set|repo/core/lm/thread.py L62-63|21 Nov 2026|X code|"Reply Was Pasted: {post.is_pasted}"|A|OC|D6|
|3|Second Gemma model above 125,000; quote-replies go to Grok|repo/flows/reply_spam/constants.py ; classifier_simple_reply_scorer.py L34-36, L57-67|21 Nov 2026|X code|"GEMMA_REPLY_SPAM_MIN_FOLLOWERS = 125_000"|A|OC|D3|
|4|Gemma score 0 applies the same label|repo/flows/reply_spam/plan_spam_comment.py ; task_write.py L140-141|21 Nov 2026|X code|"if score == 0.0:"|A|OC|D6 D10|
|5|Flag comes from upstream metadata; no logic published|repo/core/data_loaders/data_types.py L895-897|21 Nov 2026|X code|"is_pasted=post_metadata.isPasted"|A|OC|D6|
|6|Viral claim that pasted replies rank lower; names no file|https://x.com/konstiwohlwend/status/2118879212342067466|7 Nov 2026|K. Wohlwend, developer|"it will rank lower than if you type it out"|C|OC|D6|
|7|User report of the flag; no staff answer|https://github.com/xai-org/x-algorithm/issues/275|9 Nov 2026|GitHub user|"dictate elsewhere first"|C|OC|D6|
|8|Two write-ups agree both models get the line; neither defines "pasted"; both sell a product|https://typeout.app/blog/x-algorithm-pasted-replies ; https://thexalgorithmbook.com/updates/what-x-code-says-about-pasted-replies|8 Nov 2026|S. Mour; B. Wolcott|"The code for X's apps isn't public"|C|OC|D6|
|9|Bier, answering a request to remove "reply X + RT" posts, said Grok will downrank engagement solicitation; questions are not mentioned|https://x.com/nikitabier/status/2034668641304895664|19 Mar 2026|Bier (bio now: former head of product)|"direct solicitations for engagement"|A|OC|D2 D8|
|10|In this sample later replies had fewer views; smaller authors answered far more often|raw/E4_q3a, E4_q3b|23 Nov 2026|grok live sample, n=39|n/a|B|6 rows spot-checked|D3 D4 D9|
|11|Answered and unanswered replies end with a question about equally often; answered ones were earlier|raw/E4_q4a, E4_q4b|23 Nov 2026|grok live sample, n=77|n/a|B|7 rows spot-checked|D2 D8|
|12|About 20% of niche posts fall in 07:00-13:00 UTC; 36-40% after 18:00|raw/E4_q5a, E4_q5b|23 Nov 2026|grok live sample, n=605|n/a|B|3 rows spot-checked|D4 D7|

Prompts: `prompts/E4_*.txt`. Raw answers: `raw/E4_*.out.txt`.

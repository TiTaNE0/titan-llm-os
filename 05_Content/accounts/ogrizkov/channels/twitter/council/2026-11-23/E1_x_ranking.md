# E1 — How X ranks, limits and punishes replies (evidence only)

No recommendations. Gathered 2026-11-23: five grok queries gave leads; this seat opened the sources (the public repo `xai-org/x-algorithm` at its 21 Nov 2026 head, X Help Center pages, X posts).

Strength: A = X code, policy or staff; B = practitioner with data; C = opinion. Checked: **OC** = opened and confirmed; **ON** = opened, does not say this; **NO** = not opened by this seat (grok lead only). `repo/` = https://github.com/xai-org/x-algorithm/blob/main/ and `help/` = https://help.x.com/en/

## Claims

|#|Claim|Source URL|Date|Author|Quoted line|Str.|Checked|For|
|---|---|---|---|---|---|---|---|---|
|1|For You drops replies from accounts the viewer does not follow (flag default: false). Replies do not reach non-followers through For You.|repo/home-mixer/filters/oon_retweet_reply_filter.rs|21 Nov 2026|X code|"Reposts and replies from accounts the viewer does not follow"|A|OC|D1 D3 D9|
|2|Post-page order: (1) accounts the viewer follows and replies the root author answered, (2) verified accounts, (3) everyone else. An ML score orders within a tier.|help/resources/recommender-systems/conversations-recommendations|undated|X Help|"Verified accounts" … "Everyone else"|A|OC|D3 D10|
|3|Named rank signals: the author replied (a like is not named), the viewer follows the replier, Premium. Tiers: Basic, Premium "larger", Premium+ "largest". No multiplier published.|help/using-x/mentions-and-replies ; help/using-x/x-premium|undated|X Help|"if the original post author has replied"|A|OC|D3 D9|
|4|Reply candidates: the 3,200 most recent replies; bigger threads add the top 800 by a search model. No rule rewards early arrival as such.|as #2|undated|X Help|"up to 3,200 of the most recent replies"|A|OC|D3 D4|
|5|If the parent or root author has over 250,000 followers, a Grok model scores the reply 0–3. Below that, a lighter Gemma spam screen runs. The scoring prompts are withheld.|repo/grox/flows/reply_spam/task_filter.py ; prompts.py|21 Nov 2026|X code|"GROK_GEMMA_FOLLOWER_SPLIT = 250_000"|A|OC|D3 D8 D10|
|6|The scorer's input includes the reply author's replies in the last 24 hours, follower count, blocks received in 24 hours, and whether the reply was pasted. (Grok said the paste flag is only logged; the file shows it reaches the model.)|repo/grox/core/lm/thread.py|21 Nov 2026|X code|"Num Replies Last 24 Hours" ; "Reply Was Pasted"|A|OC|D1 D6 D10|
|7|Score 0 adds the label `RiskyHighVizReply`. The reply is then dropped from notifications of people who do not follow the replier, so the target author may not see it. Exempt: grey badge or credibility score ≥ 66. Blue check is not exempt.|repo/grox/flows/reply_spam/task_write.py ; repo/visibility-filtering/rules/levels.rs|21 Nov 2026|X code|"RISKY_HIGH_VIZ_REPLY_EXEMPT_MIN_PAGE_RANK_SCORE = 66"|A|OC|D3 D10|
|8|Enforcement rules name LLM-slop classes. `llm_slop_post` adds `RiskyHighVizReply` for 30 days. `llm_slop_user` adds the account label `SpamHighRecall` for 7 days, which drops the account's posts from For You recommendations and from notifications. The classifier is not published. (Grok: not confirmed.)|repo/abuse-enforcement-service/service-lib/rules/enforcement_user.yaml ; enforcement_post.yaml|21 Nov 2026|X code|"llm_slop_user" in score.labels|A|OC|D5 D6 D10|
|9|Clusters of replies with duplicate text get the label `COPYPASTA_SPAM`. Only high-PageRank and grey-badge accounts are exempt.|repo/botmaker-rules/scarecrow/bot/BBQDuplicateTextRepliesProd.bot|21 Nov 2026|X code|TweetRtfApplyLabel("COPYPASTA_SPAM", :tweetId)|A|OC|D6|
|10|Policy bans high-volume unsolicited replies, near-identical "Copypasta" and off-topic promotional replies, for all users. Penalties include "downranking the post in replies". "High-volume" has no number.|help/rules-and-policies/authenticity|April 2025|X policy|"bulk, aggressive, high-volume unsolicited replies, mentions, or direct messages"|A|OC|D1 D6 D10|
|11|"Show probable spam" folds replies judged on the author's past behaviour and the reply text.|help/using-x/mentions-and-replies|undated|X Help|"the author's previous behavior and the content of the reply"|A|OC|D10|
|12|Automation rules define automation as actions with no person performing them. Keyword-search auto-replies are banned; AI reply bots need written approval (the Developer Guidelines contradict that line). Nothing covers an AI draft posted by hand.|help/rules-and-policies/x-automation ; https://docs.x.com/developer-guidelines|Updated April 2026|X policy|"without a person actively performing them"|A|OC|D5|
|13|No X rule found requiring disclosure of AI-assisted text. The "Automated" label is for API bots; "Made with AI" labels cover media.|help/using-x/automated-account-labels ; https://x.com/en/tos|undated; ToS 9 Oct 2026|X Help, ToS|"perform programmed actions through the X API."|A|NO|D5|
|14|The API may post a reply only when the author mentioned or quoted the account. Stated reason: LLM reply spam.|https://x.com/XDevelopers/status/2026084506822730185|23 Feb 2026|X Developers|"only reply if the original author @ mentions you"|A|OC|D5 D10|
|15|X announced automation detection: accounts where no human taps the screen will likely be suspended.|https://x.com/nikitabier/status/2022496540275937525|14 Feb 2026|Nikita Bier, then X head of product|"If a human is not tapping on the screen"|A|OC|D5 D10|
|16|Staff line: AI proofreading is allowed; programmatic engagement with users is not.|https://x.com/nikitabier/status/2059789636885790911|28 May 2026|Bier|"Proofreading content with AI is fine"|A|OC|D5|
|17|X removed 42,000 accounts that automated replies with chatbots.|https://x.com/nikitabier/status/2080747924380856519|24 Jul 2026|Bier|"without a human in the loop runs counter to our mission"|A|OC|D5 D10|
|18|X blocked an account after judging its posts AI-written and asked for human-written content only. How X judged is not stated.|https://x.com/nikitabier/status/2082005176945426787|28 Jul 2026|Bier|"please only submit human-written content to X."|A|OC|D5 D10|
|19|A dislike control on replies feeds reply ranking.|https://x.com/nikitabier/status/2034293888350114233|18 Mar 2026|Bier|"used purely for ranking & personalization of that section"|A|OC|D8 D10|
|20|Technical cap: 200 replies a day for unverified accounts. No Premium figure published.|help/rules-and-policies/x-limits|undated|X Help|"50 original posts and 200 replies per day"|A|OC|D1|
|21|For You weights: reply 5.0, follow author 4.0, profile click 0.0, not interested −53.07, mute −58.8, block −31.2, report −234. They multiply predicted probabilities, not counts.|repo/home-mixer/params/param.rs|synced 20 Nov 2026|X code|"the weights do not multiply raw engagement counts"|A|OC|D8 D10|
|22|The widely quoted "reply engaged by author = 75" is an April 2023 For You weight. The 2026 action list has no such action.|https://github.com/twitter/the-algorithm-ml/blob/main/projects/home/recap/README.md|5 Apr 2023 (older)|Twitter code|"scored_tweets_model_weight_reply_engaged_by_author: 75.0"|A|OC|D3|
|23|Original posts from mutual follows get +15 on the reply weight. Replies are excluded.|repo/docs/BIDIRECTIONAL_BOOST_CHANGE.md|July 2026|X code|"boosts original posts from people you mutually follow"|A|OC|D3 D9|
|24|The new-author boost covers original posts only (author ≤ 50,000 followers, post under 200 impressions, at most 2 hours old). For You drops posts older than 48 hours.|repo/home-mixer/scorers/author_cold_start.rs ; repo/README.md|21 Nov 2026|X code|"Posts older than 48 hours"|A|OC|D4|
|25|Staff: link posts get lower reach because readers engage less. Nothing found on links in replies. (Grok's quote "Links are not deboosted" is not in this post.)|https://x.com/nikitabier/status/1979994223224209709|19 Oct 2025|Bier|"posts with links tend to get lower reach"|A|OC|D8|
|26|Authors can limit replies to verified accounts or to accounts they follow.|help/using-x/x-conversations|undated|X Help|"only accounts which are verified"|A|OC|D3|
|27|X's "Under the Hood" page (https://x.com/i/jf/under_the_hood) shows the visibility labels on one's own account and posts.|repo/README.md|13 Aug 2026|X code|"labels on their account and posts that can limit visibility"|A|OC (README only)|D9 D10|
|28|One X Analytics export, 17 days, account just past 1,000 followers: 933 replies, median 15 impressions, 23 reached 100, 244 profile visits, 19 followers. Same days: 150 posts, median 1,621 impressions, 165 followers. Author sells a PDF.|https://talkfirstplaybook.com/guides/reply-strategy-x|8 Oct 2026|Michał @b4dgerr|"Replies are how a new account meets people, not how it gets reach."|B|OC|D1 D3 D9|
|29|Same export: 70 "let's connect" replies gave 14 followers (1 per 5); the other 863 gave 5 (1 per 173).|as #28|8 Oct 2026|Michał @b4dgerr|"one new follower for every five replies"|B|OC (numbers; exact quote not re-checked)|D2 D8|
|30|A second export, 26 days, follower count not given: 424 replies gave 11,830 impressions, 170 profile visits, 8 follows; 52 posts gave 902 impressions, 1 follow. Publisher sells marketing software.|https://scout7.ai/content/x-reply-strategy|29 Sep 2026|Murali Sid, Scout7|"The reply earns the visit. The post helps convert the visitor."|B|OC|D1 D9|
|31|Self-reported totals, no per-reply data: 39 → 2,316 followers in 25 days at about 94 replies a day on posts under an hour old. Similar claims at 50–120 a day (@aryanlabde, @yashhq_22; not opened).|https://x.com/TonyChanBuilds/status/2124098569191768499|21 Nov 2026|Tony Chan|"went up in the last hour."|B (weak)|OC|D1 D4|
|32|Self-report: 250+ replies in a day under "let's connect" posts, then a 3-day "shadowban"; he advises 79. No analytics shown.|https://x.com/MaximLevoshin/status/2123135413946822859|18 Nov 2026|Max, founder|"Once I did 250+ a day then got shadowbanned for 3."|C|OC|D1 D10|
|33|Premium accounts had about 10x the median reach per post. Posts, not replies.|https://buffer.com/resources/x-premium-review/|2 Oct 2025|Buffer|"18.8 million posts from 71,000 X accounts"|B|OC|D3|
|34|Best-hour studies cover posts in local time, not replies or the AI niche: Buffer, Tuesday 9 a.m.; Sprout (tech), Tue–Thu 11 a.m.–4 p.m.; Eden, small hour effect, replies excluded.|https://buffer.com/resources/best-time-to-post-on-twitter-x/ ; https://sproutsocial.com/insights/best-times-to-post-on-twitter/ ; https://eden.so/blog/best-time-to-post-on-x/|Mar–Aug 2026|vendors|"no replies, retweets, quote tweets, or X articles"|B|NO|D4|
|35|A well-known developer published a block list of 3,728 accounts he says post automated AI replies (498 already suspended), with one-click blocking for others.|https://x.com/levelsio/status/2123388955143893122|19 Nov 2026|Pieter Levels|"once I block them they're blocked by the entire network"|B|OC|D5 D10|
|36|A tool seller's own account: posts started from AI drafts had 0.81x his median reach against 1.02x hand-written. He says cause cannot be separated.|https://climbx.so/blog/does-x-penalize-ai-generated-posts|10 Oct 2026|D. Smidstrup, ClimbX|"cannot tell the two apart."|C|NO|D5 D8|
|37|EU AI Act Article 50 applies from 2 Aug 2026. Its text-disclosure duty covers text published to inform the public on matters of public interest, exempts human-reviewed text and excludes personal non-professional use.|https://artificialintelligenceact.eu/article/50/|in force 2 Aug 2026|EU law|"human review or editorial control"|A (law, not X)|OC|D5|
|38|Grok lead: a builder's audit found 324 replies averaging 83 views, top views under large threads.|https://runbyagents.usectl.com/research|17 Sep 2026|research log|"top reply views came from being under large threads"|B|ON (not in the part of the page read)|D3|

## What the evidence does not tell us

No A or B source was found for these.

- **D1.** A safe or effective number of replies per day for an account under 1,000 followers. X gives no number for "high-volume". The scorer sees "replies in last 24 hours" (#6) but how it uses it is withheld. All volume-with-growth reports (50–250 a day) are self-reported totals, mostly from "let's connect" reciprocity threads, not niche discussion. No public test shows what volume triggers a restriction.
- **D2, D8.** Whether a short agreeing reply earns follows compared with a reply that adds a fact, number or counterexample. The only split (#29) compares connect-asks with everything else. What earns 0, 1, 2 or 3 from the reply scorer.
- **D3.** Impressions, profile visits or follows per reply by target size (500k+, 5k–100k, under 5k). The "reply to accounts 2–10x your size" rule: its one opened source calls it "not measured data". How often AI labs or known builders answer small accounts. How common verified-only replies are on large AI accounts. Whether the Grok-scored tier above 250,000 helps or hurts a good reply from a small account.
- **D4.** Any measured effect of reply latency (5, 15, 60 minutes, 24 hours). When AI labs and AI builders post. Best hours for an AI and developer audience.
- **D5.** Whether mentioning AI assistance changes reach. How X decides text is AI-written (#18), and whether the `llm_slop` classes (#8) fire on AI drafts that a human posts by hand.
- **D6.** What the scorer does with "Reply Was Pasted", and what counts as pasted (the flag is not defined in the published code). How similar replies must be to form a `COPYPASTA_SPAM` cluster. Whether repeating the same project facts in different wording matters.
- **D7.** Nothing external bears on empty or thin runs.
- **D9.** Typical follows per reply for a sub-1,000 account. The two exports (#28, #30) disagree on whether replies or posts bring more reach.
- **D10.** How the labels in #7–#9 change a reply's position on the post page (only notification and For You rule sets are published). Whether this account carries any label now; #27 names the page that would show it.

## Grok query files

Prompts in `council/2026-11-23/prompts/`; raw answers in `council/2026-11-23/raw/` under the same name with `.out.txt`.

- `e1_q1_reply_ranking.txt`
- `e1_q2_limits_enforcement.txt`
- `e1_q3_growth_small_accounts.txt`
- `e1_q4_target_size_timing.txt`
- `e1_q5_disclosure.txt`

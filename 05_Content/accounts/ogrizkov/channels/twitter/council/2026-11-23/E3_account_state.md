# E3. Account state of @ogrizkov, live data, 2026-11-23

Role: account analyst. Evidence only, no recommendations.

**Tags.** Every number below is `[ACCOUNT DATA]` fetched live by the grok CLI on 2026-11-23, unless marked `[VAULT]`. The code after each heading names the query. Prompts are in `prompts/`, raw answers in `raw/`.

| Code | Prompt file | Raw answer |
|---|---|---|
| Q1 | `E3_q1_profile_limits.txt` | `E3_q1_profile_limits.out.txt` |
| Q2a | `E3_q2a_posts_0924_1023.txt` | `E3_q2a_posts_0924_1023.out.txt` |
| Q2b | `E3_q2b_posts_1024_1123.txt` | `E3_q2b_posts_1024_1123.out.txt` |
| Q3 | `E3_q3_draft_match.txt` | `E3_q3_draft_match.out.txt` |
| Q4 | `E3_q4_parent_metrics.txt` | `E3_q4_parent_metrics.out.txt` |

## 1. Profile now [Q1]

| Field | Value |
|---|---|
| Followers / following | 58 / 119 |
| Verified | Blue |
| Total posts | 966 |
| Name | Evgeny \| Agentic Systems Builder |
| Bio | "Building agentic systems that develop, promote, and grow my projects. Sharing real pipelines, experiments & numbers" |
| Pinned | 2026-11-12 post about a model retirement, 9 views |

Follower history: only today's count could be observed. No dated series exists (Social Blade returned 404). `[VAULT]` records 52 on 2026-05-18 (`analysis/2026-05-18_account_review.md`) and ~67 in June (`strategy.md`). If the vault figure is right, the account is down 9 since June. **No follower change can be tied to any reply.**

## 2. What he published in 60 days (2026-09-24 to 2026-11-23) [Q2a, Q2b]

60 items retrieved: 54 replies, 5 originals, 1 quote, 0 reposts.

| Period | Days | Replies | Replies/day | Days with a reply | Median views/reply |
|---|---|---|---|---|---|
| 09-24 to 10-23 | 30 | 2 | 0.07 | 1 | 27 |
| 10-24 to 11-02 | 10 | 42 | 4.2 | 9 | 6.5 |
| 11-03 to 11-22 | 20 | 10 | 0.5 | 7 | 70.5 |
| All 60 days | 60 | 54 | 0.9 | 17 | 10 |

- Busiest day: 2026-11-01, 15 replies.
- All 54 replies together: 6,017 views, of which one reply has 4,161. Median 10, mean 111.
- Engagement on the 54 replies: 2 likes, 0 reposts, 3 replies received (one from the post author, one from the @grok bot, one from a third party).
- **Author answered: 1 of 54 (1.9%).** It was @noclipepe (1,374 followers), 2026-10-29.
- 48 replies were top-level, 6 were nested under another reply.

Originals versus replies:

| Type | n | Views (each) | Median | Likes |
|---|---|---|---|---|
| Original | 5 | 38, 16, 10, 3, 9 | 10 | 0 |
| Quote | 1 | 15 | 15 | 0 |
| Reply | 54 | 2 to 4,161 | 10 | 2 |

All 5 originals carried media. `[VAULT]` The May review recorded originals at 235 to 13,362 views and up to 60 likes in April-May 2026. That file was a Grok summary and was not re-checked here.

## 3. Views per reply by size of the account replied to [Q2b]

Follower counts are today's, not the count on the day of the reply. For a nested reply the account is the immediate parent.

| Followers of account | n | Median views | Best | Author answered |
|---|---|---|---|---|
| under 5k | 8 | 13.5 | 266 | 1 |
| 5k-50k | 28 | 9 | 4,161 | 0 |
| 50k-500k | 13 | 8 | 205 | 0 |
| over 500k | 4 | 11 | 22 | 0 |
| not retrieved (@sentimentGod) | 1 | 5 | 5 | 0 |

The four replies under accounts over 500k: @Google 12 views, @GoogleDeepMind 10, @claudeai 3, @GeminiApp 22. Their parent posts had 1.2M to 7.5M views and 157 to 2,853 replies [Q4]. Two of the four were posted within 1 hour of the parent.

Follower size is a weak proxy: several small accounts had viral posts. By the parent post's own numbers [Q4]:

| Replies already on the parent (today) | n | Median views | Best |
|---|---|---|---|
| 20 or fewer | 17 | 16 | 4,161 |
| 21-100 | 9 | 11 | 205 |
| 101-300 | 14 | 6 | 172 |
| over 300 | 14 | 11 | 119 |

| Parent post views | n | Median views | Best |
|---|---|---|---|
| under 10k | 11 | 5 | 42 |
| 10k-100k | 18 | 7 | 4,161 |
| 100k-1M | 16 | 16 | 205 |
| over 1M | 9 | 10 | 119 |

Median share of the parent's views that his reply received: 0.012%.

## 4. Views by age of the post when he replied [Q2b]

Age = reply time minus parent post time. Known for all 54. Median age 6.2 h.

| Age of parent | n | Median views | Best |
|---|---|---|---|
| under 1 h | 6 | 3 | 22 |
| 1-3 h | 10 | 14 | 119 |
| 3-6 h | 11 | 42 | 4,161 |
| 6-12 h | 4 | 8.5 | 25 |
| 12-24 h | 20 | 9.5 | 266 |
| over 24 h | 3 | 4 | 10 |

Groups are small. The under-1h group has only 6 items, 2 of them under @claudeai and @GeminiApp.

## 5. Views by how many replies he posted that day [Q2b]

| Replies that day | n replies | Median views | Best |
|---|---|---|---|
| 1-2 | 15 | 42 | 205 |
| 3-5 | 15 | 10 | 4,161 |
| 6-9 (one day, 10-29) | 9 | 32 | 266 |
| 10+ (one day, 11-01) | 15 | 3 | 8 |

On 2026-11-01 none of 15 replies passed 8 views. This is one day, so it shows a coincidence, not a cause. Parent age and thread size also differed that day.

By posting hour (UTC; Israel winter time is UTC+2): 00-05 n=6 median 70.5; 06-11 n=20 median 8; 12-17 n=15 median 5; 18-23 n=13 median 10.

## 6. The eight best replies [Q2b, Q4]

| Views | Date | Replied to (followers) | Level | Parent age | Replies on parent | First words |
|---|---|---|---|---|---|---|
| 4,161 | 10-27 | @heydamir (10,703) | nested | 4.5 h | 5 | "Wow, really Huge ones, this infinite portfolio is awesome" |
| 266 | 10-29 | @noclipepe (1,374) | top | 13.0 h | 17 | "Telling ya, Google takes its place at top three SOTA" |
| 205 | 10-24 | @ashen_one (57,562) | top | 16.2 h | 89 | "It's same sick as on my iPad mini" |
| 172 | 11-19 | @charlierguo (9,871) | top | 4.7 h | 149 | "Thanks, I was also lost in those OpenAI models." |
| 156 | 11-20 | @rezoundous (12,151) | top | 4.3 h | 20 | "@grok what is that Google cloud 40 usd ?" |
| 149 | 11-16 | @gtechtn (80) | nested | 5.4 h | 11 | "Mostly yes, but I made that remote control from browser" |
| 119 | 11-21 | @_mohansolo (106,854) | top | 1.1 h | 1,202 | "That was a great surprise as I was used mine" |
| 95 | 11-19 | @vikaskansalHQ (9,870) | top | 1.3 h | 315 | "Oh My! They made it YouTube Family plan!" |

The 4,161-view reply sat under the author's own follow-up post (76,807 views, 5 replies) inside a thread whose root had 2,048,548 views. It got 1 like. All eight were written by him, not by the pipeline. Only the 149-view reply carried media and named his own project work.

## 7. Pipeline drafts: what was posted [Q3, Q4]

- `2026-11-01_batch`: **6 of 13 posted**, all on 2026-11-01, five word-for-word (including the `isn;t` typo), one without the final period.
- `2026-11-22_batcha`: **0 of 8 posted** at fetch time. No @ogrizkov post exists on 11-22 or 11-23.

| Draft | Target (followers) | Parent age | Parent views / replies | Views | Likes | Author answered |
|---|---|---|---|---|---|---|
| #1 | @LinuxHandbook (161,065) | 19.6 h | 107,467 / 73 | 6 | 0 | no |
| #2 | @jmwind (49,837) | 22.5 h | 78,488 / 51 | 3 | 0 | no |
| #3 | @leoleotoobad (2,062) | 34.3 h | 46,965 / 197 | 2 | 0 | no |
| #4 | @mardehaym (60,509) | 52.3 h | 14,955 / 117 | 4 | 0 | no |
| #5 | @JustinAngel (6,578), nested under @theo | 18.6 h | 11,715 / 10 | 5 | 0 | no |
| #6 | @Voxyz_ai (31,454) | 21.5 h | 11,194 / 12 | 3 | 0 | no |

Pipeline replies: n=6, median 3.5 views, best 6. His own nine replies on the same day: median 3, best 8. His own 48 replies over the 60 days: median 10.5.

## 8. Signs of limits [Q1]

- **Hidden under "show more replies": not retrievable.** Grok's thread tool returns only 2-3 top replies per post and no ranking. His reply was absent from that sample on all 10 threads checked, including threads with 11 and 20 replies. This neither proves nor rules out hiding.
- Search ban: no. `from:ogrizkov` returns his posts; user search returns him first.
- Labels: none seen. The tools have no dedicated label field.
- Sudden drop inside the 60 days: none. The four newest replies (11-19 to 11-21) have 95 to 172 views, the high end of the range.

## 9. Reliability and gaps

- Grok search returns at most 10 posts per call. Q2a and Q2b paged by day and by post id until every window returned fewer than 10. Grok believes both lists are complete for indexed public posts. Deleted or unindexed posts would be missing.
- Cross-checks that agree: Q1 fetched 29 of the same items separately with identical view counts; Q3 and Q2b found the same six pipeline replies; Q4 filled 54 of 54 rows.
- All view, like and follower numbers are totals on 2026-11-23, not at posting time.
- Not retrieved: reply ranking and hidden-reply status; any dated follower history; profile visits and follows per reply (these exist only in the owner's own X analytics); followers of @sentimentGod.
- Sample size is 54 replies, most from ten days. Medians in groups under 10 items are fragile.

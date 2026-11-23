# E6. Spec gap audit: reply pipeline v3.2

Fresh-context critic, 2026-11-23. Sources: the spec with its hooks revision (A, B, D are its sections), DECISION, E1, E3, E4, the issues log, strategy, voice, account, pipeline files, telemetry of both 11-23 runs.

## 1. Coverage map

|Stage|Status|Spec|Hole|
|---|---|---|---|
|Discovery|partly|B3 step 2, B7|Queries come only from project entries; no author watchlist|
|Selection|partly|A2, D1|No floor on parent views; reply restrictions unchecked|
|Timing|partly|B1, D1|Mail lands about 45 min after the slot; post-by ignores his windows|
|Angle, starter|covered|B4, B5|none|
|Hooks|partly|A2, B5, B7|A label: fit, variety and adherence unchecked|
|Voice|partly|B5, B8|His only if he rewrites; no topic-comfort filter for Clean|
|Gate|covered|A1, B2, B6|1 SHIP probe in 7: an over-strict critic still calibrates|
|Delivery|covered|A6, A7|Verified to Sent, not to the phone|
|His work per item|missing|UI section|No effort budget; nobody walked the phone flow|
|Follow-up|missing|none|Nothing happens after an author answers|
|Measurement|partly|A4, D3|Visits and follows only as weekly totals|
|Learning|partly|A4 `period`|Only the ceiling has a rule and an owner|
|Profile conversion|missing|DoD line, B11|No draft, no gate, no owner|
|Account safety|partly|A3, A4|Ramp counts deliveries; tripwire absolute; no monthly label step|
|Operator workload|missing|none|No weekly budget; launch stacks everything|
|Failure handling|partly|A3, B3|Board line only; two stop reasons never alarm|
|Cost, run time|partly|D1 `cost`|Call caps, no token figure; run time assumed|
|Launch test|missing|Tests|Stubs only; the first live run is his first trial email|

## 2. A day in the life (16:00 slot, week 1)

- 16:11 the session starts (all three scheduled runs started at :11-:12; the spec's fixtures use 16:11).
- 16:11-16:20 preflight, then measurement and feedback (B3 0b-0d); weekly also the pattern refresh and critic qualification. One grok search call took 2.3-6.7 min.
- 16:20-16:25 scouts. Capture is about 16:22: the fresh band is posts from 14:52 on.
- 16:25-16:47 thread fetches, Matcher, Drafter, gates, Critic with 7 probes, two interest reviewers.
- 16:49 mail verified (my estimate: the old, shorter pipeline took 24-25 min from start; the spec assumes 25; the deadline allows 17:26).
- His window opened at 16:30. At 16:50 he opens the mail, taps "Open post", reads the thread in X, flips back to Mail for the angle and starter (no split view on an iPhone), types 25-40 words of English, posts about 16:57.
- Age of the post then: 35 min at best, 80-125 typical for the fresh band, up to 245 for the older band. The card says post by 18:49; his window ends 18:30.
- 20:30 repeats: start 20:41, mail about 21:19, post-by 23:19, window ends 23:00.

Where it breaks:
1. Answered replies arrived a median 73 min after the post, 17 of 37 within 60 min; views by delay 45, 24, 18 (E4 Q3-Q4). Most of his will land at 80-250 min.
2. Posts made after 16:22 are never seen, though he is at the phone until 18:30.
3. Week 1 gives one item per run. If nothing passes there is no mail, and "nothing passed" looks like "Mac asleep".

## 3. Gaps, ranked by harm to the goal

**Must fix before approval**

1. **Profile conversion has no owner.** DECISION A1: replies earn visits, the profile converts them; forecast 1-2 followers in 4 weeks. `COMPOSE_PIPELINE_DESIGN.md` called conversion the bottleneck in June and was never built. The pinned post has 9 views; nobody drafts the new one and launch does not wait for it. Fix (B10, A4): `set-mode live` refuses until `weekly.md` holds the new pinned post's URL; the main session polishes his rough draft; `period` names a profile change when visits rise and follows do not.
2. **Replies land late by construction** (section 2). Fix: `windows` in `params.json`; post-by = the earliest of send + 120, window end, post time + 360; move B3 0b, 0d and the pattern refresh after delivery; start runs so the mail lands as a window opens; log candidates by age band in the funnel, so day 14 can decide on a second run inside each window. B1 settles that by argument; DECISION 10 item 7 asked for a test.
3. **Discovery looks for the wrong posts.** Vectors exist only for project entries (B7), yet Deep is capped at 1 a day: 5 of 6 items are Clean replies found by queries tuned for Deep. Answering authors are only a tie-break, though authors of 2k-20k answered 9 of 15 (E4 Q3). Fix: `agents/watchlist.json` (E4's 30 accounts, authors who answered him, tier-1 accounts he follows) as the Scout's first query; topic vectors from voice.md's authority zones; the Matcher drops Clean items outside them.
4. **Silent outages remain.** `guard` (branch not `main`, dirty tree) and `locked` are not "empty" in A3 `health`, so they never alarm. This vault is one working copy where other tasks switch branches, and `params.json` sits in guarded `C/agents`. If no run starts, `health` never runs. The only channel is a board line. Fix: count every non-delivery reason; build the E23 worktree on `main`; one status line in each reply mail ("since last mail: 3 slots, 2 empty: guard"); `runs/_analytics/STATUS.md` every slot.
5. **The ramp limits deliveries, not his replies.** The label followed his own jump from 0 to 5-9 replies a day. `all_replies_per_day` is 10 from day 1. The stage counts days since the first trial mail, so a slot leaving a two-week trial opens at 6 a day even if he posted three. Fix (A3): allowance = min(stage, his 7-day posted average + 2); ramp the total (4, 6, 10); header line "today: N more, yours included"; read his reply count every run.
6. **The tripwire fires on small threads.** It counts absolute views. His replies under parents below 10k views had a median of 5 (E3 section 3, n=11); fresh candidates in the last three runs had median 21-128 views. Fix: `parent_views` in `reply_log`; a reply counts only when its parent passed 2,000 views.
7. **Hooks are a label, and mode B never asks for what only he has.** `check-item` tests that the id exists, not that the opening follows it, fits the type or varies. The card shows "H3 · name", which his rewrite erases. Four of his eight best replies are first-person experience (E3 section 6); Clean forbids it, and the own-8 report judges them "as Clean". Fix: the hook as one instruction line; one use per mail, rotated by ledger; an optional card line "Yours?" with one question to him, never a claim; log `added_experience`.
8. **Nothing follows an author's answer.** It is the rank signal X names (E1 claims 2-3) and the period-1 bar, yet the loop ends at the first send. DECISION section 5 leaves the follow-up to him; the spec is silent. Fix: header line "if the author answers, reply once the same day"; the Wins-logger logs `followed_up`; follow-ups count in the daily total.
9. **Learning has no owner, loses its input at launch and never sees the goal metric.** `--feedback` reads `[TRIAL]` subjects only; `period` proposes only the ceiling; the weekly pattern refresh is one grok call, 10 posts at most (E3 section 9); a hook needs 30 replies and 28 days deliver about 126. Visits and follows exist only as weekly totals, though X Analytics exports them per reply (E1 claims 28, 30). A failed trial has no path: agreement uses the first 26 marks forever. Fix: feedback in live mode with reason words (target, angle, wording, late); `measure.py import-export` on days 14 and 28; runbook `## LEARNING`: per period at most 5 proposed changes, he approves; patterns every 14 days from 40 winners and 40 controls; a recorded gate change opens a new 26.
10. **No live test and no workload budget.** Tests use stubs, so the first live run is his first trial mail; nobody counted his minutes. Fix (DoD, B11): one supervised live run without `--send`; one walk-through on his phone, minutes per item recorded; a table of his minutes per week: before trial, before live, later.

**Can follow later**

- Three more SHIP probes. A stop he can send from the phone (reply "PAUSE 3").
- Monthly `under_the_hood` step; the November report tests the label reading.
- Token ceiling per run; cost per delivered item in the trial report.
- iCloud SMTP as sender if Mail fails again (R-6).
- Fetched sources and thread text are untrusted input.

## 4. Contradictions

- Post-by (send + 120) against his windows (DECISION 11): 18:49 and 23:19, at the 75-min deadline 19:26 and 23:56. Also against "lands under 6 h" (D3): 210 + 75 + 120 = 405 min; B1 says 355.
- "Never raise by more than 2 a day from one week to the next" (DECISION 11.1) against the calendar ramp of A3. B10 says the ramp applies "to what he posts"; A3 counts days.
- DECISION 10 item 8 sends the logged-out spam-fold check "into the spec"; item 5 orders a re-pull of the May post numbers. Neither is there.
- DECISION 10 item 1 sets the minimum as replies plus the pinned post. The DoD still collects `finding` and `his_words` for about 31 entries at launch.
- DECISION 11.2 drops the weekly label check because the report is monthly. D3 keeps a weekly `under_the_hood` column and has no monthly step.

## 5. What to cut

- Tier 3 (125k+) until day 28: authors above 20k answered 1 of 24, and week 1 has two replies a day.
- The D5 schema growth at launch; ask for a `finding` line when a Deep bind is blocked.
- Seven probes in every critic call: full set at the 7-day qualification, two per call.
- The Mail sheet check: it needs Accessibility and adds nothing over the Outbox, Drafts and Sent checks.
- Realigning the two legacy doc lints: I-1 showed they test documents, not reality. Retire them.

## 6. Second opinion: Grok

Prompt `prompts/G_spec_completeness.txt`, answer `raw/G_spec_completeness.out.txt` (400-word summary, no names). Grok independently named gaps 1, 2, 3, 6 and 8 and the status line of gap 4. Its items that my list lacks:

- Ceiling 4 a day until a month passes without a label: 6 sits in the 5-9 band that preceded it.
- Follow-up limits: one a day, one reply then stop, follow the author only after an answer, two replies per author per week.
- Phone rule: no paste, link or hashtag; if he cannot restate the angle in a minute, skip and log.
- Day 28: under 10 net follows or no author answer replaces the watchlist; volume stays.
- Two originals a week: the new-author boost covers original posts only (E1 claim 24).
- Drop a candidate that will be over 3 h old when his window ends.
- Cuts: the second reviewer, the cross-family critic, targets above 20k, the day-14 raise, six of the 11 rules. The either-reviewer rule is an approved default (DECISION 10 item 2); cutting it is his call.

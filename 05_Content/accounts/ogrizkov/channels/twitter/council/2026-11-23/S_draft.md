# S — Draft decision record, growth council 2026-11-23

Status: synthesiser's draft, before red team. No pipeline file has changed.
**Missing inputs: `E4_gap_round2.md` and `X2_*.md` do not exist.** One cross-examination round ran; it ended with 9 questions agreed and 1 disputed.

Framing facts:
- Grok withdrew its own proposal after a live look at the account. "15 a day" and "obvious but relevant" have no seat behind them. Neither has "3 per run, empty runs are fine".
- Account today: 58 followers, Blue. 54 replies in 60 days: median 10 views, 1 author answer (1.9%). Last batch: 0 of 8 drafts posted.
- Published exports show 1 follow per 53-173 ordinary replies: about 1 follow per 14 days at 6 a day. Replies earn profile visits; the profile must convert them.

Evidence labels: **A** = X code, policy or staff. **B** = practitioner or live sample with data. **Account** = live data on @ogrizkov. **Opinion** = model judgement only.

## 1. Decisions

**D1 Volume. Up to 6 replies a day, as a ceiling, never a target.**
- Numbers: 2 runs, 3 per run, floor 0. Hold 14 days, then +2 or -2 by the section 3 rule; stop at 10 until a second passing period. No 15.
- Evidence: opinion for the number. A: the reply judge sees the replier's 24-hour reply count, weight withheld. Account: the one 15-reply day had median 3 views (confounded by stale targets).
- Votes: Claude 8, Grok 6, Gemini 6. Dissent, Claude: 6 gives under 60 posted replies in 14 days, too few for the tests. Chosen anyway: raising to 8 later is free, a label costs 7-30 days. The operator may overrule.

**D2 Reply types. Two types, one bar: the reply adds one specific thing the thread lacks.**
- Numbers: Deep = a project fact answers, contradicts or measures the author's claim; max 1 a day. Clean = no project fact. No ratio. 0 "obvious but relevant" replies.
- Evidence: opinion; account (operator's verdict on batch A); B (863 ordinary replies gave 5 followers).
- Votes: bar unanimous. Deep cap: Grok and Gemini 1 a day. Dissent, Claude: no cap, fit decides.

**D3 Targets. Fresh, uncrowded threads of small responsive builders; large accounts are a capped experiment.**
- Numbers: the reply lands under 6 h after the parent, so capture at 3.5 h or less (plus 30 min run, plus 2 h to post). 40 replies or fewer. Authors of 1k-20k first, answering authors on top (a preference). At 125k or more: 1 a day.
- Under a 500k account a small account gets close to nothing: his four such replies got 3-22 views under posts with 1.2M-7.5M views (account). Above 250k a Grok model scores each reply and can hide it from the author's notifications; Blue is not exempt (A).
- Evidence: A (judge thresholds at 125k and 250k; the author's answer is the named rank signal); account; B weak (39 replies: median views fall from 45 under 1 h to 7 at 6-12 h; authors of 2k-20k answered 9 of 15, larger ones 1 of 24).
- Votes: agreed. Capture: Claude 3 h, Grok and Gemini 4 h. "Large": Claude 250k, Grok 150k, Gemini 125k. Dissent, Claude: responsiveness as a hard filter; 60% of delivered to 1k-20k authors.

**D4 Timing. Runs at 16:00 and 20:30 Israel time; post within 2 h of the email or skip.**
- Numbers: aim for 60 minutes. The 08:00 slot (01:00 US East) goes.
- Evidence: B (605 posts by 30 niche accounts: 36-40% appear after 18:00 UTC) and opinion.
- Votes: slots unanimous. Deadline: Grok and Gemini 2 h. Dissent, Claude: 60 minutes.

**D5 Disclosure. No reply mentions the reply pipeline or AI drafting; his agent projects stay a subject.**
- Numbers: 0 mentions. He edits and posts each reply by hand.
- Evidence: A. X defines automation as actions "without a person actively performing them"; no rule requires disclosing a draft a person posts. X has blocked an account for AI-written posts. On the operator's point 4: disclosure is neither required nor shown to be punished; all seats, Grok included, see no gain in it.
- Votes: unanimous. Claude alone adds "never deny it if asked": operator's call.

**D6 Paste and duplication. Type by hand under large accounts, test typed against pasted below, never repeat text.**
- Numbers: TYPE at 125k or more and on quote-replies. Below, the email alternates TYPE and PASTE: 15 per arm in period 1, 30 by day 28. Pasted median under 75% of typed, or a label: 0 pastes. Inconclusive: typed. A fact rests 30 days.
- Evidence: A for the facts (both judges receive "Reply Was Pasted"; duplicate clusters get `COPYPASTA_SPAM`). What counts as pasted: not found. Test size, thresholds, cooldown: opinion.
- Votes: agreed for 14 days. Cooldown: Claude 14 days, Grok and Gemini 30. Arm: Grok 15, Claude and Gemini 30. Dissent, Grok: typing every reply costs compliance.

**D7 Empty or thin runs. Widen the search once, never lower the gate, deliver what passed.**
- Numbers: floor 0. One widen pass (queries and authors only). Over 20% of runs empty in a period: discovery audit, then a third run at 22:00 Israel.
- Evidence: opinion. No data for threads over 40 replies; replies at 6-12 h had median 7 views (n=5).
- Votes: mechanism unanimous. Widen may relax: Claude nothing, Grok thread size to 80, Gemini age to 8 h. Alarm: Claude 10%, Gemini 20%, Grok 50%.
- **This departs from the operator's position 2.** Empty runs are made rare by wider discovery and Clean replies, not a lower bar. The alarm level is his to set.

**D8 Quality gate. Judge what the reply does in the thread, not whether it carries a project.**
- Numbers: 10 reject rules (section 2). Pass: a stranger learns one checkable thing about the post's subject from the reply alone, and the author could confirm or deny it in one line. Statements by default; questions at most 1 in 4.
- Reconciliation: Grok's "do not reject for a missing personal insight" stays; Grok withdrew "obvious is acceptable"; "not interesting" becomes rules 1-3.
- Evidence: opinion; account (0 of 8 posted); B (77 replies: answered and unanswered ones end with a question equally often).
- Votes: unanimous. Dissent on question form: Claude, the question is the whole reply; Grok, only after a stated point. Both allowed and logged.

**D9 Measurement. 14-day cycles on a per-reply log plus his weekly X analytics; volume moves only by rule.**
- Numbers: section 3. Evidence: opinion for every threshold; baselines are account data.
- Votes: agreed. Grok and Gemini: raise at 8% author answers and median 20 views; restart at 2 a day after a label. Dissent, Claude: 10% and 25; restart at 4; at least 50 posted.

**D10 Account risk. The danger is the quality class (AI slop, thin replies under large accounts), not a count of 6-10.**
- Numbers: he checks `x.com/i/jf/under_the_hood` before run 1 and weekly. A label: 7 days off.
- Evidence: A (`llm_slop_user` labels the account for 7 days, `llm_slop_post` the reply for 30; X removed 42,000 AI-reply accounts, mostly in this niche). Triggers unpublished. Votes: unanimous.

## 2. Pipeline parameter sheet

- **Volume:** ceiling 3 per run, 6 a day. No target, no floor. Max 1 per author per day.
- **Ramp:** +2 or -2 a day per 14-day period; cap 10; never under 2.
- **Slots:** 16:00 and 20:30 Israel. Post within 2 h or skip.
- **Tier 1:** authors 1k-20k, answering authors on top. **Tier 2:** 20k-125k, same gates.
- **Tier 3:** 125k or more. 1 a day, post under 2 h old, 20 replies or fewer, a correction or a number, always typed.
- **Freshness:** capture at 3.5 h or less. **Thread:** 40 replies or fewer; no minimum.
- **Level:** top-level; nested only under the author's own follow-up or to answer a named person.
- **Deep:** max 1 a day; fact rests 30 days. **Clean:** same bar, no experience implied.
- **Length:** 25 words or fewer by default, 40 at most.
- **Reuse:** no identical texts; no 5-word run shared with a reply of the last 14 days.
- **Thin run:** under 2 passing, one widen pass, then deliver what passed. Zero: log line, no email.

Gate, any one rejects:
1. It reads fine with the post deleted.
2. Without project nouns and numbers it restates the post or a visible reply.
3. Agreement only.
4. It cannot quote the line it answers.
5. Forced anchor: the fact does not answer, contradict or measure the claim. Drop the target, no redraft.
6. Aphorism, internal label ("E1-E5", vault, kernel), planted typo, engagement bait.
7. Experience or a fact not in the authority file.
8. A fact inside its 30 days, or reused wording.
9. Off-topic promotion.
10. Target outside the age, size or tier limits.

Never reject for a missing project fact. Never pass because of a project noun.

## 3. Four-week measurement plan

Periods: days 1-14 at ceiling 6; days 15-28 at the ceiling the rule gives.

- Per posted reply at 48 h, by the wins logger (`from:ogrizkov`): views, author answered, type, tier, author's answering habit, parent age when posted, replies at capture, slot, TYPE or PASTE, statement or question, replies that day, the text he posted.
- Weekly, by the operator: profile visits and new follows from X analytics; `under_the_hood` status.
- Computed: posted share (posted inside the deadline / delivered); share of empty runs.
- Baselines: the framing facts; peers replying within 3 h have median 24 views.

Volume rule, day 14 and day 28:
- **Raise by 2** if all hold: 40 or more posted, posted share 70% or more, author answers 8% or more, median views 20 or more, no label.
- Under 40 posted, rest met: hold and add the 22:00 run.
- **Cut by 2** if median views are under 10 over 20 or more replies.
- **Label:** 7 days off, restart at 2 a day.
- Posted share under 70%, or 30% of delivered replies marked boring or forced: fix the gate before any volume change.

Measurements for opinion-based decisions:
- D1: median views by replies that day (1-2, 3-4, 5-6) in the same tier. Switch: the volume rule.
- D2: views and author answers by type. Clean under half of Deep for two periods: cap Clean at 1 a day. The Deep cap blocks a fitting reply on 5 days: lift it.
- D3: author answers by tier and by answering habit. 0 answers in 25 replies stops a tier or type. Answering authors at 3 times the rest: hard filter. Views at 4-6 h matching 1-3 h: capture moves to 4 h.
- D4: median views by slot and by minutes from email to post. Drop a slot under half the other. Replies posted after 60 minutes at under half the views: the deadline becomes 60 minutes.
- D6: typed against pasted. The cooldown alone blocks 5 Deep replies in a period: test 14 days.
- D7: empty-run share and candidates lost per stage. Rule in D7.
- D8: posted share, his marks, author answers by question form. Keep the better form after 25.
- D9: if weekly views do not move with profile visits, steer on author answers and visits.

## 4. Changes to `strategy.md` and to the first panel plan

`strategy.md`:
- "Account Status (as of June 2026)", "Followers: ~67" → November 2026, 58.
- Replies: "Grounded in real project work when possible" → "A project fact only when it answers, contradicts or measures the post's claim. Otherwise no project: one specific point the thread lacks."
- Cadence: "2-4 high-signal pieces per week (mix of replies and original posts)" → "Original posts: 2-4 a week. Replies: up to 6 a day in two runs; a ceiling, not a target; changed only by the 14-day rule."
- Cadence: "Best window: Israel evening time (US East Coast morning)" → "Reply runs at 16:00 and 20:30 Israel; post within 2 h or skip."
- Cadence: "Avoid looking like a reply guy" → "Max 1 reply per author per day; 1 a day under accounts of 125k or more; no agreement-only replies."
- Never Do, add: "Never say in a reply that it was AI-drafted; never mention the reply pipeline."
- Unchanged: all other lines. "Never post low-signal content just to maintain cadence" is the basis of floor 0.
- Why: the old cadence line mixed posts with replies and had no data.

First panel plan:
- E1 keep: fit-3 binds apply to Deep only.
- E2 change: cap 3 per slot, 6 a day; zero is allowed after one widen pass.
- E3 change: capture at 3.5 h or less, not 8 h.
- E4 keep: add the D8 pass test.
- E5 keep: add probes. A good Clean reply ships; an "obvious but relevant" one fails.
- E7 keep: drafting starts from what the thread lacks, then checks facts.
- E8 change: 25 words by default, 40 at most.
- E9 change: "he is the doer in every reply" holds for Deep only; the question rule is D8's.
- E12 change: drop the no-I/my batch cap; a closing question is counted, not rejected; add the 5-word check.
- E13 keep: the email adds TYPE or PASTE and a post-by time.
- E17 change: the no-fact path is the default type, not an exception; "max 2 per batch" goes.
- E19 change: the section 3 fields, at 48 h.
- E25, E29 change: alarm also at over 20% empty runs per period; wake times follow the new slots.
- E6, E10, E11, E14, E15 (30 days confirmed), E16, E18, E20-E24, E26-E28, E30: keep.

## 5. What the operator does himself

1. Before run 1 and then weekly: open `x.com/i/jf/under_the_hood`, record any label, and log profile visits and new follows from X analytics.
2. Post within 2 h of the email, aiming for 60 minutes. Later, skip.
3. Type replies marked TYPE; paste only those marked PASTE.
4. Edit freely: his eight best replies were his own casual words. Mark drafts he finds boring or forced.
5. Once, 15-30 minutes: `finding` and `his_words` lines for the ~31 authority entries, plus recent stories (E14).
6. Decide: ceiling 6 or 8; cooldown 30 or 14 days; empty-run alarm; "never deny if asked"; question form.
7. Confirm a test email at the new times on his device before the live schedule changes.
8. Outside D1-D10, named by two seats: the pinned post has 9 views, the last five originals 3-38. Without stronger originals, profile visits will not become follows.

## 6. Open risks, and what reverses a decision

- **Unknown label.** Nobody knows whether the account carries one.
- **One thin sample.** D3, D4 and D8 rest on one live sample (39 and 77 replies, accounts and coding chosen by Grok). Three seats moving on it is not three confirmations.
- **Unpublished triggers.** What sets the paste flag (a paste from Mail may), and whether `llm_slop` fires on drafts posted by hand. Nothing here removes that risk.
- **Supply.** At 16:00 the 30 sampled accounts have about 5 posts under 3 h old. Until discovery is far wider, empty runs may be common.
- **Posted share.** If he does not post inside 2 h, nothing else matters.
- **The gate may reject what works.** His best replies were casual reactions; nested replies did better on his account (median 29, n=6) than for peers (9, n=9).

Reversals. D1: a label, or median views halving. D3: 25 large-account replies beating tier 1 on author answers. D5: an X rule requiring disclosure of hand-posted drafts. D7: over 20% empty runs after the third run reopens the age and thread caps. D8: posted share under 70% in two periods.

## 7. Brief for the agent that rebuilds the pipeline

Replaces the prompt in section 4 of the council brief.

> You are rebuilding the reply pipeline for @ogrizkov (58 followers, Blue). Goal: steady growth through replies a stranger finds worth reading. Volume is a ceiling, never a quota.

> Hard rules: never invent personal facts or experience. The pipeline never posts to X. The email contains only real replies, no status or error mail; when nothing passes, send nothing. No reply mentions the reply pipeline or AI drafting.

> Numbers: the parameter sheet in section 2 of `council/2026-11-23/S_draft.md` is binding. In short: at most 3 replies per run and 6 a day, no minimum; fresh, uncrowded threads of small builders first. Only the section 3 rule changes the ceiling.

> Schedule: 16:00 and 20:30 Israel time. Do not change the live schedule until the operator confirms a test email on his device.

> Drafting: start from what the thread lacks. Read the post and its top replies, quote the line you answer, and name the one thing you add: a mechanism, number, boundary case, counterexample or failure mode. Only then check whether a project fact is that thing. If yes, the reply is Deep. If no, write a Clean reply with no project fact and no implied experience. Nothing to add: skip the target.

> Gate: the ten reject rules in section 2. "Obvious but relevant" fails.

> Email: each reply carries its link, TYPE or PASTE (alternate below 125k; TYPE at 125k or more and on quote-replies) and a post-by time 2 hours after sending.

> Log the per-reply fields in section 3. Keep the architecture. Apply the first panel plan E1-E30 as amended in section 4.

## 8. Who took part

- **Claude seat:** Claude. Model id not recorded in the council folder.
- **Grok seat:** Grok through the grok CLI with live X search. Model id not recorded.
- **Gemini seat:** Gemini, text only, no tools. Model id not recorded.
- **Synthesiser:** Claude (claude-fable-5-2). Not a seat, no vote.

No model family was missing: all three answered the positions and round 1. Round 2 and the second gap round did not run.

# R — Red team, Claude (fresh context), 2026-11-23

Target: `S_draft.md`. Verdict: the draft stops forced replies. Nothing in it makes replies interesting, and by its own arithmetic it does not grow the account in 4 weeks.

**B** blocker, **M** major, **m** minor. § = draft section.

## 1. Five likeliest failures in 4 weeks

1. **No growth even on success (B; framing fact 3, §3).** "1 follow per 14 days" is about 2 follows in 28 days, and the raise rule never looks at follows. Fix: tell the operator this number; make follows and profile visits the success test; move the profile and originals fix (§5 item 8) into the decisions.
2. **Starved runs (B; D3, D7).** Capture at 3.5 h, 40 replies and ten reject rules, where the draft's own sample has about 5 fresh posts at 16:00. Result: silence, against operator position 2. Fix: replay 5 days of discovery under the new limits before launch; restore Claude's dropped fill goal ("3 or more in 9 of 10 runs").
3. **He does not post (M; D4, D6).** Baseline 0 of 8. The plan adds a 2 h deadline and phone typing. Nobody asked why he skipped batch A or when he is free. Fix: ask.
4. **The rule ratchets down (M; §3).** "Cut if median under 10": his 60-day median is 10. Replies land at 6 h, where the peer median is 18, under the raise bar of 20. Fix: thresholds relative to a period-1 baseline; no cut in period 1.
5. **Rules fire on noise (M; D6, §3).** My simulation (lognormal views): with no true difference, "pasted under 75% of typed" bans pasting in 27-35% of trials at 15 per arm. A true 8% answer rate passes "8% of 40" only 40% of the time. "0 in 25" stops a tier with a true 5% rate 28% of the time. Fix: two pre-registered questions per period; other rules report-only.

## 2. Opinion worded as fact

- D10 headline "not a count of 6-10" (M): the weight of the 24-hour count is withheld, and D1 uses that signal to prefer 6. Fix: mark Opinion.
- D1 "raising to 8 later is free" (M): implies 6 is safer than 8. No evidence.
- D3 "Above 250k ... can hide it" (M): a Gemma score of 0 writes the same label at any size (E4 Q1). Tier 1 is exposed.
- D2 "863 ordinary replies" (M): the page never describes those replies. It cannot support the bar.
- D4, B for 16:00 (m): 5 fresh posts at 14:00 UTC against 11 at 18:30 supports 20:30 only.

## 3. Dissent averaged away

- **"3 per run, floor 0, no email on zero" is adopted while the framing says no seat backs it (B; D1, D7).** The operator asked what "3 per run" rests on. Still opinion; three models reading the same files are one opinion. Fix: say so in D1.
- Two seats called profile and originals their plan's main weakness; it became to-do item 8 (B).
- Grok's "two 'not interesting' reviews fail the gate" was dropped: the only proposal that tested interest (M).
- §5 item 6 hands five numbers back to the operator; the brief demanded decisions (M).
- Capture 3.5 h is the mean of 3 and 4 (m).

## 4. Conflicts with hard rules and the complaint

- **Rule 7 against Clean (B; §2, §7).** Clean must add "a mechanism, number, boundary case"; rule 7 rejects facts outside the authority file. Either Clean dies or unverified model claims go out under his name. Fix: a Clean claim must follow from the thread or from a source the pipeline opened and logged; otherwise it is a question.
- **No test of interest (B; D8).** The ten rules only subtract. As I read them, batch reply 5 ("Point 2 held on my iOS localization...") passes, and at least four of his eight best replies fail rule 3. Fix: before launch, gate the 8 batch replies, his 8 best and 10 fresh drafts; he marks them; go live at 80% agreement.
- **X staff line (M; D5).** "please only submit human-written content to X" concerns the text, not disclosure. Every reply above 90 views was his own words; the best pipeline draft got 6. Fix: offer a mode where the email gives target, quoted line and point, and he writes the words. His call.
- **D5 against the bio (M).** "agentic systems that develop, promote, and grow my projects" advertises what D5 hides. Fix: decide the bio in D5.
- **Plumbing (M; §3).** His "boring" marks have no channel; the day-14 verdict has no owner and no delivery path; the draft has no source URLs.

## 5. Arbitrary numbers

No evidence line anywhere (M together): 25/40 words (first panel: 15-40), the 1k lower bound (sample began at 2k), Tier 3 "2 h, 20 replies", "1 in 4", the 5-word run, cap 10, "30% boring". Fix: tag Opinion or delete.

## 6. Missing

- Target quality: three batch targets were listicle or essay posts; one author appears to sell an X growth tool (E1 row 36). Follower bands do not filter that.
- The second reply after an author answers. The KPI counts a correction of a wrong claim as success.
- His own unassisted replies: inside the 6? The control arm?
- Whether `under_the_hood` works for him (only the README was opened).

## 7. Five sources opened

1. `grox/core/lm/thread.py`, head 269340c: both lines confirmed. Supports neither 6 nor 8.
2. `constants.py`, `classifier_simple_reply_scorer.py`: 125k and 250k confirmed. Nothing says the 125k model is stricter, so "TYPE at 125k" (D6) is opinion.
3. `enforcement_user.yaml`, `enforcement_post.yaml`: 7 and 30 days confirmed.
4. Bier posts ...856519, ...167485, ...426787: confirmed verbatim. The third says posts "were determined to be written by AI"; the draft files it under disclosure.
5. talkfirstplaybook.com: numbers confirmed, but the account posted 55 replies a day and the page never calls the 863 "ordinary". Its one split: "let's connect" replies converted 35 times better, a move the gate bans.

X automation rules: quote confirmed. `mentions-and-replies`: 403, not verified.

## 8. The test

All 8 batch targets were 27-44 h old, so rule 10 drops every one. Ignoring age:

1. **@nateherk**. Clean: "Going from 967k to 400k is about 2.4 times more compactions on the same goal. By hour three the agent reads a summary of a summary." The post already says "the tradeoff is more compactions": strict rule 2 drops it. Grok's exemplar for this post repeats @johnroodepic's visible reply.
2. **@yeemio**. Clean: "A hash gate shows the receipt was not altered, not that every step wrote one. A step with no receipt still ends in GO." The third such point in a 9-reply thread; the author already conceded it; the claim guesses at a schema inside a screenshot.
3. **@sristhi_saha**. Deep: "One of mine: lat/lng rounded to 3 decimals, nearest address wrong 30-50% of the time for weeks." Batch reply 8, barely changed.

Interesting to him? No. One skip, one cold nitpick that may be wrong, one reply he has already seen. What earned views on his account was his own casual voice, which the gate rejects.

# Cross-examination: Claude, round 1

Map: M0. E3, E4: council evidence files.

## D1 Volume
1. Grok: no number has evidence, so ceiling only; a target is the quota that stretched batch A. Gemini: 4-6 a day still gives 60-80 replies to learn from.
2. Concede: (a) ceiling only, no target (Grok's quota argument). (b) My ceiling of 12 falls to 8: the paste flag reaches the judge at every target size (E4 Q1), so replies get typed, and he posted 0 of the last 8 drafts [ACCOUNT DATA: E3 §7]. (c) No jump to 15: the two like-for-like replies on the 15-reply day got 3 and 8 views [ACCOUNT DATA: E4 Q2a].
3. Reject 6 a day. Targets explain the 11-01 collapse: 9 of 15 parents were older than 12 h [ACCOUNT DATA: E4 Q2c]; the 9-reply day had median 32 [ACCOUNT DATA: E3 §5]. Ceiling 6 at a 70% posted share gives under 60 replies, too few for 25 per test arm.
4. Ceiling 4 per run, 8 a day, floor 0; +2 per passing period. In `strategy.md` only the reply line changes.

## D3 Targets
1. Grok: discovery is the bottleneck; 12 h and 80 replies buy candidates. Gemini: 6 h, 40 replies, nested threads, where his 4,161-view reply sat.
2. Concede: cap 40 replies (Gemini): views fall from 45 with 0-5 earlier replies to 16-18 with 6-40; nothing measured beyond [SOURCE: E4 Q3, live sample, n=39]. My 250k band top falls: authors of 20k-150k answered 1 of 24 replies, authors of 2k-20k 9 of 15 [same]. Over 250k: 1 a day.
3. Reject 12 h: median views 45 under 1 h, 24 at 1-3 h, 18 at 3-6 h, 7 at 6-12 h [same]. The 6 h cap leaves enough supply: 30 accounts alone give 11-18 uncrowded posts under 6 h at run time [SOURCE: E4 Q5]. Reject nested as a preference: median 9 against 25 top-level [E4 Q3]. Caveat: the 9 of 15 comes from four posts; answering is an author's habit, so filter on the habit.
4. Age counts when he posts: captured at 3 h or less, posted under 6 h. 40 replies or fewer. Authors 1k-20k for 60% of delivered. The author answered a reply in this thread or his last 3 posts. Top-level; nested only under the author's own follow-up.

## D6 Paste
1. Gemini: the scorer sees the flag on every reply, so never paste. Grok: weight unknown, retyping costs compliance, so retype only above 250k.
2. Concede the fact to Gemini: below 250k the Gemma screen gets the same signals, and score 0 writes the same label [SOURCE: github.com/xai-org/x-algorithm, grox/flows/reply_spam/classifier_simple_reply_scorer.py L50-53, 21 Nov 2026]. Typed becomes the default.
3. Reject "never paste" as proven: what counts as pasted, and its weight, were not found (E4 Q1). On 11-01 pasted drafts (median 3.5) and typed replies (median 3) did the same [ACCOUNT DATA: E3 §7].
4. Drafts of 25 words or fewer. The email marks replies TYPE and PASTE alternately; authors over 125k always TYPE. After 30 each: pasted median under 70% of typed, or a label, means 0 pastes; inconclusive means typed. Cooldown 14 days: no evidence anywhere, operator's pick.

## D8 Closing question
1. Grok: a closing question is an AI tell and bait. Gemini: a specific question tied to the claim contributes; replies need "I/my".
2. Concede: the question is no lever. Answered replies end with a question 22% of the time, unanswered 18%; 73% of both are statements [SOURCE: E4 Q4, n=77]. Speed separates the groups: 17 of 37 answered replies came within 60 min, 5 of 40 unanswered.
3. Reject the hard ban: the same data show no penalty, and Bier's post does not mention questions [SOURCE: x.com/nikitabier/status/2034668641304895664, 19 Mar 2026]. Reject "I/my": a reply with no project fact would have to invent experience [MODEL OPINION].
4. Statement by default. A question passes only as the whole reply, when he wants the answer; at most 1 in 4. Rule 4 becomes: one claim about the post's own content that the author can confirm or deny. Drafting starts from what the thread lacks, then checks whether a fact is that thing; never from the fact list. Pass test: a stranger learns something about the post's subject from the reply alone.

## D9 Thresholds
1. Grok: at 1 answer in 54, strict thresholds never pass; raise on "no harm", by 2. Gemini: raise on clear gains, 50 posted minimum.
2. Concede: steps of 2 (Grok); 50 posted (Gemini). Baseline is peers: small accounts replying within 3 h get median 24 [SOURCE: E4 Q3].
3. Reject "1 author reply in 14 days": today's rate passes it.
4. Raise by 2 if posted share ≥70%, median views ≥25, author answers ≥10%, no label. Cut by 2 if median under 10 over 20 replies. Label: pause 7 days, restart at 4. All [MODEL OPINION].

## Agreed
D2, D5, D10: Confirmed. D4: change to 16:00 and 20:30 Israel: 18:30 UTC has 18 fresh uncrowded posts against 11 at 13:00 [SOURCE: E4 Q5]; post within 60 min of the email. D7: change: widening adds queries and authors, never age.

## Final numbers
- D1: ceiling 8 a day, 4 per run; floor 0; +2 per period.
- D2: one bar; Deep by fit.
- D3: under 6 h; 40 replies; 60% authors 1k-20k.
- D4: 16:00, 20:30 Israel; post within 60 min.
- D5: 0 mentions.
- D6: typed; 25 words; paste test.
- D7: floor 0; widen once.
- D8: statements; questions 1 in 4.
- D9: raise at 70% / 25 views / 10%.
- D10: `under_the_hood` weekly.

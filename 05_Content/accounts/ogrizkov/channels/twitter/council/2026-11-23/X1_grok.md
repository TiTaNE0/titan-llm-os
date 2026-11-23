The paste-flag claim is the one I would concede on, so I am checking the published ranker code before I move a number.

The Gemma path does pass the paste flag. I am cutting the answer to the disputed numbers only.

The draft is over the word cap. I am tightening it to the concessions and the numbers.

# Cross-examination: Grok, round 1

## D1 Volume
Claude: 1 Nov's median of 3 is stale parents, and ~110 replies in 14 days separates type from tier. Gemini: 60–80 replies is enough to learn.

Concede 1 Nov. Nine of 15 parents were older than 12 h, median age 17.1 h. [ACCOUNT DATA: E4 Q2c]

Reject 8, 12, and a per-run target. That fresh slice is n=2 per bucket. [ACCOUNT DATA: E4 Q2a] The judge sees "Num Replies Last 24 Hours"; the weight is withheld. [SOURCE: https://github.com/xai-org/x-algorithm/blob/269340ce2e/grox/core/lm/thread.py, 21 Nov 2026]

Ceiling 6/day, 3/run, floor 0, no target, 14 days. Under 40 posted replies, add a run before raising.

## D3 Targets
Claude: the lab replies got 3–22 views, and the rank signal X names is the author answering. Gemini: stay inside 6 h and 40 replies, and cap mega accounts.

Concede the 12 h window and the 2k floor. Medians by delay: 45 (n=7), 24 (15), 18 (9), 7 (5). Authors at 2k–20k answered 9 of 15; above 20k, 1 of 24. [ACCOUNT DATA: E4 Q3] The author who answered him had 1,374 followers. [ACCOUNT DATA: E3 Q2b]

Reject nested as the default. Peer top-level median 25 (n=30) beats nested 9 (n=9); his nested set is six. [ACCOUNT DATA: E4 Q3, Q2b]

Prefer 1k–20k; 20k–150k on the same gates. Land by 6 h (capture ≤4 h), thread ≤40. Over 150k: 1/day, under 2 h, a correction or a number. Nested only to answer a named person. Move the age cap to 8 h only if 4–6 h matches 1–3 h.

## D6 Paste and duplication
Claude: rewording cannot clear an undefined paste flag; type above 250k and test the rest. Gemini: that flag is an input below 250k as well.

Concede. Gemma prints "Reply Was Pasted" via `include_signals=True`. Quote-replies use Grok at any size. The stricter Gemma model runs above 125,000. [SOURCE: https://github.com/xai-org/x-algorithm/blob/269340ce2e/grox/flows/reply_spam/classifier_simple_reply_scorer.py, 21 Nov 2026]

Reject typing every reply. The weight is unpublished, and all 8 drafts from 22 Nov went unposted. [ACCOUNT DATA: E3 Q3]

Retype at ≥125k and on every quote-reply. Below that, 15 typed against 15 pasted, same band. Fact cooldown 30 days. No identical text, and no sentence from the last 14 days.

## D8 Quality gate
Claude: require a point the author can confirm or deny in one line. Gemini: a specific question can be that point, and "I/my" blocks a changelog voice.

Concede the ban on questions. Bier named "direct solicitations for engagement". [SOURCE: https://x.com/nikitabier/status/2034668641304895664, 19 Mar 2026] Question endings were 8/37 vs 7/40; specific questions 5 and 5. [ACCOUNT DATA: E4 Q4]

Reject the question as the lever: the split is delay, 73 min vs 1,225, on a newest-first silent set. [ACCOUNT DATA: E4 Q4] Reject required "I/my": his eight best replies are casual, and one names his work. [ACCOUNT DATA: E3 §6]

A stranger must get one mechanism, number, or boundary the thread lacks. Drop the rest, including a project fact that misses the claim. A question may follow that point. Two "not interesting" reviews fail the gate.

## D9 Measurement
Claude: raise only at ≥70% posted, ≥8% author answers, median ≥20. Gemini: holding 10 passes dull replies on fresh targets.

Concede both. His medians are 42 (3–6 h, n=11) and 70.5 (11–22 Nov, n=10), above 10; answer rate 1.9%. [ACCOUNT DATA: E3 Q2b, Q3]

Reject 15 and a bar of 30. Other small accounts at 3–6 h median 18 (n=9). [ACCOUNT DATA: E4 Q3]

Every 14 days on 1k–20k, ≤6 h, ≤40 replies: +2 at ≥70% posted, ≥8% answers, median ≥20, clean labels. −2 if median <10 or a label appears. Stop a tier at 25 zeros. Cap Clean at 1/day if it trails Deep for two periods.

## D2 Reply types
Confirmed. Deep max 1/day, and only when a fact answers. Clean uses the same bar. No ratio.

## D4 Timing
Change inside the hour: 16:00 and 20:30 Israel. Fresh thin posts median 13 and 18 then, against 11 at 13:00 UTC. [ACCOUNT DATA: E4 Q5] Post within 2 h or skip; drop the weaker slot after 14 days.

## D5 Disclosure
Confirmed. Zero mentions of the pipeline or of AI drafting. His agent work can be a Deep reply's subject.

## D7 Empty or thin runs
Change: a widen keeps the 6 h cap (median 7 views). [ACCOUNT DATA: E4 Q3] Floor 0. One widen, queries and thread size to 80. No email if empty. At 7 of 14 empty, add 22:00 Israel.

## D10 Account risk
Confirmed. Open under_the_hood before run 1. A label means 7 days off, then 2/day.

## Final numbers
D1: Ceiling 6/day, 3/run, floor 0; ±2 by D9; cap 10 until a second good period.
D2: Deep max 1/day on a real fit; Clean the rest; no ratio.
D3: Prefer 1k–20k; land by 6 h; ≤40 replies; over 150k max 1/day.
D4: 16:00 and 20:30 Israel; post within 2 h.
D5: 0 disclosure of drafting.
D6: Retype at ≥125k and on quote-replies; else 15 vs 15; cooldown 30 days.
D7: Floor 0; one widen inside 6 h; no email if empty; 22:00 if 7/14 empty.
D8: One new checkable point or drop; a question only after it.
D9: +2 at ≥70% posted, ≥8% answers, median ≥20; −2 under 10 or on a label; stop a tier at 25 zeros.
D10: Label → 7 days off, then 2/day.

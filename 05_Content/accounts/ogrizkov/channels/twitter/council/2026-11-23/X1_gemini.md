# Cross-examination: Gemini, round 1

## D1 Volume
- **Other seats:** Claude wants 8/day (~110/14d) to test faster before Week 3's 15/day. Grok wants a 6/day ceiling with no target to stop stretching and limit `Num Replies Last 24 Hours` exposure.
- **Concede:** Drop targets (targets caused batch A's stretching [ACCOUNT DATA]) and start at ceiling 6/day; `Num Replies Last 24 Hours` feeds both Gemma and Grok [SOURCE: https://github.com/xai-org/x-algorithm/blob/269340ce2e/grox/flows/reply_spam/classifier_simple_reply_scorer.py, 2026-11-21].
- **Rebut:** Reject 12/day start and Week-3 15/day: on his 15-reply day, his two 3–12h/≤100-reply targets got 3 and 8 views vs 42–4,161 on lighter days (n=2) [ACCOUNT DATA]; ~60–80 replies/14d learns safely [MODEL OPINION].
- **Decision:** Ceiling **6/day** (3 AM/4 PM, floor 0) for 14d; `strategy.md` keeps 2–4 originals/week + this ceiling + max 1/author/day. Ramp +2/day (cap 10) via D9.

## D2 Reply types
**Changed** (M0 arithmetic): drop 45% Deep ratio (exceeds 31 facts). Deep is fit-only (≤1/day, 30d cooldown); Sharp Clean fills remaining slots. Zero obvious replies confirmed.

## D3 Targets
- **Other seats:** Claude targets 500–250k responsive authors (<6h, <50 replies), capping >250k at 2/day (<2h). Grok widens to ≤12h/≤80 replies for supply, preferring top-level.
- **Concede:** To Grok on **top-level over nested** (median 25 vs 9 views, n=30/9) [SOURCE: E4_gap_round1.md, 2026-11-23] and raising my 100k split to **125k**, where a stricter Gemma spam model activates [SOURCE: https://github.com/xai-org/x-algorithm/blob/269340ce2e/grox/flows/reply_spam/constants.py, 2026-11-21].
- **Rebut:** Reject Grok's 12h/80-reply cap: views fall from 45 (<1h) and 24 (1–3h) to 7 (6–12h), while 30 accounts yield 13–18 weekday posts <6h/<50 replies. Reject Claude's 2/day >250k cap: 2k–20k authors answered 9/15 vs 1/24 for 20k–150k [SOURCE: E4_gap_round1.md, 2026-11-23]; lab replies got 3–22 views [ACCOUNT DATA].
- **Decision:** **1k–125k** (prioritize **2k–20k** responsive authors), top-level, capture **≤4h** (post ≤6h), **≤40 replies**; **>125k ≤1/day** (<2h, ≤20 replies). Review by tier/age at 14d.

## D4 Timing
**Changed:** **16:00 & 20:30 Israel** (14:00/18:30 UTC); fresh weekday inventory rises to 13 and 18 (<3h: 5 and 11) [SOURCE: E4_gap_round1.md, 2026-11-23]. Post ≤2h or skip.

## D5 Disclosure
**Confirmed.** Ban covers reply pipeline/AI drafting only, not agentic projects as topic.

## D6 Paste and duplication
- **Other seats:** Claude and Grok retype only >250k to reduce phone friction; Claude tests typed vs pasted <250k, Grok uses a 30d fact cooldown.
- **Concede:** Grok's **30d fact cooldown** (fits 31 facts) and Claude's **A/B test** below strict tiers; `isPasted` trigger logic is unpublished [SOURCE: https://github.com/xai-org/x-algorithm/blob/269340ce2e/grox/core/data_loaders/data_types.py, 2026-11-21].
- **Rebut:** Reject >250k-only retyping: `SimpleReplyScorer` sends `Reply Was Pasted` to Gemma <250k and applies `RiskyHighVizReply` on score 0 [SOURCE: https://github.com/xai-org/x-algorithm/blob/269340ce2e/grox/flows/reply_spam/task_write.py, 2026-11-21].
- **Decision:** Retype **>125k**. Below 125k, run a **14d 50/50 typed-vs-pasted split (~30 each)**; ban pasting if pasted trails >25% or draws a label. Zero duplicates, no 5-word repeat/14d, 30d fact cooldown.

## D7 Empty or thin runs
**Confirmed** (floor 0; 1 widen pass: queries + age ≤8h; no email on 0; audit >20% empty).

## D8 Quality gate
- **Other seats:** Claude requires one-line answerability (often questions) for author replies. Grok bans closing questions to remove AI tells and force standalone points.
- **Concede:** Statements as default—answered and unanswered replies use questions equally (22% vs 18%; 73% statements) [SOURCE: E4_gap_round1.md, 2026-11-23]—and drop my Clean "I/my" rule [MODEL OPINION].
- **Rebut:** Reject Grok's hard ban: Bier targeted "reply X + RT" solicitation, not technical questions [SOURCE: https://x.com/nikitabier/status/2034668641304895664, 2026-03-19]; 8/37 answered replies asked one [SOURCE: E4_gap_round1.md, 2026-11-23].
- **Decision:** Hard-reject deletion-pass, restatement, agreement-only, forced anchor (drop, no redraft), aphorisms/jargon/typos, invented facts; pass needs a concrete edge case, failure mode, or counterexample the thread lacks. Default statements; technical questions **≤25%**, 0 bait. Compare author-answer rates at 14d.

## D9 Measurement
- **Other seats:** Claude prioritizes ≥70% posted share and gates scaling on ≥8% author replies and ≥20 median views. Grok scales +2/day on "no harm" (median holds + ≥1 author reply or 2 follows).
- **Concede:** Claude's **≥70% posted** (0/8 on batch A [ACCOUNT DATA]) and **≥20 median views** (vs 60d median 10 [ACCOUNT DATA]), plus Grok's **+2/day** step.
- **Rebut:** Reject Grok's 1-author-reply bar: over ~60–80 replies that is 1.3–1.7%, below his 1.9% baseline [ACCOUNT DATA], scaling noise [MODEL OPINION].
- **Decision:** 14d cycles (48h check; weekly visits, follows, `under_the_hood`). Raise +2/day (cap 10) if 0 labels, ≥70% posted, ≥8% author reply, ≥20 median. Cut -2/day if <10; 7d pause (restart 2/day) on label. Drop tier/type at 0/25 author replies.

## D10 Account risk
**Confirmed** (check `under_the_hood` pre-launch + weekly; max 6/hour; 7d pause on label).

## Final numbers
**D1:** Ceiling 6/day (3 AM/4 PM), floor 0; +2/day ramp (cap 10); max 1/author/day.
**D2:** Deep (fit-only, ≤1/day) + Sharp Clean; 0 obvious.
**D3:** 1k–125k (prioritize 2k–20k), top-level, ≤4h capture/≤6h post, ≤40 replies; >125k ≤1/day (<2h, ≤20 replies).
**D4:** 16:00 & 20:30 Israel; post ≤2h or skip.
**D5:** 0 pipeline/AI-drafting mentions; agent projects allowed.
**D6:** Retype >125k; 14d 50/50 typed-vs-pasted <125k; 0 duplicates; no 5-word repeat/14d; 30d fact cooldown.
**D7:** Floor 0; 1 widen pass (queries + age ≤8h); no email on 0; audit >20% empty.
**D8:** Hard-reject forced/obvious/restated/AI-tells; require novel technical point; statements default, technical questions ≤25%, 0 bait.
**D9:** 14d cycle (+weekly visits/follows); +2/day if 0 labels, ≥70% posted, ≥8% author reply, ≥20 median; -2/day if <10; 7d pause on label.
**D10:** Check `under_the_hood` pre-launch + weekly; max 6/hour; 7d pause on label.

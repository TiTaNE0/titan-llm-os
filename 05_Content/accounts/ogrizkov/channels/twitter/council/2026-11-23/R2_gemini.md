# Red team: Gemini

## Findings

1. **[Blocker] Compliance collapse baked into the plan** (Summary; §1 A1; §3; §5)  
   Expects 1–2 followers in 4 weeks while exploding workload: from 0.9 replies/day and 5 originals in 60 days (`E3 §2`) to ~3 replies/day in 2-hour windows, retyping half, 31 authority rewrites, 26 marks, pinned-post swap, 2 originals/week (added in A1 unvoted), same-day follow-ups, weekly logs, and an "own" arm. Expect week-2 abandonment.  
   **Fix:** Drop 2 originals/week and the "own" arm in Period 1; keep only the pinned-post swap and 20:30 Israel run.

2. **[Blocker] Rule 11 and Clean Rule 7 perpetuate "not interesting" AI slop** (§1 D2, D8; §2 Rules 7, 11; §5; §7)  
   He rejected 8/8 batch-A drafts though #3, #4, #7, #8 were concise and specific (`ctx_batcha`). Web-sourced claims he never read (Rule 7) create pedantic replies he cannot defend when authors answer (§5). Rule 11 uses two LLMs to judge interest and ships when one says "nothing."  
   **Fix:** Reject if *either* reviewer says "nothing." Ban web-sourced claims he cannot vouch for. Ship target + 1-line angle + optional 15-word starter for his own voice (every >90-view reply, `E3 §6`).

3. **[Blocker] D6 TYPE-vs-PASTE test is confounded and invites an `llm_slop` ban** (§1 D6; §2 Length; §3 Q3; §5)  
   Alternating TYPE (his words, ≤25w) vs PASTE (verbatim AI, ≤40w) confounds `is_pasted`, AI prose, length, and voice—proving nothing. Pasting 30 AI drafts in X's most policed niche (`E1 #8, #18`; `E2 #17`) risks `llm_slop_user`. Papers over Claude ("type all") vs Grok ("compliance").  
   **Fix:** End verbatim AI pasting; test identical human-edited text (typed vs pasted) or retype all.

4. **[Blocker] Silent empty runs violate operator position 2 and mask outages** (§1 D7; §2; §4 E25; §7)  
   Sending no email on zero passes overrules `00_BRIEF §3.2` and masks crashed crons or broken Grok keys as empty runs (`SCHEDULED_RUNS_ISSUES.md`). Claude's "relax nothing" widen plus 10% alarm guarantees starvation—especially at 16:00 Israel (median 5 fresh posts across 30 accounts, `E4 Q5`).  
   **Fix:** Keep emails reply-only, add an out-of-band failure/empty heartbeat, drop 16:00 until supply is proven.

5. **[Major] Unexplained 10x–300x reach collapse and unattributable Q4** (§1 A1; §3 Q4; §6)  
   Nobody asked why originals plunged from 235–13,362 views in May to 3–38 in Oct–Nov (`E3 §2`)—possible pre-existing throttling. Meanwhile, Q4 credits profile visits (`0.25/reply`) to replies while A1 simultaneously swaps the pinned post and adds 2 originals/week, breaking attribution.  
   **Fix:** Audit May-vs-Nov originals and check `under_the_hood` first; freeze originals in Period 1.

6. **[Major] Opinion worded as fact and statistical theater** (Summary; §1 D3, D10; §3 Q1–Q2; §9)  
   "1–2 followers" and "replies earn visits, profile converts" are stated as fact from two vendor blogs (`E1 #28, #30`; ignoring `E2 #23`). §9 calls 3.5 h "derived" though 6 h is opinion (`E4 Q3` n=5 in 6–12 h). D10 calls AI slop *the* known danger while `Num Replies 24h` and `is_pasted` weights are withheld (`E1 #6`). §3's binomial test misuses heterogeneous 1/54 history; §9's "4–8% misfire" hides heavy-tail assumptions (`E3` median 10, max 4,161).  
   **Fix:** Tag all forecasts, cutoffs, and risk rankings `[MODEL OPINION]`; cut unverified power math.

7. **[Major] Papered-over seat splits and hard-rule tension** (§1 D1, D3–D5; §3; §6)  
   D1 caps at 6 (vs Claude's 8) yet §3 needs ≥40 posted/14d and 60 non-large replies/28d, proving Claude's underpowering dissent. D3 sets "large" at 125k though Grok/Gemma splits at 250k (`E1 #5`), weakening Claude's "answering habit" filter to an undefined sort. D4's 2-hour window contradicts `E4 Q4` (median 73 min). D5 stretches "never invent facts" (`00_BRIEF §1`) into "never deny AI drafting"—a confession trap—while his bio keeps "promote, and grow."  
   **Fix:** Match gates to ceiling 6, set large tier to 250k, define answering habit (≥2 replies/10 posts), cut "promote, and grow" from bio, drop "never deny."

8. **[Minor] Arbitrary constants and missing plumbing** (§1 D8; §2; §3; §7)  
   Arbitrary: **21/26** calibration (imbalanced sets let "reject all" pass—tie to ≥80% precision on "would post"); **5-word reuse/14d** (flags normal phrasing—tie to ≥0.75 cosine similarity); **40/25w caps** (tie to `E3` p90); **30d cooldown / 1 Deep/day** (tie to per-author/7d dedupe); **≤25% questions** (`E4 Q4`: 22% vs 18%—ban bait only); **5-weekday replay** omits weekends (`E4 Q5`). Missing: Grok's 10-post cap dropping logged replies (`E3 §9`) and spam-folding checks (`E3 §8`).  
   **Fix:** Tie constants as above, add weekend replay, paginate wins-logging, check 5 replies/week logged-out for spam folding.

## The one change that matters most

**Stop emailing verbatim AI drafts to paste; deliver fresh (<90 min), high-answer-rate threads with a 1-line angle for him to answer in his own words.** Every >90-view reply used his voice (`E3 §6`), verbatim pasting is his biggest `llm_slop` ban risk (`E1 #8, #18`), and human phrasing fixes "stretched" and "not interesting" while cutting compliance friction.

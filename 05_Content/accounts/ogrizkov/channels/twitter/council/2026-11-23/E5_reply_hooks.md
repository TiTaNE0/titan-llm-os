# E5. Reply hooks: what winning replies look like in the niche (live data, 2026-11-23)

Role: research analyst. Evidence first; lines marked **Opinion** are the analyst's reading. Examples are described, not quoted. Every reply text, outcome and code is in `raw/H_coded_replies.jsonl`.

## 1. Method

- **Threads.** Three grok discovery calls (X search by day, 2-21 Nov, `min_replies:8`, niche topics) gave 42 threads; 9 came from E4. Rules: 8-80 replies, author with 1,000-125,000 followers, at least 2 days old. One was too fresh, 3 were off-topic polls. **47 threads** remain: authors with 1,454-94,557 followers (31 threads at 1k-20k, 16 at 20k-125k), posts with 311-379,130 views; 17 findings, 10 opinions, 9 build logs, 6 questions, 4 results, 1 other (grok's labels).
- **Replies.** Six grok mining calls returned 61 rows. Then grok stopped: "402 Payment Required: Grok Build usage balance exhausted". Three calls died, four never ran. The rest came from the public endpoint `api.fxtwitter.com/2/conversation/<post id>`, a lookup service grok itself used. Check: 58 of the 61 grok rows were in it with matching views (within 2%), likes, followers, delay and author-answer flag; the 3 it lacked were added.
- **Population.** 868 English top-level replies by accounts under 5,000 followers.
- **Winner** = 500+ views, or 5+ likes, or the author answered: 253 of 868 (57 by views, 22 by likes, 222 answered). **Control** = under 50 views, under 5 likes, not answered, same thread as a sampled winner, posted within a factor of 3 (or 120 minutes) of a sampled winner's delay.
- **Coded sample.** Up to 5 winners and 3 controls per thread, picked by a hash of the reply id: **125 winners (37 threads), 69 controls (28 threads).** The 17 other replies with 500+ views or 5+ likes were coded afterwards, so all 61 "reach" replies and all 22 replies with 5+ likes are covered.
- **Coding.** One analyst coded each text before the outcome was joined. About 55 outcomes had been seen earlier in grok's output; the 17 added rows were coded with the outcome visible. Two moves were added to the brief's list: a bare answer to a poll-type post, and asking for the material (prompt, playbook, recording). Author answers were coded as substantive (information, argument, a question back) or courtesy (thanks, emoji, short agreement).

## 2. Before any wording: timing, thread, replier (all 868, counted by script)

| Delay after the post | n | Median view rank in thread (0-100) | 500+ views or 5+ likes | Author answered, selective threads |
|---|---|---|---|---|
| under 30 min | 119 | 80 | 8 (7%) | 16 of 42 (38%) |
| 30-120 min | 153 | 62 | 23 (15%) | 19 of 69 (28%) |
| 2-6 h | 174 | 56 | 14 (8%) | 8 of 80 (10%) |
| 6-24 h | 353 | 40 | 16 (5%) | 18 of 143 (13%) |
| over 24 h | 69 | 12 | 0 | 0 of 27 |

"Selective threads": the 19 threads where the author answered some, but under half, of these replies. In 10 threads the author answered half or more; in 18, nobody.

- **Length.** Answered in selective threads: 18% under 10 words (21 of 114), 18% at 10-25 (22 of 119), 18% at 26-40 (14 of 80), 8% over 40 (4 of 48). Reach replies: 7%, 9%, 6%, 3%.
- **Thread size decides reach.** 59 of the 61 reach replies sit under posts with 20,000+ views. Under smaller posts: 2 of 400.
- **Author size decides answers.** Authors with 1k-20k followers answered 212 of 512 replies (41%) in threads where they answered at all; authors with 20k-125k, 10 of 89 (11%).
- **Replier.** In selective threads Blue accounts were answered 18% of the time, others 10%. Under 100 followers 12%; 100-999, 16%; 1,000-4,999, 23%.
- **Question mark.** Replies ending in "?" were answered 15 of 67 times (22%) in selective threads; statements 46 of 294 (16%).
- **Media and links.** 6 of 13 replies with media were reach replies; 6 of 31 with a link (19%, against 7% without).

## 3. Moves: winners against controls

Share ratio = share among the 125 winners divided by share among the 69 controls. Groups under 10 carry *.

| Move | Winners | Controls | Share ratio | Of 61 reach replies | Of 22 most liked | Author answers with content |
|---|---|---|---|---|---|---|
| Practitioner question | 28 | 11 | 1.4 | 13 | 3 | 19 of 23 |
| Short reaction or praise | 26 | 10 | 1.4 | 14 | 5 | 2 of 19 |
| Missing step or tip | 15 | 13 | 0.6 | 4 | 2 | 10 of 13 |
| Bare poll answer (other) | 14 | 8* | 1.0 | 0 | 0 | 5 of 14 |
| Joke or quip | 10 | 7* | 0.8 | 10 | 5 | 1 of 7 |
| Restating the post | 9* | 8* | 0.6 | 2 | 0 | 6 of 9 |
| Own result or number | 7* | 4* | 1.0 | 7 | 5 | 3 of 6 |
| Resource pointer | 7* | 0* | n/a | 5 | 2 | 0 of 3 |
| Counter-example or disagreement | 5* | 3* | 0.9 | 3 | 0 | 3 of 4 |
| Asks for the material (other) | 4* | 0* | n/a | 3 | 0 | 1 of 1 |

Own failure story 0/2, other 0/3. Correction with a source: not found.

- Delay still differs: median 64 minutes for winners, 285 for controls. In the subset posted 30 minutes to 24 hours after the post (83 winners, 61 controls) the picture holds: question 2.1, reaction 1.6, tip 0.4, restating 0.55.
- Tips by length: 40 words or fewer 12/6; over 40 words 3/7.
- Own results by length: 25 words or fewer 4/0; longer own stories plus failure stories 3/6.
- Disagreement by tone: calm and specific 5/0; mocking or blunt 0/3.
- By post type: questions on build logs 14/5, on findings 9/5; tips on opinion posts 6/2, on build logs 1/3; disagreement on result posts 3/0.

## 4. Openings and form

| Opening (first five words) | Winners | Controls | Share ratio |
|---|---|---|---|
| Question word first | 19 | 7* | 1.5 |
| Action or tip word first | 9* | 2* | 2.5 |
| Quip lead-in | 4* | 0* | n/a |
| Praise word first | 14 | 6* | 1.3 |
| First person first | 10 | 7* | 0.8 |
| The post's own term, then a verdict on it | 25 | 20 | 0.7 |
| Pushback word first | 1* | 5* | 0.1 |

- Near 1 and small: tool name as the answer 10/5, agreement word 6/3, number first 5/4, other 22/10.
- The verdict opening is the most common opening among controls. Counting only reach winners and answers in selective threads: 13/15 (0.5). Under one post two accounts wrote near-identical verdict replies: 6 and 5 views.
- Form: statement 88/55 (0.9), question 24/9 (1.5), statement then question 13/5 (1.4).
- Coded length: under 10 words 42/21 (1.1), 10-25 47/20 (1.3), 26-40 25/16 (0.9), over 40 11/12 (0.5). The 61 reach replies: median 13 words, 3 over 40.
- Names something specific from the post: yes 80/47 (0.9), no 45/22 (1.1). No edge for a win, but 43 of the 50 substantive author answers went to specific replies.
- Own project named 5/5 (0.55); own experience without a project 13/10 (0.7); closing maxim 8/6 (0.7).

## 5. His eight best replies (E3 section 6), same coding

Five are short reactions or praise (4,161, 266, 172, 119 and 95 views). Two are own-experience remarks (205; 149 with media and his project). One is a question to @grok (156). Six are under about 12 words. None is a question to the author; none is a tip. By this study's rule two are winners: the 4,161-view reply, nested in a 2-million-view thread, and the one the author answered. None is from the label week, whose replies say nothing about wording. His best replies match this sample's reach winners: a short reaction in a large or lively thread.

## 6. Where the data contradicts or fails to support DECISION.md

1. **Agreement-only is banned (gate rule 3), yet short reactions win here as often as anything:** 26 of 125 winners, 14 of 61 reach replies, 5 of the 22 most liked. But 17 of 19 author answers to reactions were a thank-you or an emoji. The ban rests on that and on account risk (decision section 11), not on views.
2. **"Statements by default, questions at most 1 in 4" is not supported.** Questions are 30% of winners and 20% of controls, and 19 of 23 author answers to them had content. E4 found the same direction, smaller. Period 1 counts author answers; the question is the move that earns them.
3. **The Clean type's core move, one checkable point the thread lacks, is the most common move among controls** (13 of 69; ratio 0.6). It holds at 40 words or fewer when it leads with the new fact.
4. **Specificity (gate rules 1 and 4) does not separate winners from controls** (64% against 68%). It separates real answers from thank-yous.
5. **Deep is not a premium type here.** Own project named: 5/5. Only the short tried-it report stands out (4/0; own results are 5 of the 22 most liked).
6. **The landing window is late.** Capture at 3.5 hours plus up to 2 hours to post lands in the 2-6 hour band: 10% answered, against 38% under 30 minutes. The Gemini red team said the same.
7. **Tier 1 targets cannot give reach.** Under posts below 20,000 views 2 of 400 replies became reach replies. There the only realistic win is an author answer.
8. **Supported:** the 40-word cap (25 or fewer is safer), small authors first, no restating, no aphorisms (weakly).

**Opinion:** wording is the smaller lever. Thread choice and delay move the numbers by a factor of 3 or more; no hook moves them by more than about 1.5, on groups this small.

## 7. Hooks found

Seven, in `reply_patterns.md`, winners/controls: question first on one concrete detail 17/7; one noticed detail then the question 12/5; the new fact or check first in 40 words or fewer 12/6; a tried-it result in 25 words or fewer 4/0; the calm limit of the claim 5/0; the source the thread is missing 4/0; one dry line 4/0. The last four rest on groups under 10. Losing patterns: sections 3 and 4.

## 8. Limits

- One snapshot: totals on 23 November, posts 2 to 21 days old.
- Neither source sees every reply. Grok's search returned as few as 2 of 45; the endpoint returned 21 of 45 on one thread and missed 3 replies grok had. Spam-folded replies may be absent, which would hide the worst losers.
- 222 of the 253 winners win by an author answer; 45 of the 99 answered winners in the sample come from threads where the author answers most replies.
- One coder, no reliability check, no significance test. Ratios on groups marked * are illustrations.
- Threads came in grok's search order; five are poll-type questions.
- "Attention" means views, likes and author answers. Profile visits and follows cannot be seen from outside.
- Associations, not causes.

## 9. Files

Prompts in `prompts/`; answers in `raw/`, same name plus `.out.txt`.

- Discovery, ran: `H_d1_threads_1102_1108`, `H_d2_threads_1109_1114`, `H_d3_threads_1115_1121`.
- Mining, ran: `H_m01` to `H_m06`.
- Died on the balance error: `H_m07`, `H_m08`, `H_m09`. Written, never run: `H_m10` to `H_m13`.
- Endpoint data: `raw/H_fx_threads.jsonl` (50 threads), `raw/H_fx_population.tsv` (868 replies, numbers only), `raw/H_coded_replies.jsonl` (211 replies with text, outcome and codes).

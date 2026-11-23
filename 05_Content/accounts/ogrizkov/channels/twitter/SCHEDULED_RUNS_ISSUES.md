# Scheduled reply pipeline: issues, incidents and risks

Living log for the twice-daily scheduled run (desktop task `twitter-reply-pipeline`, 08:00 + 18:00, TARGET=5, drafts emailed via Mail.app on the Mac, iCloud → iCloud `evgeniy.ogrizkov@icloud.com`).
Purpose: input for an agent-team review of how to make this process reliable and cheap.
Runbook: [[skill/twitter-reply-orchestrate]] · overview: [[PIPELINE_OVERVIEW]].

**Operator requirement (2026-11-22):** the only email he ever gets contains real, gate-passed replies with exact post links. No error, status, halt or "nothing found" mail. Failures must be detected and fixed locally by agents (retry, fallback, resume). The setup must work unattended, as if on a 24/7 server.

---

## 1. Incidents (what actually went wrong)

| # | Date | What happened | Root cause | Cost / impact | Status |
|---|------|---------------|-----------|---------------|--------|
| I-1 | 2026-11-22 18:11 | First scheduled run (the 18:00 slot; the 08:00 slot was before the task existed) halted at the agy probe before any work. | Critic pinned to `Gemini 3.1 Pro (High)`, which agy no longer offers. The 2026-11-01 batch had already run on `gemini-4-argon-high` under manual operator authorization, but the pins in roster/critic/runbook/constraints/overview were never updated, and `verify_gemini_swap.sh` asserted the old name, so the check stayed green on a dead model. | 1 grok call, one lost slot (no drafts), 1 noise email. | Fixed: repinned to `Gemini 4 Neon (High)` (b8ceefa). |
| I-2 | 2026-11-22 | The halt was emailed to the operator as raw HALT.json. | Design error by the setup agent: it built a "halt email" path although the operator only wants replies. Not verified visually before shipping. | Operator annoyance and trust loss ("why send this at all"). | Fixed: the script refuses to build any email without real drafts; the halt path was removed (c3440d7). |
| I-3 | 2026-11-22 | The runbook still passed `--dangerously-skip-permissions` to agy. The Claude Code auto-mode classifier blocks it, so even a correct model would have failed at 18:00. | Known since 2026-07-13 (memory) but never removed from the runbook; the verify script *required* the flag. Knowledge in memory ≠ change in files. | Would have caused a second lost slot. | Fixed: flag removed, 4 verify checks inverted (b8ceefa). |
| I-4 | 2026-11-22 | The setup agent first recommended `Gemini 4 Argon (High)` from a stale model list saved in the morning probe output; the operator flagged that Argon may be gone. | A model being listed was treated as proof it works. | Nearly a wrong repin. Both Argon and Neon answered a real probe on 2026-11-22. | Rule: always `agy models` + a real fenced-JSON probe before pinning. |
| I-5 | 2026-11-22 | Email delivery went through 3 designs: Mail.app/iCloud to the wrong address, then Gmail; the sepia background was stripped by the Gmail mobile app (div backgrounds) and needed table/bgcolor markup. | Setup agent did not ask for the sender/recipient up front and did not use email-safe HTML from the start. | 5 test emails sent (Mail.app full, Gmail full, links preview, sepia v1, sepia v3). | Fixed; layout approved. |
| I-6 | 2026-11-22 | `run_scheduled_task` ("Run now") was blocked by the Claude Code classifier on the first try; it went through after the operator explicitly asked again. | Classifier treats starting an unattended Auto-mode session as risky without explicit user intent. | Delay; operator had to intervene. | Open: consider a permission rule for this tool. |
| I-7 | 2026-11-22 18:29 | Extra manual test run (`local_74957ca9…`, batch `2026-11-22_batcha`) right after the failed 18:00 slot. | Needed to prove the fixes end to end. | One extra full run of spend (no overlap: next slot is 08:00). | Result: see §4. |

| I-8 | 2026-11-22 19:09 | In the Gmail iOS app, post links open as `https://www.google.com/url?q=https://x.com/...&source=gmail&ust=...` and land in a browser, not the X app. | The Gmail client wraps every http(s) link in its redirect at render time; the sent HTML is clean (verified). The redirect breaks iOS universal links into the X app. Setup agent did not test link-tap behaviour on the phone. | Operator cannot tap straight into X; the core use of the email fails. Tried `twitter://status?id=<id>`: the Gmail app strips non-http links, so the button is dead (19:11). Gmail app cannot open X directly; needs a different reading client or delivery channel. 19:2x: the operator chose the iPhone Mail app; batcha resent to the iCloud address for a test. Setup agent changed the schedule recipient before the test was verified; the operator stopped it and it was reverted the same minute (process lesson: no config change before the operator confirms the test). iPhone Mail test: links still arrived wrapped, so the wrapping happens on the Gmail send side, not only in the Gmail reader. Next test: iCloud → iCloud via Mail.app on the Mac (the first attempt went out with an EMPTY body because of a wrong relative path, the setup agent's error; v2 resent with the real body). v2 confirmed by the operator: a tap opens the post in X. Fixed: `email_replies.py --send` now sends iCloud → iCloud via Mail.app; the Gmail connector is no longer used. |
| I-9 | 2026-11-23 08:37 and 18:35 | Both scheduled runs reported "email sent, exit 0", but the operator received nothing. The messages sat in Mail's Drafts and Outbox behind a sheet: "This message could not be sent because your account does not have a preferred outgoing mail server". The operator saw Mail asking for something, did not understand it and closed it. | `email_replies.py --send` treats osascript exit 0 as delivered; Mail accepts the message and fails later, with a modal sheet nobody sees in an unattended run. Why the iCloud account lost its preferred outgoing server since the successful sends on 2026-11-22 is unknown. The setup agent then told the operator the send "worked" from the run's own summary, without checking Sent. | Two slots delivered nothing (11 drafts), silently. The hard requirement (he always gets the result) failed with no signal. | Fixed 2026-11-23 19:54: the operator clicked "Always Use This Server" (iCloud); the stuck 18:00 email went out and arrived at 19:54, the 08:00 batch was resent by the script and arrived at 19:56 (both checked in Sent and Inbox); the two leftover drafts were moved to Trash. Why the setting was lost is still unknown, so it can recur. Rebuild: delivery counts only when the message is in Sent and the Outbox is empty; otherwise exit 4, retry, and write an alarm line. |
| I-10 | 2026-11-23 evening | Two limits hit in one day. The grok CLI returned "402 Payment Required: Grok Build usage balance exhausted" during the hook study; the planner then stopped on the Claude account's 5-hour usage limit (resets 01:00). | One day of councils, audits and studies on the largest model, with paged grok calls, and no budget set in advance by the setup agent. | No grok call works until the balance is restored; the rebuild cannot continue before 01:00. The operator: grok is on a mid-tier subscription, use it only when really necessary. | Open. Pipeline design changes in `council/2026-11-23/PENDING_SPEC_REVISION.md` section B (grok only for discovery, at most 3 calls per run, public endpoint for reads). |

## 2. Quality defects seen in output

| # | What | Where | Note |
|---|------|-------|------|
| Q-1 | `isn;t` / `aren;t` in drafts. | 2026-11-01 #2, #3; batcha #6 | NOT a defect: deliberate register texture per `reply_register.md:32` and `drafter.md:41`. Setup agent wrongly flagged it; the Producer sub-agent also flagged it as an "encoding artifact". Open question: the Producer's own context does not know the register, so it raises false alarms. |
| Q-2 | Internal jargon in a shipped draft (`E1-E5 classes`, `macro`). | 2026-11-01 target #9 | Already noted as a "Known gap (proposed v3.2)" in AGENTS_CONSTRAINTS.md. |

| Q-3 | Drafts read as AI (batcha, 2026-11-22). Grok review: 4/8 AI (#1, #3, #6, #7). Independent Fable review (not shown Grok's verdict): 0/8 clearly his voice, 5 mixed, 3 AI (#1, #3, #6). Both agree on #1, #3, #6. The Critic SHIPped all 8 with voice_fit 0/9 fails, so the Critic does not catch this. | batcha #1-#8 | Systematic causes (verified): (1) Drafter pastes anchor-entry phrasing ("token-budget cap with explicit drop priority", "strictly-scoped delta" are near-verbatim from 01_anchored.json); (2) subagent-less headline compression: 4/8 one-line, no "I + verb"; (3) cosmetic texture only (6/8 dropped final period) on native-clean grammar; (4) internal jargon unglossed (E1-E5, vault files); (5) engagement question in #6, which voice.md:53 bans. Root conflict: voice.md:61 says he drafts first and AI polishes; the pipeline generates from scratch, so ESL rhythm has no real source. Proposed: paraphrase gate (≤3 words verbatim from anchor), stranger-legibility gate, shape variety (≤2 subjectless one-liners per batch, no aphorisms), cap each texture tic at 2 per batch; or a 5-word operator seed per target that the pipeline polishes. |

| Q-4 | Replies are boring and forced (operator, 2026-11-22): "a real piece of my work is taken and stretched hard onto the post's topic just to have something to comment on; the comments are simply not interesting." This is the main quality problem, above voice (Q-3). | batcha #1-#8 | Suspected cause: Matcher binds any vault entry with some topical overlap, and the Drafter must use it, so the reply is about his project, not about the author's point. No gate measures whether the reply adds something the author or readers would care about. Operator goal: replies that are genuinely interesting to read. |

## 2c. Account state

| # | What | Evidence | Note |
|---|------|----------|------|
| A-1 | The account carried the X label `SpamHighRecall` ("posts are hidden from recommendations to non-followers") on 1 day of October 2026. | Operator's X report `runs/_analytics/under_the_hood/2026-10.json` (generated 2026-11-07). In the published X rules every `SpamHighRecall` rule lasts 7 or 30 days (`abuse-enforcement-service/service-lib/rules/enforcement_user.yaml`, fetched 2026-11-23), so the 1 October day is most likely 31 October, the start of a 7-day label. Views agree: 24-30 Oct 22 replies, median 22; 31 Oct - 6 Nov 20 replies, all 8 views or fewer; 7-22 Nov 10 replies, median 70.5 (`council/2026-11-23/raw/E3_q2*`). | Inference, not proof: the report gives no date and the trigger is unpublished. It followed a jump from near zero to 5-9 replies a day (27-30 Oct), all written by him (no pipeline draft was posted before 1 Nov). All six pipeline drafts posted on 1 Nov fell inside the label week, so their 2-6 views say nothing about draft quality. The November report should show about 6 labelled days if this reading is right. Decisions: `council/2026-11-23/DECISION.md` section 11. |

## 2b. Performance

| # | What | Evidence | Note |
|---|------|----------|------|
| P-1 | One run takes 35+ min; grok calls dominate. | batcha telemetry: scout calls 342 s each; thread fetches 342 s and 513 s; critic (Neon) 274 s + 136 s retry. | Scout and thread-fetch calls look sequential. Candidate fix: run vector fetches in parallel and batch thread fetches. Self-heal (3 attempts) could push one slot to 2-3 h. |

## 3. Risks: what can still go wrong unattended

**Infrastructure / host**
- R-1 Mac asleep or Claude app closed at slot time → run is late (runs on next launch). Only a 07:50 wake is set; no wake for 18:00. Moving to a 24/7 host removes this but needs grok, agy and Gmail auth there.
- R-2 iCloud Drive sync of the vault (`Mobile Documents`) during a run → file conflicts or half-synced artifacts.
- R-3 The scheduled run uses whatever branch is checked out. Fixes were merged to `main` and pushed on 2026-11-22 (102884b), but any other checked-out branch at slot time still runs that branch's files.

**External dependencies**
- R-4 agy model churn: Google renames or removes models without notice (happened in under 3 weeks). Mitigation: the scheduled prompt has a fallback ladder Neon → Argon → Hydrogen → 3.8 Flash, probing each first.
- R-5 grok CLI auth, credits, or rate limits; X search returning few or no fresh discussions.
- R-6 Delivery depends on Mail.app on this Mac: Mail must be configured with iCloud, macOS automation permission for osascript → Mail must stay granted, and the Mac must be online (offline = message sits in Outbox). On a 24/7 server this needs a different sender (iCloud SMTP with an app-specific password); do not move to Gmail (link rewriting, I-8).
- R-7 Claude Code auto-mode classifier blocking new actions in unattended runs (seen twice: I-3, I-6). The osascript → Mail send has not yet been exercised inside a scheduled run.

**Process / design**
- R-8 Silent failure by design: the operator gets no email on failure, so a broken pipeline can go unnoticed for days. Only signal: `runs/_index/scheduler_log.md`. Needs a check that is not an email to the operator (e.g. an agent reads the log on the next run and escalates only after N consecutive empty slots?).
- R-9 Two sources of truth: the runbook says SAVE-AND-HALT and forbids model substitution; the scheduled prompt overrides both (self-heal, fallback ladder). They can drift. Decide whether self-heal belongs in the runbook.
- R-10 Cost: self-heal allows up to 3 attempts per slot, so worst case is about 3× a normal run, twice a day. No cost cap or telemetry alert on spend.
- R-11 Critic quality can degrade down the ladder (3.8 Flash is a weaker judge). Calibration probes guard against a blind SHIP but not against a weaker fair judge.
- R-12 Overlapping runs (manual run plus a slot, or a slot running past the next one) → duplicate targets or reused threads across batches.
- R-13 Stale search vectors (generated 2026-11-01, past the 7-day TTL) → Vault_Scout regen adds time and cost to the first run.
- R-14 Email depends on the `replies_to_post.md` format. If the Producer changes the format, the parser finds 0 drafts and the run self-heals into extra attempts for nothing.
- R-15 Dark mode on the phone may recolor the sepia email (client behaviour, cannot be forced).

## 4. Run log

| Run | Trigger | Outcome | Critic model | Shipped | Email | Notes |
|-----|---------|---------|--------------|---------|-------|-------|
| 2026-11-22_batch | 18:00 slot (started 18:11) | HALT at probe | (3.1 Pro, dead) | 0 | noise halt email (I-2) | I-1, I-3 |
| 2026-11-22_batcha | manual test, session `local_74957ca9…`, 18:29-19:02 | OK | gemini-4-neon-high (no fallback) | 8 (TARGET 5) | Gmail sent; links wrapped by Gmail (I-8); resent via iCloud | 57 candidates → 9 bound → 8 shipped; calibration 2×2 probes pass; ~33 min, grok-bound (P-1) |
| 2026-11-23_batch | 08:00 slot (started 08:11), session `local_7afb939a…` | OK, first attempt | Neon | 6 | sent via Mail.app iCloud → iCloud, exit 0 | First scheduled run with the Mail.app send: it works unattended (closes the open part of R-7). Old rules. |
| 2026-11-23_batcha | 18:00 slot (started 18:11), session `local_1c136bad…` | OK, first attempt | Neon | 5 | sent (run reported success) | Old rules. 11 drafts emailed in one day. |
| (schedule) | 2026-11-23 evening | Scheduled task disabled by the operator's decision | n/a | n/a | n/a | Old 08:00 and 18:00 runs stopped until the v3.2 rebuild passes its launch gates; the rebuild edits the live files in place. Re-enable only with the new prompt, after a test email is confirmed. |

## 5. Questions for the agent-team review

**Panel ran 2026-11-22:** consolidated edit plan, conflicts and verbatim reports in [[REPLY_QUALITY_REVIEW_2026-11-22]]. Questions 1-7 below are answered there.

1. Should self-heal and the critic fallback ladder move into the runbook as the single source of truth?
2. How should a silently failing pipeline be noticed without emailing the operator (R-8)?
3. Is a 24/7 host worth it now? What does grok, agy and Gmail auth look like there?
4. What is the cost cap per slot and per day? Where does spend telemetry go?
5. Should `gate.sh` catch typos like `isn;t` (Q-1) and internal jargon (Q-2)?
6. Should pins (models, flags) be checked against the live CLI by a preflight instead of grepping docs (lesson from I-1/I-3: the verify script tested the docs, not reality)?
7. Which Q-3 voice gates to adopt (paraphrase ≤3 words from anchor, stranger-legibility, shape variety, texture-tic cap), and is a 5-word operator seed per target worth the manual step? Why did the Critic pass voice_fit on all 8, and should its mandate change? (Operator deferred these to this review on 2026-11-22.)


---

## Appendix A. Fable voice review of batcha, full report (2026-11-22, verbatim)

Independent read-only review by a Fable subagent; it was not shown Grok's verdict. Source for Q-3.

Read-only review; no files touched. Sources: voice.md, reply_register.md, plus thread gists and anchored facts in runs/2026-11-22_batcha/ (00b_threads.json, 01_anchored.json).

Overall: 0 of 8 clearly sound like him; 5 mixed, 3 read as AI. The facts are good, the sentences are the problem.

## Per draft

**1. Sumanth_077: reads as AI.** "Injection has a token-budget cap with explicit drop priority" is the anchor entry copied almost verbatim, a spec-sheet noun stack. "does this from the other side" is an abstract connector, "instead of loading everything available" a tidy contrast clause, and "Our" is wrong for a solo builder. Legibility: poor ("Injection" of what?).
Rewrite: `I do the same at session start. Context has a token cap and a priority what to drop first, then a check before any work starts. Never load everything available`

**2. martynov014: mixed.** The comma-splice and the admitted gap sound human. "E1-E5 classes" means nothing to a stranger.
Rewrite: `Hooks only check what you wired in. My error classes E1-E5 are written in the rules and still not wired`

**3. DanielSmidstrup: reads as AI.** "Pre-prod audit blocked deploy:" plus a noun list is a commit message: no subject, and it does not answer "what do you use". Legibility: fair.
Rewrite: `Pre-prod audit for me. It blocked a deploy, confidence was hardcoded to 100%, demo mode left in`

**4. itsscatto: mixed.** The rhythm is his. "by backend, 1x versus 25x" is unreadable: which backend costs what?
Rewrite (local/premium labels come from the anchor entry, not the draft): `Caps aren;t the only way, weight credits by which backend serves the request. Local model 1x, premium API 25x`

**5. kevinlu310: mixed, closest to him.** The stacked run-on matches his Kimi pattern, and "nobody overwrote anyone's work" is human. "each fed a strictly-scoped delta" and "merged at 100% coverage" are lifted from the anchor entry. Legibility: fine.
Rewrite: `Point 2 held on my iOS localization, 3 background sub-agents, one per locale, each got only its own delta. 2,253 translations merged, 100% coverage, nobody overwrote anyone's work`

**6. nateherk: reads as AI.** It follows the template restate, my setup, question. "are what compaction loses" is an aphorism built from another replier's point. The closing "do you write the reasons down anywhere outside the session?" is a bolted-on engagement question, which voice.md bans. " - " is the tic applied mechanically, and "vault files" is internal jargon.
Rewrite: `Compaction loses the reasons why a branch was killed, not only the details. I keep decisions in files, not in chat, so compacting earlier costs me little`

**7. yeemio: mixed, leaning AI.** "Hash can't judge, so the judge should..." is wordplay with a prescriptive "should", a commentator's line with no build behind it. The "so" does not follow. Legibility: fine.
Rewrite: `Hash can't judge. For that part the judge should at least come from another model family`
The anchor says his own critic runs on a non-Claude model; saying that would fix the voice, but it is not in the draft.

**8. sristhi_saha: mixed.** The specifics are good, but it is a subjectless headline. "30-50% for weeks" drops "of the time", a meaning-break by voice.md's own definition.
Rewrite: `Mine was lat/lng rounded to 3 decimals. It missed the nearest address 30-50% of the time, for weeks`

## (a) Systematic tells
1. **Anchor-entry phrasing pasted in.** Noun stacks and participles ("token-budget cap with explicit drop priority", "strictly-scoped delta", "Pre-prod audit blocked deploy") replace "I + verb".
2. **Telegram compression.** Four of 8 (2, 3, 7, 8) are one-line subjectless headlines or aphorisms. Articles are dropped changelog-style, not the Russian way. There is no hedge and no reaction to the person.
3. **Cosmetic texture on native-clean grammar.** Six of 8 drop the final period, with exactly one `;` and one ` - `. There are no typos, no lowercase, and no ESL word order anywhere.

## (b) Where the docs fail
- reply_register.md covers punctuation and casing only, nothing on syntax. "Reach for... dropped final period more often" produced the 6-of-8 sameness its own guardrail calls the tell.
- "Never touch the signal... `E1-E5` stays" protects internal labels, and the specificity gate rewards verbatim anchor terms. Together they encourage tells 1 and the jargon.
- voice.md's "stack specifics" and "land flat", plus the short-length quota, push toward headlines. Nothing requires a first-person verb or legibility to a stranger.
- voice.md says polish his draft and never generate from scratch, and forbids inserting his tells. The pipeline generates from scratch, so ESL texture has no legitimate source.
- The "social move" law gives cover for #6's question.

## (c) Recommendation
Add three gates before texture:
- **Paraphrase:** no run of more than three consecutive words from the anchor entry; state the fact as "I/my + verb".
- **Stranger legibility:** every internal label (E1-E5, vault, injection, backend weights) is glossed in plain words or dropped; numbers keep their unit and referent.
- **Shape variety:** at most two subjectless one-liners per batch, no aphorisms, no closing question unless it names specifics he would really ask.

Then cap any single texture tic at two per batch, the dropped period included.

Better still, have him type a five-word seed per target and let the pipeline polish it. That is the only route to real ESL rhythm, and it is what voice.md already demands.

## Appendix B. Grok voice review of batcha (2026-11-22, verbatim, pasted by the operator)

Вот мой разбор по каждому реплаю.
Стиль пользователя (по памяти и прошлым постам)
	•	Плоский, конкретный, без воды
	•	Часто пропущены артикли
	•	Двухтактный ритм (длинное конкретное предложение + короткий вывод)
	•	Технические детали без объяснения «почему это круто»
	•	Минимум эмоций и engagement-bait

Анализ реплаев
#
Реплай
Оценка
Почему
1
Our session start does this from the other side. Injection has a token-budget cap with explicit drop priority…
Скорее ИИ
Слишком гладко и структурировано. «from the other side», «explicit drop priority» — типичные AI-формулировки. Нет твоего характерного ритма.
2
Hooks only check what you wired in, my E1-E5 classes still aren’t
Ближе к тебе
Короткий, обрывистый, без артиклей. Есть ощущение живого ESL.
3
Pre-prod audit blocked deploy: confidence hardcoded to 100%, demo mode left in.
Смешанный / скорее ИИ
Хорошая конкретика, но слишком чисто и симметрично сформулировано.
4
Caps aren;t the only way, weight credits by backend, 1x versus 25x
Ближе к тебе
Опечатка «aren;t», сжатый стиль, техническая конкретика. Выглядит живым.
5
Point 2 held on my iOS localization, 3 background sub-agents… 2,253 translations…
Скорее ты
Конкретные цифры, личный опыт, чуть кривой ритм. Это похоже на твой стиль.
6
The reasons behind a killed branch are what compaction loses. I keep decisions in vault files…
Скорее ИИ
Слишком гладкая риторика и вопрос в конце. «do you write the reasons down…» — классический AI-engagement.
7
Hash can’t judge, so the judge should come from another model family
Нейтрально / скорее ИИ
Слишком афористично и чисто. У тебя обычно больше конкретной привязки к своему стеку.
8
Lat/lng rounded to 3 decimals missed the nearest address 30-50% for weeks
Ближе к тебе
Конкретная цифра, проблема, без лишних слов. Хорошо ложится на твой стиль.
Итог
Скорее ты писал (или сильно редактировал): #2, #4, #5, #8
Скорее чистый ИИ: #1, #3, #6, #7
Главный признак AI в этих реплаях
Слишком «чистые» формулировки, симметричные структуры и лёгкий engagement-вопрос в конце. Твой живой стиль обычно более обрывистый, с пропущенными артиклями и более жёсткой привязкой к конкретному опыту без риторики.

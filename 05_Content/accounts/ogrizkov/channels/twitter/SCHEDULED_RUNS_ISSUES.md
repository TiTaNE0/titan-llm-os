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

## 2. Quality defects seen in output

| # | What | Where | Note |
|---|------|-------|------|
| Q-1 | `isn;t` / `aren;t` in drafts. | 2026-11-01 #2, #3; batcha #6 | NOT a defect: deliberate register texture per `reply_register.md:32` and `drafter.md:41`. Setup agent wrongly flagged it; the Producer sub-agent also flagged it as an "encoding artifact". Open question: the Producer's own context does not know the register, so it raises false alarms. |
| Q-2 | Internal jargon in a shipped draft (`E1-E5 classes`, `macro`). | 2026-11-01 target #9 | Already noted as a "Known gap (proposed v3.2)" in AGENTS_CONSTRAINTS.md. |

## 2b. Performance

| # | What | Evidence | Note |
|---|------|----------|------|
| P-1 | One run takes 35+ min; grok calls dominate. | batcha telemetry: scout calls 342 s each; thread fetches 342 s and 513 s; critic (Neon) 274 s + 136 s retry. | Scout and thread-fetch calls look sequential. Candidate fix: run vector fetches in parallel and batch thread fetches. Self-heal (3 attempts) could push one slot to 2-3 h. |

## 3. Risks: what can still go wrong unattended

**Infrastructure / host**
- R-1 Mac asleep or Claude app closed at slot time → run is late (runs on next launch). Only a 07:50 wake is set; no wake for 18:00. Moving to a 24/7 host removes this but needs grok, agy and Gmail auth there.
- R-2 iCloud Drive sync of the vault (`Mobile Documents`) during a run → file conflicts or half-synced artifacts.
- R-3 The scheduled run uses whatever branch is checked out. The fixes live on `fix/twitter-critic-neon` (not merged to `main`). If the operator switches to `main`, the dead model and the blocked flag come back.

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

## 5. Questions for the agent-team review

1. Should self-heal and the critic fallback ladder move into the runbook as the single source of truth?
2. How should a silently failing pipeline be noticed without emailing the operator (R-8)?
3. Is a 24/7 host worth it now? What does grok, agy and Gmail auth look like there?
4. What is the cost cap per slot and per day? Where does spend telemetry go?
5. Should `gate.sh` catch typos like `isn;t` (Q-1) and internal jargon (Q-2)?
6. Should pins (models, flags) be checked against the live CLI by a preflight instead of grepping docs (lesson from I-1/I-3: the verify script tested the docs, not reality)?

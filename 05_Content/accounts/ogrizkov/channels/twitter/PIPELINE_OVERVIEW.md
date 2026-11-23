---
type: reference
artifact: pipeline-overview
account: ogrizkov
channel: twitter
describes: the reply pipeline v3.2 (council/2026-11-23/DECISION.md + skill/twitter-reply-orchestrate.md)
written: 2026-11-23
status: current
---

# X Reply Pipeline — How It Works Now (v3.2)

A plain-language reference for the @ogrizkov reply pipeline. Binding sources: `council/2026-11-23/DECISION.md` (sections 2, 3, 10, 11) and the runbook `skill/twitter-reply-orchestrate.md`. Where they differ from `Reply_Pipeline_PRD_v3.0_Agentic.md`, DECISION and the runbook supersede the v3.0 PRD. Per-role contracts: `agents/roster.md`, `agents/role_specs/`, `agents/schemas.md`. Numbers: `agents/params.json`. Critic model order: `agents/critic_ladder.json`.

---

## 1. What it is

Two runs a day find fresh discussions where @ogrizkov can add one checkable thing, draft a short starter for each, judge them with deterministic gates, a cross-family critic and a fresh-context interest reviewer, and mail only the passed items to the operator (iCloud → iCloud through Mail.app). He writes each reply in his own words on his phone (delivery mode B). **It never posts to X.** The mail carries only real items; nothing is sent when nothing passes, and no error or status mail exists.

Goal: replies a stranger in the thread finds worth reading, which earn profile visits. Volume is a ceiling, never a quota.

It is NOT the Hermes marketing pipeline (`05_Marketing_System/`).

---

## 2. What changed in v3.2

- **What the thread lacks comes first.** The Matcher quotes the claim, names the open point and the move, and only then asks whether a project fact is the missing thing. Yes: a Deep item (at most 1 recommended a day; the fact then rests 30 days). No: a Clean item — the default — with no project fact and no implied experience, inside his authority zones (`voice.md`).
- **Discovery:** grok is used only for the discovery search (at most `cost.max_grok_calls` a run): a watchlist of answering authors and of large accounts (`agents/watchlist.json`), plus topic vectors on his authority zones and project vectors. Every read of a known post goes through `bin/fetch_posts.py` (public endpoint), grok only as the fallback.
- **Targets and ranking:** fresh posts first (under 90 minutes; 91-210 only when the fresh band yields nothing), up to 40 replies, authors 1k-20k then 20k-125k, ranked by two signals: authors who answer and post momentum. A large-account lane (125k+, posts under 60 minutes) is measured on its own.
- **Hooks:** every starter opens with a pattern from `reply_patterns.md` (read-only; written by the hook study). The mail shows the hook as one plain "How to open" line.
- **Delivery and posting are separate:** up to 6 passed items per run, best first, in trial and live mode; the mail recommends how many to post today and marks those items. Stages (2, 4, 6 pipeline items a day) open only on posting conditions; a tripwire sets the recommendation to 0 for 7 days while items keep coming for review.
- **Timing:** windows 16:30-18:30 and 21:00-23:00 Israel; runs start earlier (15:30 and 20:00 to begin with) so the mail is in Sent when a window opens; post-by = the earliest of send + 120 minutes, window end and post time + 360 minutes.
- **Reliability:** preflight (probes, lock, branch guard, Mail readiness), verified delivery (in Sent, not in Outbox or Drafts; incident I-9), slot log, `STATUS.md`, alarms in the daily log, timeouts, one owner for the unattended rules.
- **Measurement:** per-reply log at 24 h and 48 h, marks from mail feedback, tripwire, X Analytics import, period reports on days 14 and 28, a 14-day pattern refresh proposal, a LEARNING section owned by the main session.
- **Trial first:** every slot starts in trial (mails marked TRIAL), over at least 5 weekdays and a weekend; it ends on the trial report, 21 of 26 agreement with his marks and the own-8 report.
- **Not built (E30):** a 24/7 host. The pipeline runs on this Mac; the Mac must be awake at the start times.

---

## 3. Positioning the whole pipeline serves

**Core:** *Building agentic systems that develop, promote, and grow my projects. Sharing real pipelines, experiments & numbers.* Pillars build / apply / results remain tags on each item; pillar mix is a tie-breaker only (E18), never a quota.

---

## 4. The roster (who does what)

| # | Role | Model | Job |
|---|------|-------|-----|
| 0 | Orchestrator | Opus 4.8 host (Fable 5 if available) | Runs the control flow, holds thin state, routes artifacts. Never ingests voice/grounding/search text. |
| 0b | Vault_Scout | Sonnet 4.6 | Project vectors (`answers[]`/`contests[]`) and topic vectors per authority zone → `runs/_index/search_vectors.json`. |
| 1 | Scout | grok (`grok -p`) | Discovery search only: call A (watchlist + large accounts), call B (vectors). |
| 1b | Post reader | script | `bin/fetch_posts.py`: snapshots, his reply count, readings, author answers. |
| 2 | Matcher | Opus 4.8 | Claim-first fit test, Deep or Clean, zone, source logging, drops with reasons. |
| 3 | Drafter | Sonnet 4.6 | One starter per target with a hook, a quoted line, a one-line point, optional "Yours?". |
| 4 | Critic | non-Claude rung of `critic_ladder.json` via `agy -p` | Rubric v1.4 from the persisted snapshot, plus the interest question; 2 probes per call. |
| 4b | Interest reviewer | Opus 4.8, fresh per draft | Rule 11: "what does a builder learn?"; "nothing" rejects. |
| 5 | Gatekeeper | scripts | `bin/gate.sh` v2.5 and `bin/target_filter.py`. |
| 6 | Asset | Haiku 4.5 | Cards, interactive runs only. |
| 7 | Producer | script | `bin/produce.py`: the review file and the recommended/review marks. |
| 8 | Wins-logger | scripts (+ grok fallback) | `fetch_posts.py my-reply` + `measure.py`; winners into `wins.md`. |

Cross-family veto: the Drafter is Claude, the Critic is not; never a Claude or GPT model as Critic. Independence = non-Claude family + judging the persisted snapshot.

---

## 5. End-to-end flow (runbook `## CONTROL FLOW`)

```
0.  PROBE          bin/preflight.sh (exit codes 0/2/3/5/6/7/8/9/10/11; every stop is logged).
1.  IN PARALLEL    reply count (fetch_posts.py) + discovery (2 grok calls; 1 in reserve).
2.  BUDGET         slot_state.py budget: deliver_cap, post_today, resting entries, recent hooks.
3.  TARGETS        target_filter.py prefilter (rule 10, rank) → fetch_posts.py thread → rank.
4.  MATCHER        two waves: wave 1 for the recommendation, wave 2 for review items.
5.  PER TARGET     Drafter → gate.sh → check-item → Critic (batched, 2 probes) ‖ interest reviewer
                   → batch gate. Mail at the send cut-off or when both waves are done.
                   Thin run: one widen pass. Zero passed: log no_pass, no mail.
6.  PRODUCER       produce.py → replies_to_post.md (marks, order, caps).
7.  DELIVERY       email_replies.py --send: verified in Sent, retried, alarmed.
8.  RECORD + LOG   slot_state.py record / log (STATUS.md).
9.  MAINTENANCE    readings, tripwire, feedback marks, critic qualification, pattern refresh,
                   period report, release the lock. Never changes a delivered mail.
```

---

## 6. The artifact chain (every hop is a file)

Per batch (`runs/SLOT_ID_batch/`): `00_candidates.json` (Scout), `00_survivors.json` / `00_ranked.json` and `_prefilter_cuts.json` (`target_filter.py`), `00b_threads.json` (`fetch_posts.py`), `01_anchored.json` (Matcher), `02_drafts.json` (Drafter), `03_review.json` (orchestrator), `replies_to_post.md` (`produce.py`), `email.html` (`email_replies.py`), `_telemetry.jsonl`, `batch_report.md`. Shared state: `runs/_index/` (slot log, ledger, delivery state, sent markers, critic model, zones, authors). Measurement: `runs/_analytics/`. Fields: `agents/schemas.md`.

---

## 7. The gates (any one rejects)

1. Reads fine with the post deleted (Drafter deletion test; Critic `op_relevance`).
2. Without project nouns and numbers it restates the post or a reply (Matcher subtraction test; Critic `thread_fit`, `forced_anchor`).
3. Agreement only (Matcher moves; `gate.sh`; Critic `forced_anchor`).
4. Cannot quote the line it answers (`target_filter.py check-item`).
5. Forced anchor (Critic; the target is dropped, never redrafted).
6. Aphorism, internal label, planted typo, engagement bait (`gate.sh` labels and tic cap; Critic `ai_tells`). `aren;t` alone is not rejected.
7. Unverified claim (Critic `no_fabrication`; `gate.sh --type clean`; logged source fields).
8. A fact inside its rest, or reused wording (`check-item`; `gate.sh --history`, 5-word run, 14 days).
9. Off-topic promotion (Matcher replyability; Critic `thread_fit`).
10. Target outside the limits (`target_filter.py prefilter`).
11. Interest: the Critic's `learns` and a fresh-context reviewer; either "nothing" rejects.

Never reject for a missing project fact. Never pass because of a project noun. The hook check is a separate deterministic check and never overrides a rule. Fewer than 6 pass, fewer are sent.

Rubric v1.4 (`agents/role_specs/critic.md`): HARD `no_fabrication`, `thread_fit`, `op_relevance`, `forced_anchor`, `stranger_interest`, `ai_tells`; advisory `no_hype`, `length_register_sane`. Calibration: 2 probes per call from `tests/critic_probes.json` (v2, frozen real snapshots); the full set weekly (`bin/qualify_critic.sh`).

---

## 8. Telemetry and health

- `bin/trace.sh` / `bin/run_traced.sh` (`--timeout`, outcomes `timeout` and `no_block`) per call; `bin/batch_report.sh` per batch (counts `dropped`).
- `runs/_index/scheduler_log.jsonl` one line per slot with the funnel by age band, minutes to Sent and the reason; `spend.jsonl`; `STATUS.md` (last 10 slots, stage, recommendation, alarms, pause).
- Alarms: more than 1 slot in 10 without delivery, or a missed slot, writes one line to the daily log through `.vault_link/.scripts/append_log.sh`; never an email.

---

## 9. How to run it

- Interactive: "Run the @ogrizkov Twitter reply pipeline." → the runbook.
- Unattended: the scheduled task applies `skill/scheduled_task_prompt.md` → runbook `## UNATTENDED MODE` (the single owner of the unattended rules). The main session switches it on only after a supervised live run and a test mail confirmed on his device (runbook `## TRIAL AND LAUNCH`).
- Gateway: `/opt/homebrew/bin/bash bin/verify_v32.sh` (offline, stubs only). The two legacy doc lints (`verify_v3_scaffold.sh`, `verify_gemini_swap.sh`) assert v3.1 documents and are not run.

---

## 10. Failure policies

SAVE-AND-HALT for interactive runs; resume and self-heal for infrastructure failures in unattended runs; never stub or substitute a model; never lower a gate to fill a mail; every non-delivery counted. Details: runbook `## ERROR PATHS`, `## SAVE-AND-HALT`, `## UNATTENDED MODE`.

---

## 11. Operator minutes

The time budget to hold; estimates until the phone walk-through measures them (`runs/_analytics/workload.md`). He reads up to 12 items a day and posts only the recommended ones. At stage 1 the posting part is 17 minutes a day, inside the 20-minute target; reading and marking the review items adds up to 15 minutes, which he asked for, so the day total is up to 32 minutes, above the target.

| When | Task | Minutes |
|---|---|---|
| Once, before the trial | Mail fix: outgoing server, clear two stuck messages | 10 |
| Once, before the trial | Pinned post: edit one candidate and post it | 30 |
| Once, before the trial | Week-0 numbers and pinned post URL into `weekly.md` | 5 |
| Once, before the trial | Test mail walk-through on the phone | 15 |
| Each day, stage 1 | Post the 2 recommended replies, about 7 minutes each (read the thread, write, post) | 14 |
| Each day, stage 1 | One follow-up when an author answers | 3 |
| Each day | Read the other items, up to 10, about 1 minute each (quoted line, angle, starter) | 10 |
| Each day | Feedback marks: one reply per mail, two mails | 5 |
| Each day, stage 1 | Total: posting part 17, with reading and marks up to 32 | 32 |
| Each week | Visits and follows into `weekly.md` | 5 |
| Days 14 and 28 | Download the X Analytics export, read the period report | 15 |
| Each month | Save the X monthly report file | 5 |

---

## Appendix — key files

| File | What |
|------|------|
| `skill/twitter-reply-orchestrate.md` | runbook (v3.2) |
| `skill/scheduled_task_prompt.md` | the scheduled prompt (a pointer to UNATTENDED MODE) |
| `agents/params.json` | every number a script reads |
| `agents/critic_ladder.json` | critic model order (the only file naming a critic model) |
| `agents/watchlist.json` | seed lists: answering authors, large accounts |
| `agents/roster.md`, `agents/role_specs/`, `agents/schemas.md` | roles and fields |
| `reply_patterns.md` | the hook sheet (read-only input) |
| `project_authority.md` | project facts (`reuse: 30d`, optional `finding:` / `his_words:`) |
| `reply_register.md`, `../../voice.md` | voice and register |
| `bin/*.sh`, `bin/*.py` | gates, state, reads, mail, measurement |
| `tests/` | fixtures, stubs, critic probes |
| `council/2026-11-23/DECISION.md` | the decision record this version implements |

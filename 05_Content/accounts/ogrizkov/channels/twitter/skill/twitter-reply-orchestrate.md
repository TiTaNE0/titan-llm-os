# Skill: twitter-reply-orchestrate (v3.2)

Orchestrator runbook — the host Claude Code session IS the orchestrator (claude-opus-4-8 host; claude-fable-5 if available). Roster + role contracts: `../agents/roster.md`. Every number below that a script reads lives in `../agents/params.json`; the critic model order lives in `../agents/critic_ladder.json`. Binding inputs: `../council/2026-11-23/DECISION.md` (sections 2, 3, 10, 11) and the v3.2 spec; where they differ from the v3.0 PRD, they win. All paths are relative to `05_Content/accounts/ogrizkov/channels/twitter/`. Shell scripts run under `/opt/homebrew/bin/bash`.

Hard rules: never invent personal facts or experience; the pipeline never posts to X; the mail carries only real items (nothing is sent when nothing passes, never an error or status mail); no reply says how it was written. Volume is a ceiling, never a quota.

---

## PROBE

`/opt/homebrew/bin/bash bin/preflight.sh` (step 0). It checks, in order and each with a time limit: bash 4+; params; the pattern sheet (`reply_patterns.md` has at least one allowed hook, via `bin/target_filter.py hooks`); the authority zones (copied from `voice.md` to `runs/_index/authority_zones.json`); the slot id; branch `main` and a clean `skill/`, `agents/`, `bin/`; the run lock; Mail (automation answers, Outbox empty, no pipeline message in Drafts); the public endpoint (reported as `endpoint_ok`, not a stop); the grok fenced-JSON probe only when the last slot-log line with a grok call did not succeed; `agy models` and a fenced-JSON probe down `agents/critic_ladder.json` (first answer wins → `runs/_index/critic_model.json`); `search_vectors.json` freshness; `slot_state.py health`. It prints one JSON object. Any non-zero exit stops the run; preflight has already written the slot-log line, so the stop is counted and can alarm.

Exit codes: 0 ok, 2 config, 3 outside slot window, 5 locked, 6 branch or dirty tree, 7 grok dead or grok budget at 0 (reason `grok_budget`), 8 no usable critic rung, 9 Mail not ready, 10 pattern sheet missing or unusable, 11 grok balance exhausted. Run lock: the first preflight of a run creates a run token, writes it into the lock and into `runs/SLOT_ID_batch/run_token`, and prints it as `run_token`. RESUME and a new attempt of the run pass `--run-token "$(cat runs/SLOT_ID_batch/run_token)"` and pass the lock; any other session, the same slot included, exits 5 `locked` while the lock is fresh, and a stale lock (`lock_stale_min`) is taken over. Grok probe: it runs only when `grok_probe_needed` (after a good grok call of this slot, the probe included, recorded with its time in `runs/_index/grok_calls.jsonl`, no probe is spent again in the slot until a grok call of the slot fails). It is spent from the run's grok budget first; at 0 a new run stops with 7 `grok_budget`, while a RESUME skips the probe (`grok_probe_skipped`) and is never stopped by it. `--release` removes the lock (last step of maintenance); `slot_state.py log --reason no_pass` releases it too, because a run where nothing passed ends there. `--critic-only --exclude <telemetry_id>` picks the next rung after a calibration failure.

---

## STATE MODEL

Run-time state lives in files the scripts own (`runs/_index/`, gitignored; spec D3): `scheduler_log.jsonl`, `spend.jsonl`, `delivered.jsonl` (ledger), `delivery_state.json` (modes per slot start, stage, pause), `posted_counts.json`, `authority_zones.json`, `sent/SLOT_ID`, `critic_model.json`, `critic_qualified.json`, `grok_calls.jsonl` (every grok call spent or refused, and its result with the time), `alarms.jsonl`, `authors.json`, `feedback_seen.json`, `.run.lock/`; `STATUS.md` in the channel folder; the measurement files under `runs/_analytics/`.

The orchestrator itself holds ONLY:
- `slot_id` (from `bin/slot_state.py slot-id`) and `batch_id` = `SLOT_ID_batch` (second attempt `SLOT_ID_a2_batch`), and the `run_token` preflight printed (also in `runs/SLOT_ID_batch/run_token`)
- the budget JSON of this run (`bin/slot_state.py budget`)
- per-target status ∈ `{drafted, passed, failed, skipped, quarantined, held, dropped}` and retry counts
- `grok_calls` this run, and the hook ids already taken by drafts of this run. The grok budget itself is kept in code: `budget` reports `grok_calls_left_run` (cap `cost.max_grok_calls` per slot, all attempts and the preflight probe included) and `grok_calls_left_today` (cap `cost.max_grok_calls_day`)
- `calibration_probes` — for the current critic call only: the injected probe ids and their positions. Never written into the batch handed to the Critic and never into `results[]`.

Orchestrator **never ingests** `voice.md` / `reply_register.md` / grounding text / search results (PRD §9.4). It routes file artifacts. That thin state is what keeps its context clean.

---

## CONTROL FLOW

Grok rule: grok is used only for the discovery search, at most `max_grok_calls` (3) per run and `max_grok_calls_day` (6) a day; every read of a known post goes through `bin/fetch_posts.py`; grok is a fallback for a read only when the endpoint fails and a call is left. Every grok call goes through `bin/run_traced.sh --grok-slot SLOT_ID --grok-purpose discovery|widen|read|maintenance --grok-batch BATCH`, which spends the call through `slot_state.py grok-call` before it runs (a command named grok without these flags is refused with exit 64). Exit 75 means the budget is at 0: stop discovery, deliver what passed; the refusal is written to the slot log (`grok_stop`) by the next `slot_state.py log`. The preflight probe counts against the run's 3.

Never reject for a missing project fact. Never pass because of a project noun.

Steps 0 to 8 run before delivery; only what today's items need runs before the mail. Step 9 runs after it.

**0. PROBE** — `bin/preflight.sh`; any non-zero exit stops the run with the slot-log line it wrote.

**1. Started together, in parallel:**
- REPLY COUNT: `python3 bin/fetch_posts.py reply-count --handle ogrizkov` (no grok call). Unreadable → `budget --posted-today-unknown`; `partial: true` → `budget --partial`.
- DISCOVERY, two grok calls through `bin/run_traced.sh --timeout`: call A asks for fresh posts by the `authors` of `agents/watchlist.json` and, as a second list in the same prompt, for posts under `tiers.large.max_age_min` minutes old by the `large` list (labs and builders first); call B sends the `cost.scout_vectors_per_run` vector queries of `runs/_index/search_vectors.json` in one prompt, topic vectors before project vectors. Pillar mix is a tie-breaker only (E18). Every prompt asks for posts no older than its age limit, newest first, with their view counts, and passes `python3 bin/slot_state.py history --days 14 --urls` as the exclude list. The third call of the budget stays in reserve. A second attempt of a slot (`SLOT_ID_a2_batch`) makes no discovery call: it copies `runs/SLOT_ID_batch/00_candidates.json` (`grok_discovery_batch` in the budget names the batch); `run_traced.sh` refuses a new discovery in the second batch with exit 75. Vault_Scout regenerates `search_vectors.json` first when it is missing, older than 7 days, or `project_authority.md` / `authority_zones.json` changed.

**2. BUDGET** — `python3 bin/slot_state.py budget --posted-today N > runs/BATCH/_budget.json` gives `deliver_cap` and `post_today`. Delivery does not depend on `post_today`: a run with `post_today` 0 still delivers items for review.

**3. TARGETS** — `python3 bin/target_filter.py prefilter --candidates runs/BATCH/00_candidates.json --budget runs/BATCH/_budget.json --out runs/BATCH/00_survivors.json --cuts runs/BATCH/_prefilter_cuts.json` (rule 10; tiers 1 and 2 ranked by the answers and momentum score, the large-account lane apart; one cut reason per candidate). Thread reads: `python3 bin/fetch_posts.py thread --url U1 --url U2 ...` for the top `cost.thread_fetch_max` survivors, in parallel (E27) → `runs/BATCH/00b_threads.json`. When the endpoint fails, the fallback is one grok call that reads all those URLs, if the reserve call is unused; else the unread survivors are cut `thread_unreadable`. Then `python3 bin/target_filter.py rank --survivors ... --threads ... --out runs/BATCH/00_ranked.json`.

**4. MATCHER**, two waves in rank order (`role_specs/matcher.md`). Wave 1: the first `post_today` + `cost.bind_extra` candidates, plus the best large-account candidate when the day's large place is unused (`recommended_today.large` < `large_per_day`). Wave 2: the further candidates, up to `caps.bind_max` binds in all. Wave 1 is started first. The Matcher gets `resting_entries` and the zone list. Band rule: every candidate of the 0-90 band is processed first; a candidate of the 91-210 band is processed only when no fresh candidate has passed in this run.

**5. Per target, per wave:**
- a. Drafter (`role_specs/drafter.md`, fresh per retry) gets `hooks_recent` and the hook ids already taken by earlier drafts of this run.
- b. `gate.sh` single: `/opt/homebrew/bin/bash bin/gate.sh --type deep|clean --max-words N --anchor A --history H --thread TH DRAFT_FILE` with `N` = 40 (25 for the large-account lane), `A` = entry_substance + contribution (Deep), `H` = `slot_state.py history --days 14`, `TH` = the snapshot text. Exit 2 → ABORT (config). Exit 1 → one fresh redraft with the flag, then `skipped`.
- c. `python3 bin/target_filter.py check-item --target T --draft D --thread TH --budget B [--source-text runs/BATCH/sources/tN.txt]` (hook, zone, quote, source and rest checks). A failure drops the draft before the Critic sees it.
- d. In parallel: the Critic rubric call — one batched call per wave, with the 2 probes of `bin/qualify_critic.sh --pick --slot SLOT_ID`, model from `runs/_index/critic_model.json`, through `bin/run_traced.sh --role critic --timeout 660`; evaluated by `bin/qualify_critic.sh --evaluate <output> --model <telemetry_id> --probes <the ids --pick printed>` (a probe mismatch or a picked probe missing from the output holds that wave) — and the interest reviewer, one fresh sub-agent per draft (`role_specs/critic.md` § Interest review). Either "nothing" rejects.
- e. Batch gate over the passed set: `gate.sh --batch` on a file of their `DRAFT:` lines. On a failure the lower-ranked draft of the flagged pair is dropped; no redraft loop.

Send time: the mail is produced when both waves are done or at `send_cutoff` (budget; `timing.send_margin_min` before the window opens), whichever comes first. Wave 1 is always waited for; a wave-2 draft that has not passed every gate by then is left out and logged.

Routing (E6): `forced_anchor`, `op_relevance` or an interest reject → status `dropped`, no redraft. `no_fabrication`, `thread_fit`, `stranger_interest`, `ai_tells` → one fresh redraft, then dropped. `no_hype`, `length_register_sane` → STYLE budget (3). Quarantine rules and budgets stay as before. A replacement is the next candidate in rank order; no extra discovery call.

Stop conditions: `deliver_cap` items passed; candidates exhausted; `max_grok_calls`; the send time above; `cost.slot_deadline_min` (then no new work starts and what passed every gate is delivered); failure-rate breaker (>~40% of targets hit the breaker, or low-confidence rejects scatter across criteria). The delivery number is bounded by these stops and is never a quota; the gate is never lowered to fill it.

Thin run: when passed is below min(`thin_run.widen_below`, `deliver_cap`) after all bound candidates of both bands, time remains before the send time and the reserve grok call is unused, exactly one widen pass: one discovery call with unused query seeds and the `python3 bin/target_filter.py authors --limit 20` list; same limits, same gates. Then deliver what passed. Zero passed: `slot_state.py log --reason no_pass` (it also releases the run lock), no email, no retry.

**6. PRODUCER** — `python3 bin/produce.py runs/BATCH --budget runs/BATCH/_budget.json` (marks and order; `role_specs/producer.md`). ASSET: interactive runs only (`role_specs/asset.md`), text unchanged; `bin/render_asset.sh` exit 3 is non-fatal.

**7. DELIVERY** — see `## DELIVERY`.

**8. RECORD AND LOG** — `python3 bin/slot_state.py record --slot SLOT_ID --replies runs/BATCH/replies_to_post.md`, then `python3 bin/slot_state.py log --slot SLOT_ID --reason R --funnel '<json>' --minutes-to-sent N --sent-before-window true|false --grok-calls N --grok-ok true|false --endpoint-ok ... --delivered N --recommended N --emailed true|false --batch-ids ... --attempts N --critic-model ... --wall-min N` (which rewrites `STATUS.md`). The funnel holds candidates, survivors, fetched, bound, drafted, gate_pass, critic_pass, interest_pass, passed, and `by_age_band`.

**9. MAINTENANCE** — see `## MAINTENANCE`; always after delivery.

**LOUD FLAGS** — emit to stdout AND `03_review.json`: `"BATCH HELD — DO NOT POST"` whenever `held: true`; `"CRITIC UNAVAILABLE — batch HELD"`; `"CALIBRATION FAILED — critic SHIPped a planted probe — batch HELD"`; `"no cross-family veto this run"` (stub only); `max_grok_calls reached`; every dropped, skipped and quarantined target with its reason.

---

## UNATTENDED MODE

The single owner of the rules for a scheduled, unattended run (E24). `skill/scheduled_task_prompt.md` only points here.

- Never ask questions. The operator wants ONE outcome: a mail with real, gate-passed items. He does not want to hear about errors, halts or empty runs; every outage goes to the slot log, `STATUS.md` and, when it alarms, one line in the daily log.
- Self-heal only for infrastructure failures, never for an empty result. SAVE-AND-HALT becomes resume: diagnose, fix, resume from the saved artifacts (`HALT.json` `next_stage`) or start a fresh attempt (`SLOT_ID_a2_batch`). Attempts per slot (`cost.attempts_per_slot`), per day (`caps.attempts_left_today`) and the deadline (`cost.slot_deadline_min`) come from the budget. RESUME and a fresh attempt run `bin/preflight.sh --run-token "$(cat runs/SLOT_ID_batch/run_token)"`: the token passes this run's lock, and the probe recorded for the slot is reused, so no grok call is spent unless a grok call of the slot failed. A fresh attempt reuses the first attempt's `00_candidates.json` and spends no discovery call; the slot's grok budget is shared by its attempts. A slot where nothing passed is a correct outcome: log `no_pass`, no mail, no new attempt.
- Critic unavailable, probe fails, or critic times out: `bin/preflight.sh --critic-only --exclude <telemetry_id>` picks the next rung of `agents/critic_ladder.json` (non-Claude only, keeps the cross-family veto). Never use a Claude or GPT model as Critic. Note the model used in `batch_report.md`.
- Never pass `--dangerously-skip-permissions` to agy (it is blocked here and not needed).
- CALIBRATION FAILED: re-run that critic call once as a fresh call. If a probe still mismatches, move to the next rung and re-judge. Never deliver drafts from an uncalibrated critic.
- grok: a failed call is not repeated beyond the budget of 3 calls a run and 6 a day (`run_traced.sh` exit 75 = budget at 0: stop discovery). grok fully down: stop silently with a slot-log line (`infra`). A "402 ... balance exhausted" answer stops the run with the reason `grok_balance` and an alarm line.
- His reply count cannot be read: `budget --posted-today-unknown` (the mail then recommends at most one item).
- Any other sub-agent failure: retry once with a fresh sub-agent, then treat as a new attempt.
- Sub-agent tokens are traced through `bin/trace.sh` (the Agent tool returns them; E28); CLI calls through `bin/run_traced.sh --timeout`.
- Run the Producer even if fewer than `deliver_cap` passed. Deliver what passed (1 or more).
- Do not commit anything.
- Final message: slot id, batch ids, attempts used, critic model, items delivered and recommended, delivered or not (verified in Sent), minutes to Sent, grok calls used.

---

## DELIVERY

Command: `python3 bin/email_replies.py runs/BATCH/replies_to_post.md --slot SLOT_ID --send` (iCloud → iCloud through Mail.app; never Gmail, which rewrites links through google.com and stops a tap from opening the X app).

- Exit 0: delivered and verified (the message is in Mail's Sent mailbox and neither Outbox nor Drafts holds it; the marker `runs/_index/sent/SLOT_ID` is written). Then record and log (step 8).
- Exit 3: nothing sendable (no complete item, no `mode:` line, or held). Log, no retry.
- Exit 6: already sent for this slot. Log, send nothing.
- Any other exit: treat as exit 4 with the reason `send_state_unknown` (do not resend outside the command).
- Exit 4: not delivered (`not_in_sent`, `stuck_outbox`, `stuck_draft`, `send_error`, `state_unknown`, `send_state_unknown`, `timeout`). `state_unknown`: Mail did not answer the Sent/Outbox/Drafts check, so nothing was sent. `send_state_unknown`: a send was issued but its state could not be read; the message may exist. In every case `open -a Mail` when Mail is not running, then the same command again: it sends only after the check answers and shows the message in none of Sent, Outbox and Drafts (a message found in Sent counts as delivered, so no second copy is made), up to `delivery.send_attempts` in total. Never send any other way. After that `python3 bin/slot_state.py log --slot SLOT_ID --reason delivery_failed` and `python3 bin/slot_state.py alarm --reason delivery_failed --text "<reason>"`, which appends the alarm line to the daily log through `.vault_link/.scripts/append_log.sh`.
- Never an email about a failure. The same alarm command serves the non-delivery alarm from `slot_state.py health` (also raised by `slot_state.py log` itself) and a tripwire pause.
- `python3 bin/email_replies.py --verify-delivery --slot SLOT_ID` re-checks a slot without sending.
- `email_replies.py --test --send` is for the main session only (phone walk-through); unattended mode never calls it.

---

## MAINTENANCE

Always after delivery, or as a separate run by the main session. A failure here never changes a delivered mail and is logged.

1. `python3 bin/measure.py due`.
2. Readings: `python3 bin/fetch_posts.py my-reply --parent <url> --handle ogrizkov` for the due items (it follows the conversation cursor up to `endpoint.max_pages`; a reading with `found: null` / note `unknown` is not "no reply": it waits for the next maintenance and never counts toward the tripwire or the posting days; grok pages only as the fallback, through `run_traced.sh --grok-purpose maintenance`, within `cost.maintenance_grok_calls`; when neither works, the readings wait for the next maintenance and the reason is logged); the host sets `reading` and `author_only_corrected`; then `python3 bin/measure.py merge --pages <file>` and `python3 bin/measure.py tripwire` (a trip pauses the posting recommendation for `tripwire.pause_days`, writes the alarm line, delivery for review goes on).
3. Feedback: `python3 bin/email_replies.py --feedback > runs/_analytics/_feedback.jsonl`, then `python3 bin/measure.py marks --from-json runs/_analytics/_feedback.jsonl` (trial and live mails alike; read-only on Mail).
4. When `qualification_due`: the weekly critic qualification — one critic call on the full probe set of `tests/critic_probes.json` (plus `runs/_analytics/labelled.json` once it exists, from `measure.py agreement --export`), then `bin/qualify_critic.sh --evaluate <output> --model <telemetry_id> [--labelled F] --record`.
5. When `patterns_refresh_due`: the pattern refresh of `agents/role_specs/wins.md`.
6. On days 14 and 28 after `live_since` (`period_due`): `python3 bin/measure.py period --end YYYY-MM-DD`.
7. Winners into `runs/_analytics/wins.md` (`skill/twitter-reply-log-wins.md`).
8. `python3 bin/slot_state.py status`; `/opt/homebrew/bin/bash bin/preflight.sh --release`.

---

## MEASUREMENT

DECISION section 3 as amended. Never an email.
- Per posted reply, at 24 h and 48 h: `runs/_analytics/reply_log.jsonl` (`measure.py merge`; fields in `agents/role_specs/wins.md`), with hook, move, tier, parent views, `followed_up`, `added_experience`. Only replies he posted have rows.
- Marks: `runs/_analytics/marks.md`, one line per mark on recommended and review items alike (email feedback, posted trial items, chat via `measure.py marks --item`).
- Weekly operator file: `runs/_analytics/weekly.md` (`measure.py init`): the `pinned_post_url:` line, then profile visits and new follows per week, week 0 first.
- Monthly X report: the operator saves each month's file as `runs/_analytics/under_the_hood/YYYY-MM.json`; the stage-3 condition reads the newest one.
- X Analytics export on days 14 and 28: `python3 bin/measure.py import-export --file <csv>` (prints the header row and the mapping; an unknown layout exits 1 and guesses nothing).
- Period report: `runs/_analytics/period_YYYY-MM-DD.md` with the volume-rule verdict, which the operator confirms.
- Run health: `runs/_index/scheduler_log.jsonl`, `STATUS.md`, `slot_state.py trial-report`.

---

## LEARNING

Owned by the main session. Inputs: the period reports, marks with reasons, the by-hook, by-move, by-age-band, by-tier and momentum tables, an imported export, `STATUS.md`.
- It may change `agents/watchlist.json` (new names only from a live Grok sample, never invented; at day 28 with low author answers it replaces the weakest third the report lists), values in `agents/params.json` (capture, ranking, starts, `runs_per_window`, grok budget, delivery and lane numbers), and write hook sheet proposals.
- Gate rules (`gate.sh`, the rubric, rule 11), the stage (`slot_state.py set-stage`) and the pattern sheet need the operator.
- Every change is recorded: a parameter or watchlist change by a commit on `main` before the next slot (the branch guard stops a run on a dirty tree); a gate change by `python3 bin/measure.py gate-change --note T`, which opens a new 26-mark agreement window.
- Grok for research: the main session spends a grok call only with a stated need and puts its questions into one call.
- Fixed steps: day 14 — decide `runs_per_window` and read the by-move table (the hook study's open point: the Clean core move was the most common move among losing replies, 15 winners and 13 controls, and short reactions won views, 26 and 10, while drawing only thank-you answers); day 28 — review the large-account lane against the small authors; once — re-read his May posts' numbers through `fetch_posts.py status` into `runs/_analytics/may_posts_recheck.md` (DECISION section 10 item 5).

---

## TRIAL AND LAUNCH

Trial (B10): every slot starts in trial (`runs/_index/delivery_state.json` absent = trial). A trial run is a full run and mails its passed items like a live run, marked TRIAL in the subject, the header and every item; nothing is sent when nothing passes. Delivery is the same in trial and live mode (up to `volume.deliver_per_run`, best first). Marks on recommended and review items alike count toward the 26-mark window. Stages and the tripwire apply to what he posts; stage 1 counts from the first day he posts a pipeline item, trial items included. The trial ends for a slot when `slot_state.py trial-report` and `measure.py agreement` both exit 0 and `runs/_analytics/own8_report.md` exists; `slot_state.py set-mode --slot HH:MM live` also needs the pinned post URL in `weekly.md`. `trial-report` exit 0 checks the overall share and each slot's coverage, and `set-mode live` checks only the pinned post URL: before `set-mode` for a slot, the main session also checks that slot's own share in `trial-report` (at least `trial.pass_share`). Delivery mode A (ready drafts) is not built; the day-14 report shows the posted share that decides it.

Posting recommendation: stages 1 to 3 (`volume.stages`) limit the items recommended per run, pipeline items per day and all his replies per day; the allowance is the smaller of the stage total and his 7-day average + `allowance_avg_plus`. Stages never open by the calendar: `slot_state.py set-stage 2` needs posting on `stage2_posting_days` days in stage 1 and no tripwire; `set-stage 3` needs a `raise` verdict and a label-free monthly report. The main session runs a stage change after the operator's yes; the next mail says when and why.

Post-build operations (B11), by the main session with the operator:
1. Merge to `main` on the operator's instruction (the branch guard runs only from a clean `main`).
2. Mail (I-9): the operator sets the iCloud outgoing server and clears stuck messages; preflight exits 9 until then.
3. Supervised live run: one full run without `--send`; review `replies_to_post.md` and `email.html`; measure the run time for 6 items; correct the start times in `params.json` so the mail is in Sent before each window opens.
4. One test mail: `python3 bin/email_replies.py --test --send runs/BATCH/replies_to_post.md`; phone walk-through; minutes per item into `runs/_analytics/workload.md`; the operator confirms the mail on his device.
5. Only then the main session applies `skill/scheduled_task_prompt.md` at the start times of `params.json`. The Mac must be awake at those times (operator setting).
6. Profile: `python3 bin/measure.py init`; the operator posts the new pinned post (candidates in `runs/_analytics/pinned_post_candidates.md`) and writes its URL and the week-0 numbers into `weekly.md`. `finding` lines only on a finding request.
7. Own-8 report: run his 8 best own replies (DECISION, `council/2026-11-23/E3_account_state.md` section 6) through `gate.sh`, the Critic as Clean and the interest review; write `runs/_analytics/own8_report.md` with the count rejected and the rule for each.
8. Trial over at least 5 weekdays and a weekend at both slots; marks; `trial-report`; `agreement`; go live per slot with `set-mode`.

---

## ERROR PATHS

| Condition | Action |
|-----------|--------|
| `preflight.sh` non-zero | Stop; the slot-log line is written; unattended: self-heal per UNATTENDED MODE when it is infrastructure |
| `preflight.sh` exit 10 (pattern sheet) | Stop; the main session fixes the sheet or the parser |
| `preflight.sh` exit 11 / grok "402 ... balance exhausted" | Stop with `grok_balance`; alarm line |
| agy critic exceeds 10m print-timeout | CRITIC-UNAVAILABLE; interactive SAVE-AND-HALT; unattended next rung |
| `gate.sh` exit 2 at any point | ABORT (config error: need bash≥4 — `/opt/homebrew/bin/bash`) |
| `gate.sh` exit 1 | One fresh redraft with the flag; else `skipped` with the reason |
| `check-item` exit 1 | Drop the draft before the Critic (`drop_reason` = the reason code) |
| Endpoint read fails (`fetch_posts.py` exit 4) | One batched grok fallback if the reserve call is unused; else cut `thread_unreadable` / count unknown / readings wait |
| `grok -p` returns no fenced block | Re-prompt once within the budget; else stop the call |
| Critic probe mismatch | Hold the wave; unattended: fresh re-run once, then the next rung |
| Mail not verified (`email_replies.py` exit 4, any reason incl. `state_unknown` / `send_state_unknown`) | Retry the same command up to `send_attempts` (it sends only after the state check proves the message is nowhere), then `delivery_failed` + alarm |
| grok budget at 0 (`run_traced.sh` exit 75, preflight exit 7 `grok_budget`) | Stop discovery; deliver what passed; the slot log shows `grok_stop` |
| `render_asset.sh` exit 3 | Non-fatal: keep HTML, note "open + screenshot" |
| Any role's output unobtainable | SAVE-AND-HALT; never substitute, never stub |
| Failure rate >~40% across the batch | Rate-based escalation: stop the batch; interactive: surface to the operator |

## SAVE-AND-HALT (universal failure policy — 2026-06-10b lesson)

When any role cannot produce its output for ANY reason (out of credits, auth failure, dead CLI,
sub-agent failing twice, no fenced block after the one re-prompt):

1. **SAVE** — all artifacts already on disk stay; finish any sub-agent already in flight; start NOTHING new.
2. **RECORD** — write `runs/<batch>/HALT.json`: `{halted_at_stage, reason, completed_stages,
   artifacts_present, next_stage, resume_instruction}`. Mirror `held: true` + the loud line into
   `03_review.json` if it exists yet. Log the slot (`slot_state.py log --reason infra`).
3. **STOP** — no downstream stages, no asset, no producer, no padding artifacts.
4. **RESUME** — when the blocker clears: re-run the PROBE with `--run-token "$(cat runs/SLOT_ID_batch/run_token)"`, read `HALT.json`, continue from `next_stage`
   using the saved artifacts. File-based handoffs make every stage re-entrant; nothing is redone.

Interactive runs halt; unattended runs resume per UNATTENDED MODE. The Critic degradation rule (`agents/role_specs/critic.md`) is the special case of this policy.

---

## ISOLATION MATRIX

| Role | Reads | Must never see |
|------|-------|----------------|
| Vault_Scout | `project_authority.md`, `runs/_index/authority_zones.json` | `voice.md`, `reply_register.md`, drafts, live X data, `runs/<batch>/` artifacts |
| Scout (discovery) | concrete queries from the orchestrator, `agents/watchlist.json`, the exclude list | `voice.md`, `reply_register.md`, `project_authority.md` grounding entries, drafts |
| `fetch_posts.py` | public post ids and the public handle | everything else |
| Matcher | `00_candidates.json` survivors, `00b_threads.json`, `project_authority.md`, `authority_zones.json`, budget fields, one public source per target | `voice.md`, `reply_register.md`, search internals, other roles' reasoning |
| Drafter | ONE target's snapshot + `01_anchored.json` fields, `reply_patterns.md`, `voice.md`, `reply_register.md`, never-list | Full `project_authority.md`, other targets, search internals, asset templates, gate internals |
| Critic | Drafts of its wave, persisted snapshots, `author_claim`, `move`, `reply_type`, `grounded_claim` (Deep), `source_quote`, Rubric v1.4 | Full `voice.md` / `reply_register.md`, gate internals, the Matcher's reasoning, live X / any URL to open |
| Interest reviewer | One draft, its opening post and top replies | Everything else |
| Gatekeeper | Draft or batch file (shell; no LLM context) | — |
| Asset | Top 1–2 items selected by the orchestrator, aurora-frost template | Search internals, other targets, gate internals, `voice.md`, `reply_register.md` |
| Producer (`produce.py`) | `01_anchored.json`, `02_drafts.json`, `03_review.json`, budget, pattern sheet names | — (script) |
| Wins-logger | ledger, `measure.py due`, endpoint answers, `wins.md` | Other batches' drafts, asset templates, gate internals |

Orchestrator never ingests voice / register / grounding / search text — routes artifacts only.

---

## CAPS (consolidated)

Every value lives in `agents/params.json`; this table names them.

| Cap | Key |
|-----|-----|
| grok calls per run (discovery only; 1 in reserve; the probe counts) / per day | `cost.max_grok_calls` / `cost.max_grok_calls_day` |
| grok calls in maintenance (fallback only) | `cost.maintenance_grok_calls` |
| Delivered items per run (trial and live; no minimum) | `volume.deliver_per_run` |
| Large-account items per run / age limit / words | `tiers.large.per_run` / `tiers.large.max_age_min` / `tiers.large.max_words` |
| Posting recommendation per stage | `volume.stages[]` |
| Capture band (fresh / max age / replies / min followers) | `capture.*` |
| Thread reads / extra binds / vector queries | `cost.thread_fetch_max` / `cost.bind_extra` / `cost.scout_vectors_per_run` |
| Attempts per slot / per day / slot deadline | `cost.attempts_per_slot` / `cost.attempts_per_day` / `cost.slot_deadline_min` |
| Widen passes | `thin_run.widen_passes` |
| Probes per critic call | `probes_per_call` |
| Mail send attempts / verify wait / Mail answer time limit | `delivery.send_attempts` / `delivery.verify_wait_s` / `delivery.query_timeout_s` |
| Conversation pages read per post | `endpoint.max_pages` |
| Redraft budget: hard criteria (one), style (three) | runbook routing (step 5) |
| Word and n-gram limits | constants in `bin/gate.sh` (source is authoritative) |
| Vault_Scout staleness TTL | 7 days |

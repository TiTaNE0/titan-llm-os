---
description: Weekly synthesis of the daily logs into facts, contradictions and rule proposals (Synthesizer; interactive or unattended)
allowed-tools: Bash, Read, Write
---

# /synthesize [iso_week]

The Brain owns the contract (`03_Brain/System_Agents.md` section 7, `/synthesize`), and this file owns the runnable form, the same split as the kit commands. The runbook is vault-local and not a kit command, for three reasons: the macro needs `03_Brain/` and exists only in this vault, kit commands propagate to every onboarded project, and the kit is a separate repo outside this change. Run the macro from this file, not from the section 7 summary. Paths below use the `.vault_link/.scripts/` prefix; run every command from the vault root. Argument: `$ARGUMENTS` (an ISO week such as `2026-W47`; empty means the current week in interactive mode).

Scheduled runs follow `## UNATTENDED MODE`, which owns every rule of that mode. Everything else in `## STEPS` applies to both modes.

## STEPS

Start (kernel section 1.2): capture the start instant before any work.

```bash
./.vault_link/.scripts/telemetry_start.sh synthesize
```

### Step 1 - Persona Gate
Run `./.vault_link/.scripts/persona_check.sh Synthesizer` (prefix `TITAN_SESSION_ID=<id>` when the session has a keyed id). It fails with E4 when the live persona is not `Synthesizer`. Never switch persona silently; interactive mode asks the operator to handshake as Synthesizer.

### Step 2 - Inputs
The week argument is an ISO week `YYYY-Www`. The interactive default is the current week, per the kernel. Unattended mode passes the week explicitly. Then run:

```bash
./.vault_link/.scripts/synthesize_run.sh plan --week <W>
```

Every early exit goes to Step 9, so each run appends exactly one summary line:
- Exit 0: ready; continue with Step 3.
- Exit 6: already synthesized. Write no outputs and go to Step 9 with the skipped, already synthesized line (success).
- Exit 1: E1 (`Weekly_Synthesis/` or `facts.jsonl` missing; never create them). Write no outputs, write the error report, and go to Step 9 with the error line, step plan.
- Exit 3: E3 (malformed week, exactly one output exists, or an unresolved `facts.jsonl.next`). Write no outputs, write the error report, and go to Step 9 with the error line, step plan.

Recovery is delete-only: if `plan` exits 3 with `unresolved facts.jsonl.next`, a previous run failed after Step 7 began writing. In an interactive Synthesizer session, delete `facts.jsonl.next` and that week's `<W>.synthesis.md` and `<W>.synthesis.json`, then rerun `/synthesize <W>` interactively.

### Step 3 - Read
Read exactly the `log=` files that `plan` printed, nothing else in `04_Logs/`. When `logs=0` there is nothing to synthesize: write no outputs and go to Step 9 as a skipped success.

### Step 4 - Extract
Extract candidate facts per `03_Brain/Memory_Schema.md` section 1 (record schema) and section 6 (what not to synthesize). Fact ids are `fact_<W>_NNN`, as in the 2026-W20 output. Keep only claims that would change a future decision.

### Step 5 - Reconcile
Match each candidate against `03_Brain/Weekly_Synthesis/facts.jsonl`:
- A match increments `citations`, updates `last_cited`, adds the log to `source_logs`, and raises `confidence` by 0.1.
- No match creates a new fact at confidence 0.5 and status `active`.
- A direct contradiction marks both facts `contradicted`, lowers confidence by 0.2, and adds a `contradictions` entry `{facts: [idA, idB], summary: <one sentence>, status: "open"}`.

Work on a copy: the updated store is written to `03_Brain/Weekly_Synthesis/facts.jsonl.next` in Step 7, never edited in place.

### Step 6 - Decay
Apply all four rules of the `03_Brain/Memory_Schema.md` section 3 table:
- `last_cited` more than 90 days ago and citations under 2: status `archived`.
- confidence under 0.2: status `archived`.
- Archived facts move to `03_Brain/Weekly_Synthesis/archive/<year>.jsonl`.
- citations of 5 or more and confidence of 0.8 or more: add a `rule_proposals` entry (`id` `proposal_<W>_NNN`, `source_fact`, `proposed_rule`, `rationale`, `confidence`, `target_file`, `status: "pending"`). This is the halt for the Architect.
- two facts with status `contradicted`: record the pair in `contradictions` with status `open`. This is the "halt; surface to user for resolution" rule, and Step 8 performs it.

### Step 7 - Output
Write three files under `03_Brain/Weekly_Synthesis/`, in this order:
- `facts.jsonl.next`: the full updated fact store, one JSON object per line with at least `id` and `claim`.
- `<W>.synthesis.json`: keys `iso_week`, `dates`, `synthesized_at`, `persona`, `logs_read`, `facts_added`, `contradictions`, `rule_proposals`.
- `<W>.synthesis.md`: the human report with sections Summary, Facts, Contradictions, Rule Proposals (layout of `2026-W20.synthesis.md`).

`facts.jsonl.next` goes first so that any partial write leaves a stale `.next` that the `plan` guard catches; a run that died after the two synthesis files but before `.next` would otherwise exit 6 on rerun and its facts would never reach `facts.jsonl`.

Then validate:

```bash
./.vault_link/.scripts/synthesize_run.sh report --week <W>   # add --unattended in unattended mode
```

Exit 0 prints the summary line, one line per open contradiction and one per pending proposal; then run `mv facts.jsonl.next facts.jsonl` inside `03_Brain/Weekly_Synthesis/`. Exit 3 is E3: leave `facts.jsonl.next` in place, never repair it, and do not touch `facts.jsonl`.

### Step 8 - HALT
When any `pending` proposal or any open contradiction exists, interactive mode shows each one in chat and stops. Unattended mode surfaces each one per `## UNATTENDED MODE` and ends. Nothing is promoted and no contradiction is resolved in either mode; promotion needs the Architect and `/graduate` (see `## OPERATOR DECISION`).

### Step 9 - Telemetry
Append one daily-log line per report line (the summary first, then each contradiction, then each proposal), then emit telemetry, then confirm:

```bash
./.vault_link/.scripts/append_log.sh --date <Israel today> --entry "<line>" --source-persona Synthesizer
./.vault_link/.scripts/emit_telemetry.sh synthesize <success|error> auto <error class|null> Synthesizer
```

`<Israel today>` is `TZ=Asia/Jerusalem date +%Y-%m-%d`. Every run, success or error, appends exactly one summary line and emits one `synthesize` record. Finish with the kernel confirm line: `Macro synthesize completed in <ms> ms. Telemetry emitted.`, taking `<ms>` from the `duration_ms` of the row just emitted.

Interactive line templates (UNATTENDED MODE owns the `(unattended)` ones; the step vocabulary is the same):
- Error: `Synthesize <W> (interactive): error <class> at <step>: <reason>. Report: [[<report basename>]].` The error report goes under `04_Logs/Errors/`, per the Universal Error Contract.
- Skipped: `Synthesize <W> (interactive): skipped, already synthesized.` and `Synthesize <W> (interactive): skipped, no logs in <monday>..<sunday>.`

With these templates every run, interactive or unattended, success, skipped or error, appends exactly one summary line. Step 2 and Step 3 route every early exit here. When `scope` exits 4 after `report` exited 0 (Step 7's `mv` has landed), the run still appends every contradiction line and proposal line that `report` printed, after its error summary line, whose reason reads `out-of-scope writes <paths>; synthesis written, <n> surfacing lines appended`; see `## UNATTENDED MODE`.

## UNATTENDED MODE

This section is the single owner of every rule for a scheduled, unattended run. `synthesize_scheduled_task_prompt.md` only points here, and nothing in the prompt overrides it. The default post-boot ritual (which would rewrite the legacy `.session_state.json`) is replaced by the keyed handshake below.

- Week first: `./.vault_link/.scripts/synthesize_run.sh week` prints the previous ISO week of the Israel date. It is read-only and runs before the handshake, so every later error path knows W. If `week` itself fails, W is the literal `week-unknown` for the error report name and the summary line. Exactly one week per run. No backfill: an unattended run never processes any week other than the one `synthesize_run.sh week` prints, and never loops over missing weeks.
- Handshake as the Synthesizer: `./.vault_link/.scripts/session_state_write.sh --persona Synthesizer --session-id synth-<UTC compact timestamp> --started-at <ISO> --no-legacy-mirror`, for example `synth-20261130T060000Z`. Never write the legacy `.session_state.json`, which would rebind a concurrent Executioner session or an orchestrator loop. Call every persona-checked atom with the inline prefix `TITAN_SESSION_ID=<session id>`. Record `git rev-parse HEAD` after the handshake.
- Order:
  - Start: `telemetry_start.sh synthesize`.
  - Week: `./.vault_link/.scripts/synthesize_run.sh week`.
  - Handshake: `./.vault_link/.scripts/session_state_write.sh` as above.
  - Step 1 with the `TITAN_SESSION_ID=<id>` prefix.
  - Record `git rev-parse HEAD`.
  - Steps 2-7, with `report --unattended`.
  - Scope check: `./.vault_link/.scripts/synthesize_run.sh scope --session-id <id> --head <sha>`. It runs on every path after a successful handshake. When the handshake failed there is no marker, so the scope check is skipped and the final message says so.
  - Step 9, which also performs the unattended Step 8 surfacing (below).
  - Final message.
- Summary line for every error class, one generic template: `Synthesize <W> (unattended): error <class> at <step>: <reason>. Report: [[<report basename>]].` `<step>` is one of `week`, `handshake`, `persona`, `plan`, `synthesis`, `report`, `scope`, `log`.
- Every error path writes one report to `04_Logs/Errors/<date>_E<n>_synthesize_<W>.md` (from `00_Templates/Error_Report_Template.md`; the report basename is that file name without `.md`), appends its summary line, emits `emit_telemetry.sh synthesize error auto <class> Synthesizer`, and stops (except the scope-E4 surfacing, see the E4 bullet). Nothing is retried except E2, which is retried once. When the failing step is `log` itself (append_log failed twice), the line cannot be written; telemetry is still emitted and the final message says the line is missing. Per class:
  - E1: `week` exit 1 (step `week`), or `plan` exit 1 (step `plan`).
  - E2: an atom or tool command fails unexpectedly: session_state_write (step `handshake`), append_log (step `log`), or a file write (step `synthesis`). Retry once, then report.
  - E3: `plan` exit 3 (step `plan`) or `report` exit 3 (step `report`). Leave `facts.jsonl.next` and never repair it. `plan` exit 3 for `unresolved facts.jsonl.next` is reported, never deleted; recovery is delete-only per Step 2.
  - E4: persona_check fails (step `persona`), or `scope` exits 4 (step `scope`, where the reason lists the offending paths). Nothing is reverted. When `scope` exits 4 after `report` exited 0 (Step 7's `mv` has landed), the run still appends every contradiction line and proposal line that `report` printed, after its error summary line, because a later `plan` for that week exits 6 and those lines would otherwise never reach the daily log. The error summary line uses the generic template with the reason `out-of-scope writes <paths>; synthesis written, <n> surfacing lines appended` (n = contradiction lines + proposal lines, 0 allowed). Telemetry is `emit_telemetry.sh synthesize error auto E4 Synthesizer`, and the error report is written as for any E4.
  - E5: context saturation (step `synthesis`). Stop with no resume.
  - Not errors: `plan` exit 6 gives `Synthesize <W> (unattended): skipped, already synthesized.` A run with `logs=0` writes no outputs and gives `Synthesize <W> (unattended): skipped, no logs in <monday>..<sunday>.` Both emit success.
- Write allowlist: An unattended run writes only inside `03_Brain/Weekly_Synthesis/` and `04_Logs/`, plus its own keyed session file. Never edit any other `03_Brain/` file. Never write `01_Projects/`, `02_Tasks/`, boards, `Needs_Attention.md` or `05_Content/`. Never call `queue_attention.sh`.
- Never run `/graduate`. Do not commit anything. Run no git add, commit, stash, checkout or reset. Never ask questions. Never start headless `claude -p`.
- Surfacing channel (Step 8 in unattended mode): each open contradiction and each pending proposal is surfaced in two places.
  - The daily log `04_Logs/<Israel date>.md` gets one line each, through `append_log.sh` in Step 9. It is the vault's persistent record, the operator reads it in Obsidian, and it is outside `03_Brain/`. Boot step 4 loads only the newest daily log, so those lines are in a session's boot context only until a later daily log exists.
  - The run's final message carries every line as well.
- Final message: week, outcome (success, skipped with reason, or error class with step), logs read, facts added, each open contradiction (fact ids, one-line summary), each pending proposal (id, target file, one-line rule), scope result, the log lines written, telemetry emitted yes or no, and every command that failed, with its exit code and last output lines.

## OPERATOR DECISION

Promotion and resolution stay human. None of these run unattended, and all edits stay inside `03_Brain/Weekly_Synthesis/`.
- Approve: an interactive Architect session runs `/graduate` with the proposal text, under per-change approval. After promotion, the Synthesizer sets that proposal's `status` to `promoted` and adds `promoted_at` in the week's JSON.
- Reject: the operator tells a Synthesizer session "reject <id>", and it sets `status` to `rejected` in that JSON.
- Contradiction: a Synthesizer session resolves the pair with the operator, updates both facts, and sets the entry's `status` to `resolved`.

## SCHEDULING

- Default schedule, overridable: Monday 09:00 Israel (Asia/Jerusalem), cron `0 9 * * 1` in local time, processing the previous ISO week.
- Host: a Claude desktop-app scheduled task named `weekly-synthesize`, subscription-billed, whose prompt is the body of `synthesize_scheduled_task_prompt.md`. Never headless `claude -p` or API credits. This supersedes the 2026-10-30 rejection of Schedule_Weekly_Synthesis_Cron, whose only blocker was `claude -p`.
- The scheduled task is created only after the operator confirms one manually started unattended-mode run on his machine. Steps:
  1. The operator opens a fresh Claude desktop session in the vault and pastes the prompt body.
  2. He checks the daily-log lines, the two outputs, the telemetry row and the scope result, and confirms.
  3. Only then does a main session create the task, using the desktop scheduled-task tool exactly as for the Twitter tasks.
  4. The Mac must be awake at the start time.
- No backfill of 2026-W21 through the week before the first run. A missed week is synthesized only when the operator runs `/synthesize <week>` interactively.

## INSTALL

`ln -s ../../.scripts/runbooks/synthesize.md .claude/commands/synthesize.md` (per-machine, because `.claude/` is gitignored; the scheduled prompt uses the runbook path directly and does not depend on it).

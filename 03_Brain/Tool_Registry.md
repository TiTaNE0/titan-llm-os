# Tool Registry

> **Principle:** Macros are orchestration, tools are atoms. Tools live here with explicit input/output/error contracts. Macros invoke tools, never inline shell logic.

This is the canonical list of atomic operations available to any macro. Adding a tool requires Architect approval.

---

## Tool Manifest

### `create_task`
- **Inputs:** `title: str`, `project: str`, `priority: enum[low,medium,high]`, `source_persona: str`, `objective: str` *(optional — populates `§ Declarative Objective`; placeholder kept if omitted; added 2026-06-17 via [[Task_Contract_Population_And_Guard]])*
- **Outputs:** Path to created file in `02_Tasks/<project>/`
- **Pre-conditions:** Project passport exists at `01_Projects/<project>.md`; no existing task with same title in `02_Tasks/` OR `99_Archive/Tasks/` (wiki-links resolve by basename — uniqueness is global)
- **Errors:** E1 if project passport missing; E3 if title collides (live or archived) or args invalid; E4 if persona ≠ Executioner
- **Idempotent:** ❌ (write-once)
- **Persona Gate:** Executioner (source-persona arg + `persona_check.sh`)
- **Script:** `.vault_link/.scripts/create_task.sh`
- *(Implemented 2026-06-14 by [[Orchestrator_A1_Create_Task_Atom]] — the Phase 0 contract was registered but never built. Priority enum corrected `med` → `medium` to match `Task_Template`, the `/new_task` macro, and all existing tasks; ratified via /graduate 2026-06-15 Phase B.)*

---

### `update_kanban`
- **Inputs:** `--board <path>` `--task-link <[[Name]]>` `--from <column>` `--to <column>` `--source-persona <name>`
- **Outputs:** Updated board file (`*_Board.md`); the line containing `--task-link` is removed from the `--from` section and inserted at the top of the `--to` section. Atomic via mktemp + mv. On **stderr** (only if non-zero): single-line E-class message.
- **Insertion mode (`--from none`):** for a task with no source section yet (new-task creation, e.g. `/new_task`), pass `--from none`. The atom synthesizes the line `- [ ] <task-link>` and inserts it at the top of `--to`, removing nothing. Idempotent (no-op if already in `--to`).
- **Pre-conditions:**
    - `--board` file exists
    - Task link literally appears in the `--from` section — **except `--from none`** (insertion mode), where no source section is required
    - **`source_persona` arg equals live session persona** (persona-origin guard, Composition Rule 5)
    - **Live session persona is allowed by this atom's Persona Gate** (see below)
- **Errors:**
    - E1 if `--board` file missing
    - E3 if task not found in `--from` section (precondition fail OR YAML/Kanban drift)
    - **E4 if `source_persona` arg != live persona, OR live persona not allowed by Persona Gate**
- **Idempotent:** ✅ (re-running with same args is no-op if task is already in `--to` and not in `--from`)
- **Persona Gate:** **Executioner** — enforced via `persona_check.sh`. *Phase 2 scope: only `/execute_task` calls this atom (Executioner-only invocations). Synthesizer access for Delegated-column transitions is deferred to Phase 3 alongside `/delegate` and `/recall` implementation; `persona_check.sh` will need any-of-list support at that time.*
- **Telemetry:** MANDATORY per Composition Rule 3; calls `emit_telemetry.sh` per Rule 1 carve-out
- **Called by:** `/execute_task` Step 7 (Todo → In Progress); future `/close_task` (In Progress → Done) and `/delegate`/`/recall` (Phase 3)
- **Dependencies:** None (uses `awk`, `sed`, `mktemp`)
- **Script:** `.vault_link/.scripts/update_kanban.sh`
- *(CLI signature firmed 2026-05-28 by [[TiTan_Kit_Integration_Phase2]] — original Phase 0 entry was contract-only with no implementation; added explicit CLI flags, persona-origin guard semantics, atomic-write requirement, telemetry mandate, script path, and Phase-2-scoping note for Synthesizer support.)*
- *(`--from none` insertion mode added 2026-06-07 via `/graduate` (ratified with doc+script together) — closes the gap where `/new_task` step 5 documented `from_column=none` but the atom could only move existing lines, forcing manual board edits.)*

---

### `append_log`
- **Inputs:** `date: ISO`, `entry: str`
- **Outputs:** Line appended to `04_Logs/<date>.md`
- **Pre-conditions:** None (file auto-created)
- **Errors:** E2 if filesystem write fails
- **Idempotent:** ❌ (always appends)
- **Persona Gate:** Any

---

### `archive_file`
- **Inputs:** `source: str`, `dest: str`
- **Outputs:** File moved (preserves git history via `git mv` if applicable)
- **Pre-conditions:** `source` exists; `dest` parent directory exists
- **Errors:** E1 if source missing; E2 if dest exists
- **Idempotent:** ❌
- **Persona Gate:** Executioner

---

### `populate_summary`
- **Inputs:** `task_path: str`, `summary: dict[technical_meat, deviations, debt, proof]`
- **Outputs:** Task file with `## 🏁 COMPLETION SUMMARY` filled in
- **Pre-conditions:** Task file has the section header
- **Errors:** E3 if section missing or already populated
- **Idempotent:** ❌
- **Persona Gate:** Executioner

---

### `scan_inbox`
- **Inputs:** None
- **Outputs:** List of files in `00_Inbox/` with detected project link or `null`
- **Errors:** None (read-only)
- **Idempotent:** ✅
- **Persona Gate:** Researcher, Executioner

---

### `route_inbox_file`
- **Inputs:** `source: str`, `project: str | null`, `target_section: str`
- **Outputs:** File content extracted and routed; raw deleted from `00_Inbox/`
- **Errors:** E1 if source missing; E4 if project link points to nonexistent project
- **Idempotent:** ❌
- **Persona Gate:** Researcher

---

### `extract_facts`
- **Inputs:** `log_paths: list[str]`
- **Outputs:** List of candidate fact records (per `Memory_Schema.md`)
- **Errors:** None (analysis-only, never writes)
- **Idempotent:** ✅
- **Persona Gate:** Synthesizer

---

### `write_fact`
- **Inputs:** `fact: FactRecord` (per `Memory_Schema.md`)
- **Outputs:** Append to `03_Brain/Weekly_Synthesis/facts.jsonl`
- **Errors:** E3 if fact id collision
- **Idempotent:** ✅ (with same id, updates existing)
- **Persona Gate:** Synthesizer

---

### `emit_telemetry`
- **Inputs:** `record: TelemetryRecord` (see Section "Telemetry Schema")
- **Outputs:** JSONL line appended to `04_Logs/Telemetry/<YYYY-MM>.jsonl`
- **Errors:** None (best-effort; never blocks macro execution)
- **Arg validation:** flag-style args (`--*`), arg count outside 2–6, or non-numeric `duration_ms` → no JSONL write; rejection logged to `.write_failures.log`; exit stays 0 per the never-blocks contract. *(Added 2026-07-07 via /graduate, [[Brain_Audit_Drift_Repair]] — closes the corrupt-record hole at 2026-06.jsonl:556.)*
- **Idempotent:** ❌
- **Persona Gate:** Any

---

## Subagent Engine Atoms

> **Added by [[TiTan_Kit_Integration_Phase1]] (Phase 1, 2026-05-28).**
> These atoms exist solely to compose the `claude-agent-kit` 7-agent chain into the
> `/execute_task` macro. They are NOT general-purpose — they are Executioner-only and
> assume the project has a `.vault_link/` at the repo root.

> **Augmented by [[TiTan_Kit_Integration_Phase2]] (Phase 2, 2026-05-28):** the four helper atoms below (`session_state_write`, `persona_check`, `grep_section`, `in_progress_lock`) were specced in Phase 2 but inadvertently omitted from the Phase 1 Tool_Registry batch. Added retroactively when the omission surfaced during Phase 2's draft-2 build. Each entry reflects the script's actual behavior (e.g., `persona_check` outputs to stderr, not stdout — corrected per Phase 2 § Deviations during execution).

---

### `session_state_write`
- **Inputs:** `--persona <name>` `--session-id <id>` `--started-at <ISO ts>` `--surface <name>` (optional; default `claude-code`)
- **Outputs:** Writes `.vault_link/.session_state.json` atomically (mktemp + mv). On **stderr** (only if exit 2): single-line E2 message naming the failure (missing arg, mktemp failure, mv failure).
- **Pre-conditions:** Vault dir is writable; script auto-resolves vault location via `pwd -P` from its own directory.
- **Errors:** E2 only (filesystem write failure OR missing required arg).
- **Idempotent:** ❌ (each call overwrites — new session, new state)
- **Persona Gate:** Any (handshake context — no live persona to check yet; this script is what BINDS the persona for subsequent atoms)
- **Telemetry:** MANDATORY per Composition Rule 3 (write tool); calls `emit_telemetry.sh` per Rule 1 carve-out; best-effort, never blocks
- **Called by:** [[Context_Injection_Protocol]] § 1.5 Post-Boot Ritual; re-executed at every refresh trigger per § 4
- **Dependencies:** None (no `jq`; uses heredoc + `mktemp` + `mv`)
- **Script:** `.vault_link/.scripts/session_state_write.sh`

---

### `persona_check`
- **Inputs:** `$1` = expected persona name (e.g., `Executioner`)
- **Outputs:** Exit 0 if `.vault_link/.session_state.json` exists AND its `persona` field == `$1`. Else exit 4. On **stderr** (only if exit 4): single-line E4 message naming the mismatch (or the root cause: missing state file, missing `jq`, malformed JSON, missing/empty persona field, persona mismatch).
- **Pre-conditions:** None (script handles all failure modes by collapsing to E4)
- **Errors:** E4 only (file missing, malformed, persona missing, persona mismatch, missing `jq` — all collapse to E4 per spec)
- **Idempotent:** ✅ (read-only)
- **Persona Gate:** Any (this script IS the persona gate; using it does not require being a particular persona)
- **Telemetry:** None (read-only per Composition Rule 4)
- **Called by:** `/execute_task` slash command pre-flight; `write_task_section.sh` as a precondition before any mutation
- **Dependencies:** `jq` (with friendly missing-tool E4 check if not installed)
- **Script:** `.vault_link/.scripts/persona_check.sh`

---

### `grep_section`
- **Inputs:** `$1` = file path; `$2` = section name (e.g., `"Research Notes"`); `$3` = mode `present | empty | populated` (optional; default `present`)
- **Outputs:** Exit 0 on match, exit 1 on no-match, exit 3 on header-not-found. On **stderr** (only if exit 3): single-line E3 message.
- **Pre-conditions:** `$1` exists as a regular file; `$3` (if provided) is one of the three modes
- **Errors:** E3 (header not found, file missing, invalid mode arg)
- **Idempotent:** ✅ (read-only)
- **Persona Gate:** Any
- **Telemetry:** None (read-only per Composition Rule 4)
- **Called by:** `/execute_task` slash command (steps 6 and 12); promoted as canonical emoji-tolerant section matcher in `Task_Template.md` Verification Gateway prose (per Phase 1 OQ#5 amendment)
- **Dependencies:** None (uses `awk`)
- **Mode semantics:** `present` = header exists, body irrelevant. `empty` = header exists AND body is only blockquote, blank, **or HTML-comment** lines (`<!-- ... -->`; anchor markers are infrastructure, not content). `populated` = header exists AND body has non-blockquote, non-HTML-comment content. *(Amended 2026-05-28 from "blockquote/blank lines only" — anchor comments like `<!-- write_task_section section=X -->` would otherwise mark fresh-templated sections as populated and break the `/execute_task` step 6 cache check; user-authorized one-line correction during Phase 2 build, no Architect round-trip; deviation logged in [[TiTan_Kit_Integration_Phase2]] § Deviations during execution.)*
- **Header regex:** `^##\s+(\S+\s+)?<section name>\s*$` — leading emoji or marker token optional, supports both `## 🔬 Research Notes` and `## Research Notes`
- **Script:** `.vault_link/.scripts/grep_section.sh`

---

### `in_progress_lock`
- **Inputs:** `$1` = project name (e.g., `TiTan_LLM_OS`); `$2` = current task basename (without `.md`; excluded from scan to allow resume)
- **Outputs:** Exit 0 if no OTHER **non-epic** task in `.vault_link/02_Tasks/<project>/*.md` has YAML `status: in_progress`. Tasks with `type: epic` are skipped (exempt — see [[System_Agents]] § /execute_task step 5). Else exit 3 + prints offending task basename on stdout.
- **Pre-conditions:** `.vault_link/02_Tasks/<project>/` directory exists (empty dir is fine — yields exit 0)
- **Errors:** E3 only (another in-progress task found)
- **Idempotent:** ✅ (read-only)
- **Persona Gate:** Any (caller will already have passed `persona_check Executioner` if invoked from `/execute_task`)
- **Telemetry:** None (read-only per Composition Rule 4)
- **Called by:** `/execute_task` slash command step 5
- **Dependencies:** None (uses `grep`/`awk` on YAML)
- **Script:** `.vault_link/.scripts/in_progress_lock.sh`

---

### `task_contract_check`
- **Inputs:** `--task-path <abs>`
- **Outputs:** Refuses to execute a task whose header contract is still template placeholders. Checks `§ Declarative Objective`, `§ Definition of Done`, `§ Verification Gateway` for the exact `Task_Template` placeholder LINES (whole-line match — prose that merely mentions the strings is not a false positive).
- **Errors:** exit 0 authored ("CONTRACT: OK"); exit 3 a placeholder remains (names the section on stderr); E2 bad args / file missing.
- **Idempotent:** ✅ (read-only). **Persona Gate:** any. **Telemetry:** none (read-only per Composition Rule 4).
- **Called by:** `/execute_task` Step 5.5 (pre-research guard); the Orchestrator tick routes a failure to `queue_attention`.
- **Script:** `.vault_link/.scripts/task_contract_check.sh`
- *(Added 2026-06-17 by [[Task_Contract_Population_And_Guard]]; registered via /graduate. Companion change: `create_task` gained optional `--objective` to populate `§ Declarative Objective` at creation.)*

---

### `author_contract`
- **Inputs:** `--task-path <abs>` `--section <objective|dod|gateway>` `--content-file <abs>` `--source-persona <name>` `[--overwrite]`
- **Outputs:** Authors a task's HEADER contract section (Declarative Objective / Definition of Done / Verification Gateway), located by header text, through a guarded script — so an existing task's contract can be filled without an inline `.md` Edit (which the harness blocks). Atomic; refuses an already-authored section unless `--overwrite`.
- **Errors:** E1 task/content missing or mv fail; E3 missing/invalid args, header not found, or already-authored without `--overwrite`; E4 persona.
- **Idempotent:** ❌ (write). **Persona Gate:** Executioner. **Telemetry:** MANDATORY.
- **Called by:** `/new_task` at creation — its contract step authors `§ Definition of Done` + `§ Verification Gateway` (objective seeded by `create_task --objective`); and human/agent to fill or repair a contract on an existing task ahead of the `task_contract_check` guard (`/execute_task` Step 5.5).
- **Script:** `.vault_link/.scripts/author_contract.sh`
- *(Added 2026-06-17 — completes the population half of [[Task_Contract_Population_And_Guard]], whose guard shipped ahead of a full authoring path; registered via /graduate.)*

---

### `invoke_researcher`
- **Inputs:** `task_path: str`, `refresh: bool = false`
- **Outputs:** Research report (markdown). Subagent reads vault read-only paths plus repo source.
- **Pre-conditions:** `task_path` exists; project root has `.vault_link/`
- **Errors:** E1 if `task_path` missing or no vault; E4 if persona != Executioner; E2 if subagent invocation fails (retry once, then halt with exact error)
- **Idempotent:** ✅ when `refresh=false` AND task .md `## Research Notes` already populated (returns cached content from the task file itself, no subagent spawn); ❌ otherwise
- **Persona Gate:** Executioner

---

### `invoke_spec_writer`
- **Inputs:** `task_path: str`
- **Outputs:** Spec content (markdown)
- **Pre-conditions:** `task_path` exists; `## Research Notes` already populated in the task file
- **Errors:** E1 if pre-conditions fail (must run `invoke_researcher` first); E4 if not Executioner; E2 if subagent fails
- **Idempotent:** ❌ (re-runs always; LLM output varies)
- **Persona Gate:** Executioner

---

### `invoke_builders`
- **Inputs:** `task_path: str`, `spec: str`
- **Outputs:** Combined builder report `{backend: ..., frontend: ..., api_contract: ...}`. Side effect: modifies repo source code.
- **Pre-conditions:** `task_path` exists with `## Spec` populated; source-code gate UNLOCKED
- **Errors:** E1 if pre-conditions fail; E4 if not Executioner OR source-code gate locked; E2 if either subagent fails OR violates its lane (UI subagent writing backend files, etc.)
- **Idempotent:** ❌ (rewrites code; leaves git diff)
- **Persona Gate:** Executioner

---

### `invoke_test_verifier`
- **Inputs:** `task_path: str`, `story: str`
- **Outputs:** `{coverage_map: ..., run_result: PASS|FAIL, bugs: [...]}`. Side effect: writes test files.
- **Pre-conditions:** `task_path` exists; `## Spec` populated; `invoke_builders` has completed
- **Errors:** E1 if pre-conditions fail; E4 if not Executioner; E5 if test fails AND no bugs reported (suggests test-infra issue, not code defect)
- **Idempotent:** ❌
- **Persona Gate:** Executioner

---

### `invoke_validator`
- **Inputs:** `task_path: str`
- **Outputs:** `{verdict: SHIP|FIX|BLOCK, critical: [...], important: [...], minor: [...], good: [...]}`
- **Pre-conditions:** `task_path` exists; `## Spec` populated; builders ran; test-verifier ran with PASS
- **Errors:** E1 if pre-conditions fail; E4 if not Executioner; E2 if subagent fails
- **Idempotent:** ✅ (read-only; safe to re-run, though report content varies)
- **Persona Gate:** Executioner

---

### `write_task_section`
- **Inputs:** `task_path: str`, `section: enum[research_notes, spec, validator_report, verification_output]`, `content: str`, `source_persona: str`, `overwrite: bool = false`
- **Outputs:** Updated task .md with the named section populated
- **Pre-conditions:**
    - `task_path` exists
    - **`source_persona` argument equals the live session persona** (verified by atom against session state, NOT trusted from caller input — see Composition Rule 5)
    - Live session persona == `Executioner`
    - Section is currently empty, OR `overwrite=true` (allowed only during test-verifier bug-loop iterations on the `verification_output` section)
- **Errors:**
    - E1 if `task_path` missing
    - **E4 if `source_persona` arg ≠ live session persona** (persona-origin guard — the core safety property; a kit subagent cannot satisfy this even if it acquired the atom)
    - **E4 if live session persona ≠ Executioner**
    - E3 if section already populated and `overwrite=false`
- **Idempotent:** ❌ (always writes; `overwrite=true` replaces existing content)
- **Persona Gate:** Executioner (enforced via persona-origin guard at runtime, not by declaration alone)
- **Telemetry:** MANDATORY; `args_hash = sha1(task_path + section + sha1(content) + source_persona + overwrite)` — section identifier is hashed with the rest to avoid leaking content position

---

### `set_task_status`
- **Inputs:** `--task-path <abs>` `--from-status <enum>` `--to-status <enum>` `--source-persona <name>`
  - `<enum>` ∈ `{ todo, in_progress, done, blocked, delegated }` (extensible; atom validates against allowed set)
- **Outputs:** Updated task .md with YAML `status:` field changed. **Atomic via mktemp + awk-to-temp + mv (NOT in-place sed)** — temp file is generated by awk transformation, then renamed over the original. On **stderr** (only if non-zero): single-line E-class message.
- **Pre-conditions:**
    - `task_path` exists
    - YAML `status:` field (in the first frontmatter block between `---` markers) currently equals `from_status`
    - **`source_persona` arg equals live session persona** (persona-origin guard, Composition Rule 5)
    - **Live session persona == `Executioner`** (verified via `persona_check.sh`)
- **Errors:**
    - E1 if `task_path` missing
    - E3 if current YAML status != `from_status` (precondition fail — caller's view of state is stale, OR YAML/Kanban drift suspected)
    - E3 if `from_status` or `to_status` is not in the allowed enum
    - **E4 if `source_persona` arg != live session persona** (persona-origin guard)
    - **E4 if live session persona != Executioner**
- **Idempotent:** ✅ in the sense that re-running with the same `from_status` after a successful flip yields E3 (status no longer matches `from`) — same observable end-state as no-op, just loud. Caller should not blindly retry.
- **Persona Gate:** **Executioner** (enforced via `persona_check.sh` exit code, NOT by declaration alone — same pattern as `write_task_section`).
- **Telemetry:** MANDATORY per Composition Rule 3; calls `emit_telemetry.sh` per Rule 1 carve-out; `args_hash = sha1(task_path + from_status + to_status + source_persona)`.
- **Called by:** `/execute_task` Step 7 (`todo` → `in_progress` after Kanban move). Future macros: `/close_task` (`in_progress` → `done`), `/recall` (revert), `/delegate` (→ `delegated`).
- **Dependencies:** None (uses `awk`, `mktemp`, `mv`).
- **Body-safety property:** YAML-only mutation. The atom transforms ONLY the YAML frontmatter block (between the first two `---` markers); task body markdown is never touched — important because body prose may legitimately contain phrases like `` `status: in_progress` `` (e.g., spec text referencing other tasks), and the atom must not false-positive on those.
- **Script:** `.vault_link/.scripts/set_task_status.sh`
- *(Added 2026-05-28 by [[TiTan_Kit_Integration_Phase2]] to close the YAML-status-mutation gap discovered while drafting the `/execute_task` slash command. Without this atom, Step 7 of the slash command would require an inline bash mutation outside `write_task_section.sh`'s scope, which would create a precedent for Hard Rule bending. User-decided 2026-05-28 to build the atom rather than document the bend.)*

---

### `session_state_cleanup`
- **Inputs:** `[--session-id <id>]` `[--max-age-hours <N>]` `[--dry-run]`
- **Outputs:** Removes stale `.session_state.<id>.json` files. Sweep mode (no `--session-id`) deletes keyed files older than `--max-age-hours` (default 24); `--session-id` removes one file regardless of age. NEVER touches the legacy singleton `.session_state.json`. On **stdout**: per-file `removed`/`would remove` lines + a summary.
- **Pre-conditions:** None (script resolves vault via `pwd -P`)
- **Errors:** E2 (invalid args); E3 (`--session-id` given but no matching file)
- **Idempotent:** ✅ (a second sweep removes nothing new)
- **Persona Gate:** Any (housekeeping; only ever touches the `.session_state.<id>.json` pattern)
- **Telemetry:** MANDATORY (self-emits via `emit_telemetry.sh`)
- **Script:** `.vault_link/.scripts/session_state_cleanup.sh`
- *(Added 2026-06-14 by [[Orchestrator_A2_Session_State_Isolation]]; registered via /graduate 2026-06-15 Phase B.)*

---

### `queue_attention`
- **Inputs:** `--task <[[Name]]|Name>` `--state <enum>` `--source <enum>` `--run-id <id>` `--reason <text>` `--source-persona <name>` `[--queue-file <path>]`
  - `state` ∈ `{ spec_gate, close_gate, retries_exhausted, no_progress, orphaned_lock, panel_escalate }`
  - `source` ∈ `{ orchestrator, pm_reviewer, failure_panel }`
- **Outputs:** Appends ONE entry line under `## Open` in `Needs_Attention.md` (vault root; seeded from `00_Templates/Needs_Attention_Template.md` if absent). Atomic (mktemp + mv). Line format: `- [ ] [[<task>]] | state: <s> | source: <src> | run_id: <id> | queued: <ISO> | reason: <text>` (aligns with [[Orchestrator_PRD_v2]] § 5).
- **Pre-conditions:** Queue parent dir exists; `source_persona` arg == live persona (Executioner)
- **Errors:** E1 (queue parent missing / write fail); E3 (missing/invalid args); E4 (persona)
- **Idempotent:** ✅ (no-op when an UNCHECKED entry with the same task+state+run_id exists; a resolved/checked entry permits re-escalation)
- **Persona Gate:** Executioner (the loop dispatches as Executioner; `source` is a data field, not the executor)
- **Telemetry:** MANDATORY (self-emits via `emit_telemetry.sh`)
- **Script:** `.vault_link/.scripts/queue_attention.sh`
- *(Added 2026-06-14 by [[Orchestrator_A3_Needs_Attention_Queue]]; registered via /graduate 2026-06-15 Phase B.)*

---

## Orchestrator Loop Atoms (Phase C)

> Registered via /graduate 2026-06-15 Phase C. Built by [[Orchestrator_C1_Run_Loop_And_Dispatch]] – [[Orchestrator_C4_Stale_Lock_Recovery]]. They compose the autonomous outer loop ([[Orchestrator_PRD_v2]]); the `/orchestrator_tick` macro orchestrates them. Read-only atoms emit no telemetry (Composition Rule 4).

### `fetch_next_task`
- **Inputs:** `--project <name>` `[--board <path>]` `[--tasks-dir <path>]`
- **Outputs:** Next eligible task basename from the project's Todo column on stdout — status `todo`, `type != epic`, not `blocked`; priority high>medium>low, board order as tiebreak (§4.1).
- **Errors:** exit 1 if no eligible task (the loop STOP signal); E2 bad args / board missing.
- **Idempotent:** ✅ (read-only). **Persona Gate:** any. **Telemetry:** none.
- **Script:** `.vault_link/.scripts/fetch_next_task.sh`

### `run_digest`
- **Inputs:** `--run-id <id>` `--line <text>` `[--digest-dir <path>]`
- **Outputs:** Appends one ISO-stamped line to `04_Logs/Orchestrator/<run_id>.md` (header created if absent). The REPORT primitive (§3); run-keyed, distinct from date-keyed `append_log`.
- **Errors:** E2 bad args / write failure.
- **Idempotent:** ❌ (always appends). **Persona Gate:** any. **Telemetry:** none (logging primitive).
- **Script:** `.vault_link/.scripts/run_digest.sh`

### `spec_rubric`
- **Inputs:** `--task-path <abs>`
- **Outputs:** Deterministic FORM layer of the spec gate (§4.4 layer 1): spec populated + file-change list present + zero open-question markers. The semantic layer is the `pm-reviewer` subagent.
- **Errors:** exit 0 PASS; 3 rubric FAIL (reason on stderr); E2 bad args / file missing.
- **Idempotent:** ✅ (read-only). **Persona Gate:** any. **Telemetry:** none.
- **Script:** `.vault_link/.scripts/spec_rubric.sh`

### `panel_guard`
- **Inputs:** `--task <name>` `--run-id <id>` `[--state-file <path>]`
- **Outputs:** Enforces the failure panel convenes at most once per task per run (§4.3). First convene exit 0; repeat exit 3 (escalate, do not re-panel).
- **Errors:** E2 bad args.
- **Idempotent:** ❌ (records convene state). **Persona Gate:** any. **Telemetry:** none.
- **Script:** `.vault_link/.scripts/panel_guard.sh`

### `task_owner`
- **Inputs:** `--task-path <abs>` `[--run-id <id> --source-persona <name>]` `[--get]`
- **Outputs:** Stamps/reads `orchestrator_run_id` in task YAML (run-ownership marker, §6). Set is atomic (mktemp+mv); `--get` prints the current value.
- **Errors:** E1 task missing / write fail; E3 missing args; E4 persona (set only).
- **Idempotent:** ❌ on set (last write wins); ✅ on `--get`. **Persona Gate:** Executioner (set); any (`--get`). **Telemetry:** MANDATORY on set.
- **Script:** `.vault_link/.scripts/task_owner.sh`

### `stale_lock_scan`
- **Inputs:** `--project <name>` `--live-run-id <id>` `[--tasks-dir <path>]`
- **Outputs:** Prints in_progress, non-epic task basenames carrying a DEAD (≠ live) `orchestrator_run_id` — orphans to queue (§6). Unstamped / live-owned / todo / epic are skipped.
- **Errors:** E2 bad args / dir missing.
- **Idempotent:** ✅ (read-only). **Persona Gate:** any. **Telemetry:** none.
- **Script:** `.vault_link/.scripts/stale_lock_scan.sh`

### `budget_check`
- **Inputs:** `--run-id <id>` `--ceiling <minutes>` `[--digest-dir <path>]`
- **Outputs:** Wall-clock minutes since the run's first digest line, checked against `budget.max_minutes` (§3 BUDGET). Exit 0 under the ceiling (or no digest lines yet); exit 3 when elapsed >= ceiling → the tick writes a `stop` line.
- **Errors:** E2 invalid args / missing digest file / unparseable timestamp; E3 ceiling reached.
- **Idempotent:** ✅ (read-only). **Persona Gate:** any. **Telemetry:** none.
- **Script:** `.vault_link/.scripts/budget_check.sh`
- *(Built by [[Orchestrator_Budget_Measurement]]; registered via /graduate 2026-10-30. Epoch parse pins `TZ=UTC` — BSD date reads the literal `Z` as local time otherwise.)*

---

### `resolve_attention`
- **Inputs:** `--task <[[Name]]|Name>` `--state <enum>` `--run-id <id>` `--resolution <fixed_code|fixed_spec|fixed_brief|fixed_brain|wont_fix|duplicate|promoted>` `--source-persona <name>` `[--note <single-line text>]` `[--queue-file <path>]`
- **Outputs:** Flips the first UNCHECKED `- [ ]` entry under `## Open` matching the `(task, state, run_id)` triple to `- [x]` and appends ` | resolved: <class> | resolved_at: <ISO8601Z> [| note: <text>]`. Atomic via mktemp + mv. The `resolved:` class is the countable field consumed by `/retrospective`.
- **Pre-conditions:** Queue file exists; a matching open entry exists (or the matching entry is already checked → idempotent no-op).
- **Errors:** E1 queue file missing / write failure; E3 invalid args, invalid resolution class, newline in `--note`, or no matching open entry; E4 persona.
- **Idempotent:** ✅ (already-resolved matching entry → exit 0 no-op, no double-append)
- **Persona Gate:** Executioner (source-persona arg + `persona_check.sh`)
- **Telemetry:** MANDATORY (`resolve_attention` record; per Rule 1 carve-out)
- **Script:** `.vault_link/.scripts/resolve_attention.sh`
- *(Implemented 2026-07-07 by [[Orchestrator_Feedback_Loop]] slice A; registered via /graduate 2026-07-07. Resolve-side counterpart to `queue_attention` — resolution is a distinct verb from queueing, hence a sibling atom rather than a write-side flag.)*

---

### `run_gateway`
- **Inputs:** `--task-path <abs>` `--source-persona <name>` `[--orchestrator-mode]`
- **Outputs:** Self-extracts the `**Test Command:**` from the task file's `§ 🧪 Verification Gateway` (NEVER accepts the command as an argument — single source of truth is the file), validates it, executes it via `bash -c`, and prints the pinned stdout contract: `GATEWAY_CMD=<cmd>` / `GATEWAY_EXIT=<inner exit>` / `--- GATEWAY OUTPUT ---` / combined output. Atom exit 0 means "gateway ran"; the inner result is `GATEWAY_EXIT`.
- **Validation chain (all E3):** command substitution (`$(` or backtick) denied anywhere; absolute-path leading token denied; destructive leading tokens (`rm dd mkfs shred truncate kill`) denied; first-token-bounded allowlist (`bash sh npm pnpm npx uv make go grep git curl docker python(3) pytest xcodebuild sqlite3 test cd` + `./` and `.vault_link/` path prefixes). Under `--orchestrator-mode`, `gateway_provenance != human` in task frontmatter (absent = `human`) → E3 refuse.
- **Errors:** E1 task file / section / Test Command missing; E3 allowlist or provenance refusal (distinct stderr reasons); E4 persona.
- **Idempotent:** depends on the gateway command itself (the atom adds no state).
- **Persona Gate:** Executioner (source-persona arg + `persona_check.sh`)
- **Telemetry:** MANDATORY (`run_gateway` record)
- **Script:** `.vault_link/.scripts/run_gateway.sh`
- *(Implemented 2026-07-07 by [[Harden_Verification_Gateway_Eval]]; registered via /graduate 2026-07-07. Replaces the raw `eval "$TEST_CMD"` at `/execute_task` Step 13. Documented residual gaps: `&&`/`;` chains under trusted human authorship, `cd`-absolute args, no sandbox — the provenance gate is the control for the untrusted-inbox path. `gateway_provenance` is stamped at authoring time by `author_contract.sh --provenance`.)*

---

## Tool Composition Rules

1. **No tool calls another tool — with one carve-out.** Composition happens at the macro layer. **Exception:** `emit_telemetry.sh` is kernel telemetry infrastructure, not a peer atom; any write tool MAY call it solely to self-emit its mandatory telemetry record per Rule 3. No other tool→tool calls are allowed. If you find yourself wanting to compose atoms inside a script, lift the composition to the macro layer instead. Added 2026-05-28 by [[TiTan_Kit_Integration_Phase2]] to legitimize `write_task_section.sh` → `emit_telemetry.sh`; the carve-out is **deliberately narrow** — `emit_telemetry.sh` is the only exempt callee, and only for telemetry.
2. **Tools must declare side effects** in this file. Hidden side effects are a kernel violation.
3. **All write tools must produce telemetry** via `emit_telemetry` (per Rule 1 carve-out, this is the one permitted tool→tool call).
4. **Read tools never trigger telemetry** (would flood logs). **Exception:** subagent-invoking atoms (`invoke_*`) always emit telemetry, because LLM token cost is itself a side effect worth measuring even when the subagent is read-only.
5. **Persona-origin guard:** Atoms that accept a `source_persona` argument MUST verify it against the live session persona, not trust caller input. Mismatches are E4 (Permission Denied). This is the only way to prevent a subagent — which inherits the kernel's tool access but not its identity — from impersonating a privileged persona to reach gated vault writes.

---

## Telemetry Schema

```json
{
  "ts": "2026-05-04T10:30:00Z",
  "tool": "create_task",
  "macro": "new_task",
  "task": "Add_Multiply",
  "persona": "Executioner",
  "status": "success | error",
  "duration_ms": 124,
  "error_class": null,
  "args_hash": "sha1(args)"
}
```

`args_hash` is used instead of raw args to avoid leaking sensitive content into telemetry.

**Fields emitted by `emit_telemetry.sh` today:** `ts, macro, status, duration_ms, error_class, persona, task`. The `task` field (added [[TiTan_Kit_Integration_Phase3b]], 2026-05-28) carries the task identity for per-task attestation; it is `null` for macro-level records with no single task in scope. `tool` and `args_hash` are reserved (specced for future per-atom telemetry) and not yet emitted by the live script. Telemetry-write failures are recorded to `04_Logs/Telemetry/.write_failures.log` (best-effort sentinel); `emit_telemetry.sh` still exits 0 so it never blocks a macro.

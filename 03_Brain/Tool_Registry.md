# Tool Registry

> **Principle:** Macros are orchestration, tools are atoms. Tools live here with explicit input/output/error contracts. Macros invoke tools, never inline shell logic.

This is the canonical list of atomic operations available to any macro. Adding a tool requires Architect approval.

---

## Tool Manifest

### `create_task`
- **Inputs:** `title: str`, `project: str`, `priority: enum[low,med,high]`
- **Outputs:** Path to created file in `02_Tasks/`
- **Pre-conditions:** Project exists in `01_Projects/`; no existing task with same title
- **Errors:** E1 if project missing; E3 if task already exists
- **Idempotent:** ❌ (write-once)
- **Persona Gate:** Executioner

---

### `update_kanban`
- **Inputs:** `--board <path>` `--task-link <[[Name]]>` `--from <column>` `--to <column>` `--source-persona <name>`
- **Outputs:** Updated board file (`*_Board.md`); the line containing `--task-link` is removed from the `--from` section and inserted at the top of the `--to` section. Atomic via mktemp + mv. On **stderr** (only if non-zero): single-line E-class message.
- **Pre-conditions:**
    - `--board` file exists
    - Task link literally appears in the `--from` section
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
- **Outputs:** Exit 0 if no OTHER task in `.vault_link/02_Tasks/<project>/*.md` has YAML `status: in_progress`. Else exit 3 + prints offending task basename on stdout.
- **Pre-conditions:** `.vault_link/02_Tasks/<project>/` directory exists (empty dir is fine — yields exit 0)
- **Errors:** E3 only (another in-progress task found)
- **Idempotent:** ✅ (read-only)
- **Persona Gate:** Any (caller will already have passed `persona_check Executioner` if invoked from `/execute_task`)
- **Telemetry:** None (read-only per Composition Rule 4)
- **Called by:** `/execute_task` slash command step 5
- **Dependencies:** None (uses `grep`/`awk` on YAML)
- **Script:** `.vault_link/.scripts/in_progress_lock.sh`

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
  "persona": "Executioner",
  "status": "success | error",
  "duration_ms": 124,
  "error_class": null,
  "args_hash": "sha1(args)"
}
```

`args_hash` is used instead of raw args to avoid leaking sensitive content into telemetry.

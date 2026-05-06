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
- **Inputs:** `board_path: str`, `task_link: str`, `from_column: str`, `to_column: str`
- **Outputs:** Updated board file (move task link between columns)
- **Pre-conditions:** Task currently in `from_column`
- **Errors:** E3 if task not found in `from_column`
- **Idempotent:** ✅ (re-running with same args is no-op if already in `to_column`)
- **Persona Gate:** Executioner, Synthesizer (for Delegated col)

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

### `write_checkpoint`
- **Inputs:** `macro: str`, `step: int`, `state: dict`
- **Outputs:** `04_Logs/Checkpoints/<macro>_<timestamp>.json`
- **Errors:** E2 if filesystem write fails
- **Idempotent:** ✅ (one file per macro invocation, updated each step)
- **Persona Gate:** Any

---

### `read_checkpoint`
- **Inputs:** `macro: str`
- **Outputs:** Latest checkpoint state for that macro, or `null`
- **Errors:** None
- **Idempotent:** ✅
- **Persona Gate:** Any

---

### `emit_telemetry`
- **Inputs:** `record: TelemetryRecord` (see Section "Telemetry Schema")
- **Outputs:** JSONL line appended to `04_Logs/Telemetry/<YYYY-MM>.jsonl`
- **Errors:** None (best-effort; never blocks macro execution)
- **Idempotent:** ❌
- **Persona Gate:** Any

---

## Tool Composition Rules

1. **No tool calls another tool.** Composition happens at the macro layer.
2. **Tools must declare side effects** in this file. Hidden side effects are a kernel violation.
3. **All write tools must produce telemetry** via `emit_telemetry`.
4. **Read tools never trigger telemetry** (would flood logs).

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

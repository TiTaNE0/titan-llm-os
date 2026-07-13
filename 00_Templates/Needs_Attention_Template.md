# Needs Attention

> Async escalation queue (Orchestrator A3). The autonomous Orchestrator loop, the
> spec-gate PM reviewer, and the Phase C failure panel append here instead of
> blocking the whole run — humans are **on**-the-loop, not **in**-the-loop. Only the
> escalated task waits; the loop moves on to the next one.
>
> **Do not hand-add entry lines.** Append via `.vault_link/.scripts/queue_attention.sh`
> so format and dedup stay consistent. You MAY resolve entries by hand (see below).

## Entry schema

Each entry is one line under `## Open`. Write side (written by `queue_attention.sh`):

```
- [ ] [[<task>]] | state: <state> | source: <source> | run_id: <run_id> | queued: <ISO8601> | reason: <reason>
```

After resolution by `resolve_attention.sh`, the line is flipped and extended in place:

```
- [x] [[<task>]] | state: <state> | source: <source> | run_id: <run_id> | queued: <ISO8601> | reason: <reason> | resolved: <class> | resolved_at: <ISO8601Z> [| note: <text>]
```

- **task** — wiki-link to the blocked task.
- **state** — `spec_gate | close_gate | retries_exhausted | no_progress | orphaned_lock | panel_escalate | retro_promote`
- **source** — `orchestrator | pm_reviewer | failure_panel`
- **run_id** — the run that raised it (`null` if outside a run).
- **queued** — ISO-8601 UTC timestamp (stamped by the atom).
- **reason** — free text; everything after `reason: ` is the reason, so it may contain any punctuation.
- **resolved** — (written by `resolve_attention.sh` only) resolution class; see enum below.
- **resolved_at** — ISO-8601 UTC timestamp of resolution (stamped by `resolve_attention.sh`).
- **note** — (optional) single-line human note appended by `resolve_attention.sh --note`.

**Resolution class enum** (`resolved:` field):
`fixed_code | fixed_spec | fixed_brief | fixed_brain | wont_fix | duplicate | promoted`

- `fixed_code` — root cause was a bug in a script or command; code has been corrected.
- `fixed_spec` — root cause was a spec or contract gap; spec has been updated.
- `fixed_brief` — root cause was an agent-brief omission; brief has been updated.
- `fixed_brain` — root cause required a Brain-level change; ratified via `/graduate`.
- `wont_fix` — acknowledged; not worth acting on.
- `duplicate` — duplicate of another entry; original is the canonical reference.
- `promoted` — proposals promoted to Brain / rubric / briefs via `/graduate` (used by `/retrospective`).

(Field names match `Orchestrator_PRD_v2` § 5; the one-line checkbox serialization is the canonical shipped form — it adds the tick-to-resolve mechanism the PRD's YAML example lacked.)

(Schema aligns with `Orchestrator_PRD_v2` § 5 so the PM reviewer and failure panel can write the same shape from day one.)

## Read / clear protocol

- **Read:** unchecked `- [ ]` entries under `## Open` are unresolved. Work the oldest first.
- **Resolve (scripted):** run `.vault_link/.scripts/resolve_attention.sh --task <Name> --state <state> --run-id <id> --resolution <class> --source-persona Executioner`. The script flips the checkbox and appends `resolved:`, `resolved_at:`, and optionally `note:` fields atomically. Idempotent: a second call on the same entry exits 0.
- **Resolve (manual):** check the box (`- [x]`) when handled, or delete the line. The atom dedups only against UNCHECKED entries with the same task+state+run_id, so checking the box releases a future re-escalation of the same event.
- **Prune:** periodically delete checked entries, or move them under a `## Resolved` heading you maintain by hand.

## Open

# Needs Attention

> Async escalation queue (Orchestrator A3). The autonomous Orchestrator loop, the
> spec-gate PM reviewer, and the Phase C failure panel append here instead of
> blocking the whole run — humans are **on**-the-loop, not **in**-the-loop. Only the
> escalated task waits; the loop moves on to the next one.
>
> **Do not hand-add entry lines.** Append via `.vault_link/.scripts/queue_attention.sh`
> so format and dedup stay consistent. You MAY resolve entries by hand (see below).

## Entry schema

Each entry is one line under `## Open`:

```
- [ ] [[<task>]] | state: <state> | source: <source> | run: <run_id> | at: <ISO8601> | reason: <reason>
```

- **task** — wiki-link to the blocked task.
- **state** — `spec_gate | close_gate | retries_exhausted | no_progress | orphaned_lock | panel_escalate`
- **source** — `orchestrator | pm_reviewer | failure_panel`
- **run_id** — the run that raised it (`null` if outside a run).
- **at** — ISO-8601 UTC timestamp (stamped by the atom).
- **reason** — free text; everything after `reason: ` is the reason, so it may contain any punctuation.

(Schema aligns with `Orchestrator_PRD_v2` § 5 so the PM reviewer and failure panel can write the same shape from day one.)

## Read / clear protocol

- **Read:** unchecked `- [ ]` entries under `## Open` are unresolved. Work the oldest first.
- **Resolve:** check the box (`- [x]`) when handled, or delete the line. The atom dedups only against UNCHECKED entries with the same task+state+run_id, so checking the box releases a future re-escalation of the same event.
- **Prune:** periodically delete checked entries, or move them under a `## Resolved` heading you maintain by hand.

## Open

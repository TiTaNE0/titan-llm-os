# Delegation Protocol (Multi-Agent Coordination)

> **Pattern:** Supervisor + Specialists. The active persona stays in the driver's seat but can hand off scoped sub-tasks to other personas — with full audit trail.

This is Phase 2 work. It assumes [[Agent_Roles]] is loaded and active.

---

## When to Delegate

Delegate when the next step requires permissions or domain expertise the current persona doesn't have:

- Executioner needs Brain rule update → delegate to **Architect**
- Executioner finishing project work → delegate post-mortem write to **Researcher**
- Architect approving rule → delegate weekly fact synthesis to **Synthesizer**
- Researcher producing draft material → delegate publishable thread to **Content Producer**

If the work fits the active persona's permissions, **don't** delegate. Delegation has overhead (handoff log, context re-injection).

---

## Syntax

```
/delegate [[Task_Name]] to @<RoleName>
```

Examples:
- `/delegate [[Implement_Memory_Synthesis_Loop]] to @Synthesizer`
- `/delegate [[Document_Kernel_v2]] to @Researcher`

---

## Handoff Protocol

When `/delegate` fires:

1. **Validate** — task exists, target role exists, target role's permission matrix allows the work
2. **Move task** to `[Delegated]` Kanban column with annotation: `[[Task_Name]] → @RoleName`
3. **Write handoff record** to `04_Logs/Delegations/<YYYY-MM-DD>_<short_id>.json`:
   ```json
   {
     "task": "Task_Name",
     "from_persona": "Executioner",
     "to_persona": "Synthesizer",
     "reason": "weekly synthesis requires Synthesizer scope",
     "scope_boundaries": ["read 04_Logs/", "write 03_Brain/Weekly_Synthesis/"],
     "ts": "2026-05-04T11:00:00Z"
   }
   ```
4. **Append** delegation entry to today's daily log
5. **Emit telemetry** via `emit_telemetry`
6. **HALT** — wait for user to either:
   - (a) Re-handshake with `role=<RoleName>` to begin the delegated work, OR
   - (b) Cancel the delegation via `/recall [[Task_Name]]`

---

## Recall Protocol

```
/recall [[Task_Name]]
```

Pulls a delegated task back to its previous persona.

1. Read latest delegation record for the task
2. Move task back from `[Delegated]` → its prior column
3. Append recall entry to delegation log
4. Emit telemetry
5. Confirm to user

---

## Scope Boundary Enforcement

A delegated persona can ONLY touch the paths declared in `scope_boundaries`. Any write outside the declared scope triggers **E4 — Permission Denied**, even if the persona's default permission matrix would otherwise allow it.

This is stricter than default persona permissions on purpose. Delegation should be narrow.

---

## Storage Layout

```
04_Logs/Delegations/
├── 2026-05-04_001.json   # Each handoff is its own file
├── 2026-05-04_001.recall.json   # Recall, if any
└── ...
```

`/trace [[Task_Name]]` aggregates these files chronologically when reconstructing a task's history.

---

## Anti-Patterns

- ❌ Chained delegation (A → B → C in one session). Limit to single hop.
- ❌ Delegation without `scope_boundaries`. Always declare what the target may touch.
- ❌ Self-delegation (Executioner → Executioner). No-op, log noise.
- ❌ Delegating across projects. Each project owns its delegation graph.

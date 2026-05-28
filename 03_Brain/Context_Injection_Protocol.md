# Context Injection Protocol

> **Karpathy's Rule:** *"The bottleneck is not the LLM; it's the context. Fill it strategically before the work starts."*

This protocol defines what an agent MUST load into context during the boot handshake — BEFORE responding to the first user instruction. Treat this as filling the LLM's RAM with the right facts so it doesn't have to keep re-reading the disk.

---

## 1. Boot Sequence (Mandatory Order)

| Step | File | Required? | Purpose |
|------|------|-----------|---------|
| 1 | `AGENTS.md` (root) | ✅ Always | Identifies project, points to vault |
| 2 | `03_Brain/System_Agents.md` | ✅ Always | Kernel rules + macro definitions |
| 3 | `03_Brain/Agent_Roles.md` | ✅ Always | Identifies which persona is active |
| 4 | `04_Logs/<latest>.md` | ✅ Always | Hot-cache of recent decisions |
| 5 | `01_Projects/{{PROJECT}}.md` | ✅ Always | Project mission + constraints |
| 6 | `{{PROJECT}}_Board.md` | ✅ Always | Current Kanban state |
| 7 | `06_Research/{{PROJECT}}_Research.md` | ⚠️ If exists | Deep technical context |
| 8 | `03_Brain/Weekly_Synthesis/<latest>.json` | ⚠️ If exists | Synthesized memory |

After step 8, agent confirms: **"Mission_Control rules loaded. Persona: {{ROLE}}. Project: {{PROJECT}}. Context primed."**

---

## 1.5. Post-Boot Ritual: Session State Write

Immediately after the boot confirmation (and before responding to the first user instruction), the agent MUST execute:

```bash
.vault_link/.scripts/session_state_write.sh \
  --persona {{ROLE}} \
  --session-id <new id> \
  --started-at <ISO ts>
```

This writes `.vault_link/.session_state.json`, the authoritative live-persona record. Every mutating tool atom — `write_task_section.sh`, `update_kanban.sh`, etc. — reads this file before acting and refuses with E4 if the caller-claimed persona does not match.

**Why a separate section, not a step in § 1.** The boot sequence is pure-read context injection. The ritual is the first WRITE of the session and has its own failure semantics. Keeping it out of the boot table preserves the rule that *context loading never mutates the vault*.

**Failure handling.** If `session_state_write.sh` exits non-zero, the agent MUST halt with E2 before accepting any user instruction. A session without `.session_state.json` cannot perform any vault-mutating macro — every atom's persona check will fail E4.

**State file is authoritative.** Never trust caller-supplied or ambient persona claims at the atom layer — always read the state file. This is the load-bearing invariant for the persona-origin guard (see [[Tool_Registry]] § Composition Rule 5).

**Mid-session persona switches require a new handshake** (boot + post-boot ritual). Editing `.session_state.json` directly in-session is a kernel violation — it bypasses the per-change approval gate for Architect work and the macro-level checks for Executioner work.

Added 2026-05-28 by [[TiTan_Kit_Integration_Phase2]].

---

## 2. Token Budget Guidance

- Cap injected context at **~30% of context window** — leave the other 70% for the conversation and tool outputs.
- If total injection exceeds budget, drop in this order: Research → Weekly_Synthesis → older log lines (keep header + last 50 lines of latest log).
- NEVER drop steps 1–3 to save tokens. They are the kernel.

---

## 3. Conditional Rules

- **Multi-day session:** Only inject the latest log file, not the full history. Use `/trace` macro on demand if older context is needed.
- **Cold start (no prior log today):** Inject the most recent log and prepend the line `> COLD START — last activity {{date}}`.
- **Cross-project switch:** Re-run steps 5–8 with new `{{PROJECT}}`. Steps 1–4 stay loaded.
- **Macro-only invocation (e.g., `/metrics`):** Skip steps 5–8; load only kernel + role.

---

## 4. Refresh Triggers

Re-inject context when:
- User issues `/refresh_context`
- Agent has been idle > 30 minutes (cache likely cold)
- User explicitly switches project via `/switch_project [[Name]]`
- Conversation crosses 50% of context window (compaction risk)

Every refresh trigger above MUST re-execute the [Post-Boot Ritual](#15-post-boot-ritual-session-state-write) to refresh the persona binding in `.session_state.json`. The state file is authoritative — atoms never trust ambient claims or caller-supplied values. Mid-session persona switches (e.g., Executioner → Architect) are not valid without a new handshake + ritual re-run.

---

## 5. What NOT to Pre-Inject

- Full task files in `02_Tasks/` — load on demand via Wiki-Link traversal
- Archived tasks in `99_Archive/` — only via `/trace`
- Templates in `00_Templates/` — read at macro execution time
- All log files in `04_Logs/` — only the latest one

---

## 6. Verification

After handshake, agent should be able to answer without re-reading files:
1. "What is the active project?"
2. "What was the last decision logged?"
3. "What's in the Todo column right now?"
4. "Which persona am I operating as?"

If any answer requires a fresh file read, the injection failed.

# 🛰️ TiTan LLM OS — Command Center HUD

> Decoupled **Brain / Executioner** architecture. Local-first, hub-and-spoke, agent-agnostic. The vault is the memory; the agent can be any cloud LLM (Claude Code, OpenCode, ChatGPT, etc.).

---

## 🚀 Cold Start: Agent Handshake

Copy/paste to any new session to bring an agent online:

```text
Read AGENTS.md, execute bootstrap, load 03_Brain/System_Agents.md.
Apply 03_Brain/Context_Injection_Protocol.md (full boot sequence).
Persona: role=Executioner
INITIAL STATE: ARCHITECT MODE. CODE GATE: LOCKED.
Do not write source code or run builds until a task in 02_Tasks is approved.
```

**What this triggers (per [[Context_Injection_Protocol]]):**
1. Load `AGENTS.md` (project root) → identify project
2. Load `03_Brain/System_Agents.md` → kernel rules + macros
3. Load `03_Brain/Agent_Roles.md` → adopt persona
4. Load latest `04_Logs/*.md` → recent decisions
5. Load `01_Projects/{{PROJECT}}.md` → mission + constraints
6. Load `{{PROJECT}}_Board.md` → current Kanban state
7. *(Optional)* `06_Research/{{PROJECT}}_Research.md` → deep technical context
8. *(Optional)* `03_Brain/Weekly_Synthesis/<latest>.json` → synthesized memory

Agent confirms with: `"Mission_Control rules loaded. Persona: {{ROLE}}. Project: {{PROJECT}}. Context primed."`

---

## 🎭 Choose Your Persona

Append `role=<Name>` to the handshake. See [[Agent_Roles]] for full definitions.

| Persona | When to Use | Write Access |
|---------|-------------|--------------|
| **Executioner** *(default)* | Task execution, code, builds, closing tasks | `02_Tasks/`, `04_Logs/`, boards, source |
| **Architect** | Curating Brain rules, approving promotions | `03_Brain/` *(per-change approval)* |
| **Researcher** | Compressing sessions into research artifacts | `06_Research/`, `00_Inbox/` |
| **Synthesizer** | Running weekly memory synthesis | `03_Brain/Weekly_Synthesis/` |
| **Content Producer** | Drafting public threads / blog posts | `05_Content/03_Drafts/` |

Switching mid-session requires a new handshake. Each persona's permissions are kernel-enforced (E4 Permission Denied if violated).

---

## 🛠️ Standard Developer Workflow

The 6-step ritual to keep the OS coherent:

1. **BOOT** — Paste handshake. Agent loads kernel + persona + context.
2. **MAP** — `/update_index` and `/refresh_context`. Get GPS.
3. **ARCHITECT** — `/new_task [Name]`. Code gate **LOCKED**. Agent writes `.md` and stops.
4. **REVIEW** — Read agent's Implementation Plan in the task file. Sanity-check assumptions.
5. **EXECUTE** — Issue `EXECUTE` keyword. Gate unlocks. Agent loops until **Verification Gateway** (test exit code 0) passes.
6. **VERIFY** — Agent surfaces Verification Gateway results and **HALTS**. Agent must NOT self-close. You review.
7. **CLOSE** — YOU trigger `/close_task [Name]`. Atomic finalize: completion summary, archive, board move, log entry.

---

## 🔧 Macro Index (Slash Commands)

### Task Lifecycle
| Macro | Purpose |
|-------|---------|
| `/new_task [Title] for [[Project]]` | Create task, append to Todo, **HALT** for review |
| `/close_task [Task_Name]` | Populate completion summary, archive, update Kanban, log |
| `/archive_done` | Bulk-move all `status: done` tasks to `99_Archive/` |
| `/trace [topic]` | Chronological evolution across Projects → Brain → Logs → Archive |

### Context & State
| Macro | Purpose |
|-------|---------|
| `/refresh_context` | Re-run boot sequence in-session (use after idle/drift) |
| `/switch_project [[Name]]` | Re-inject project context, retain persona |
| `/update_index` | Regenerate `Internal_Index.md` via `.scripts/generate_index.sh` |

### Memory & Brain
| Macro | Purpose |
|-------|---------|
| `/graduate` | *(Architect)* Propose Core Principle / Architecture Rule from last 7 days |
| `/synthesize [iso_week]` | *(Synthesizer)* Compile logs → facts → propose rule updates |

### Reliability
| Macro | Purpose |
|-------|---------|
| `/metrics [day\|week\|month]` | Aggregate telemetry into success rate / duration / errors |

### Multi-Agent (Phase 2)
| Macro | Purpose |
|-------|---------|
| `/delegate [[Task]] to @<Role>` | Hand off task to a specialist persona |
| `/recall [[Task]]` | Pull a delegated task back to its previous persona |

### Content Pipeline
| Macro                                  | Purpose                                                        |
| -------------------------------------- | -------------------------------------------------------------- |
| `/capture_idea [Idea]`                 | Append to `01_Content_Ideas.md`, add to Content Board          |
| `/new_thread [Topic] from [[Project]]` | Generate X/Twitter thread draft via active module + voice file |
| `/new_tiktok [Topic] from [[Project]]` | Generate TikTok script + build artifacts *(tiktok module inactive — enable first)* |
| `/new_landing [Topic] from [[Project]]`| Generate landing page copy *(landing module inactive — enable first)* |
| `/refactor_thread [[File]]`            | Rewrite draft applying active voice file; preserve facts       |
| `/enable_module <name>`                | Activate a content module (`twitter`, `linkedin`, `tiktok`, `landing`, `article`) |
| `/disable_module <name>`               | Deactivate a content module                                    |
| `/set_voice <voice_name>`              | Swap the active personalization voice (e.g. `voice_evgeny`)    |

**Pipeline registry:** `05_Content/modules.yaml` (canonical — which module is active, which voice is loaded)
**Active voice (default):** `05_Content/personalization/voice_evgeny.md` — silent load, never narrate the rules
**Active modules:** `twitter`, `linkedin` — `05_Content/modules/<channel>/` (templates + strategy + failure log)
**Inactive stubs:** `tiktok`, `landing`, `article` — registered, guarded, not yet runnable
**Agent SOP:** `05_Content/00_AGENT_GUIDE.md` — read before any drafting action

### Intake
| Macro | Purpose |
|-------|---------|
| `/process_inbox` | Route `00_Inbox/` files to Research / Brain / Templates |

---

## 🧠 Architecture Reference

The full kernel lives in `03_Brain/`. Agents read these on demand via Wiki-Link traversal.

| File | Role |
|------|------|
| [[System_Agents]] | Kernel: paths, security, macros, protocols |
| [[Context_Injection_Protocol]] | What to load at handshake & token budget |
| [[Agent_Roles]] | Persona manifest (Role / Goal / Backstory / permissions) |
| [[Memory_Schema]] | Synthesis-based memory: fact format + decay rules |
| [[Error_Recovery]] | E1–E5 error classes + recovery matrix |
| [[Tool_Registry]] | Atomic operations available to macros |
| [[Delegation_Protocol]] | Multi-agent handoff rules |
| [[Observability]] | Telemetry schema + `/metrics` |
| [[Architecture_Notes/Core_Principles]] | SOLID, TypeScript-First, GPS constraints |

---

## 🚨 Error Handling (At-A-Glance)

If any macro fails, classification is mandatory:

| Class | Trigger | Action |
|-------|---------|--------|
| **E1** Blocker | External dep missing | Mark `status: blocked`, halt |
| **E2** Tool Failure | Step errored | Retry once, then halt with report |
| **E3** Inconsistency | YAML / Kanban mismatch | Halt, ask user to pick reconciliation |
| **E4** Permission | Persona violated scope | Refuse, suggest correct macro |
| **E5** Saturation | Context window full | Save checkpoint, recommend fresh session |

Reports land in `04_Logs/Errors/`. Template at `00_Templates/Error_Report_Template.md`.

---

## 🔗 New Project Setup

1. **Symlink the vault** from the project root:
   ```bash
   ln -s ~/Library/Mobile\ Documents/iCloud~md~obsidian/Documents/Mission_Control .vault_link
   ```
2. **Create project bootloader** `AGENTS.md` in the project root using `00_Templates/AI_Project_Bootstrap.md`
3. **Create project passport** in `01_Projects/<Name>.md` from `00_Templates/Project_Passport_Template.md`
4. **Create local Kanban** at `<Name>_Board.md` (vault root) with the standard columns
5. **(Optional) Research file** at `06_Research/<Name>_Research.md` if technical depth is needed

If `.vault_link` breaks, re-anchor:
```bash
ln -sfn ~/Library/Mobile\ Documents/iCloud~md~obsidian/Documents/Mission_Control .vault_link
```

---

## 🔁 Goal-Driven Execution Model

- **Define end-states, not steps.** Macros describe outcomes; agents act until verification passes.
- **Verification-driven.** Every macro has a Verification Gateway (test command, exit code 0).
- **Human-in-the-loop.** State-changing operations halt for explicit approval.
- **Wiki-Link mandate.** All cross-references use `[[filename]]`. Never bare paths in narrative content.
- **Single source of truth.** Global rules → `03_Brain/System_Agents.md`. No duplicate rule files.
- **Read-only Brain.** Only Architect can write to `03_Brain/`, only with per-change approval.

---

## 🧭 Quick Navigation

[[00_Inbox]] · [[01_Projects]] · [[02_Tasks]] · [[03_Brain]] · [[04_Logs]] · [[05_Content]] · [[06_Research]] · [[99_Archive]]

**Boards:** [[TiTan_LLM_OS_Board]] · [[Content_Board]] · [[nearest-address-codes_Board]] · [[Voice_Cloning_Bot_Board]] · [[titan-proxy-bot_Board]] · [[Intuiscale_Board]]

**Index:** [[Internal_Index]] (auto-generated; refresh with `/update_index`)

---

## 📝 Adding a New Macro

When you add a `/macro` to `System_Agents.md`, you MUST also append it here under the correct category. The kernel and the HUD must stay in sync.

The exact contract: `System_Agents.md` is canonical for behavior. `Welcome.md` is the human-facing shortcut. If they disagree, fix `Welcome.md` to match the kernel.

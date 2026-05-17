# TiTan LLM OS

![Version](https://img.shields.io/badge/kernel-v2.0-blue)
![Status](https://img.shields.io/badge/status-active-brightgreen)
![Built with](https://img.shields.io/badge/built%20with-Claude%20Code-blueviolet)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

A flat-file operating system for AI agents. Built on Obsidian + Claude Code. Runs on any cloud LLM.

> The vault is the memory. The agent is stateless. The kernel is markdown.

---

## What it is

Most AI coding setups are session-based: you open a chat, describe the problem, get an answer, lose the context. The next session starts from zero.

TiTan LLM OS treats the agent as an executor, not a conversationalist. The vault holds all persistent state — tasks, decisions, logs, research, content drafts, synthesized memory — and the agent reads it at boot. Every session starts fully primed. No repeated explanations. No rediscovering what was done last week.

The OS runs on any agent that can read files and follow markdown-defined rules. Tested with Claude Code and OpenCode. The agent is swappable. The vault is not.

---

## Architecture

```
Mission_Control/           ← Obsidian vault (iCloud-synced, or any folder)
│
├── AGENTS.md              ← Project-level bootloader — agent reads this first
├── Welcome.md             ← Human HUD: handshake snippet, macro index, quick nav
│
├── 00_Templates/          ← Scaffolding: task, project, error, inbox templates
├── 01_Projects/           ← Project passports (mission, constraints, board links)
├── 02_Tasks/              ← Per-project task files  [gitignored]
├── 03_Brain/              ← Kernel: rules, macros, protocols, memory schemas
├── 04_Logs/               ← Daily append-only logs + telemetry  [gitignored]
├── 05_Content/            ← Multi-channel content pipeline
├── 06_Research/           ← Compressed session → research artifacts  [gitignored]
└── 99_Archive/            ← Closed tasks and published content  [gitignored]
```

```
┌──────────────────────────────────────────────────────────┐
│                     Agent Session                        │
│                                                          │
│  paste handshake                                         │
│       │                                                  │
│       ▼                                                  │
│  ┌─────────┐    reads    ┌──────────────────────────┐   │
│  │ AGENTS  │ ──────────► │  03_Brain/System_Agents  │   │
│  │  .md    │             │  (kernel: rules + macros) │   │
│  └─────────┘             └────────────┬─────────────┘   │
│                                       │ loads            │
│              ┌────────────────────────┼──────────────┐  │
│              ▼                        ▼              ▼  │
│        04_Logs/          01_Projects/         Kanban     │
│        (recent)          (mission)            Board      │
│                                                          │
│  agent confirms persona + project → ready to execute     │
└──────────────────────────────────────────────────────────┘
```

---

## Core Concepts

### Kernel — `03_Brain/System_Agents.md`

Single source of truth for agent behavior. One file. No duplicate rules anywhere else.

Defines: paths, macro commands, persona gates, task completion gate, error recovery (E1–E5), telemetry contract.

### Personas

Five role-gated personas with enforced read/write scope:

| Persona | Scope | When to use |
|---------|-------|-------------|
| **Executioner** | Tasks, logs, source code | Daily work — build, fix, ship |
| **Architect** | `03_Brain/` (per-change approval) | Kernel changes, rule promotions |
| **Researcher** | `06_Research/`, inbox | Compressing sessions into durable notes |
| **Synthesizer** | `03_Brain/Weekly_Synthesis/` | Weekly memory synthesis |
| **Content Producer** | `05_Content/03_Drafts/` | Drafting threads, scripts, copy |

A persona cannot escalate its own permissions. Switching requires a new handshake.

### Boot Sequence

Paste into any new agent session:

```
Read AGENTS.md, execute bootstrap, load 03_Brain/System_Agents.md.
Apply 03_Brain/Context_Injection_Protocol.md (full boot sequence).
Persona: role=Executioner
```

```
Boot order:
  1. AGENTS.md          → identify project
  2. System_Agents.md   → kernel rules + macros
  3. Agent_Roles.md     → adopt persona + permission scope
  4. 04_Logs/latest     → recent decisions
  5. 01_Projects/X.md   → mission + constraints
  6. X_Board.md         → current Kanban state
  7. Research + Synthesis (optional)
```

Agent confirms: `Mission_Control rules loaded. Persona: Executioner. Project: X. Context primed.`

### Task Lifecycle

```
/new_task ──► [HALT: review plan] ──► EXECUTE ──► [HALT: verify] ──► /close_task
                                                                      (user only)
```

Agents cannot close their own tasks. `§ 1.3 Task Completion Gate` in the kernel enforces this. The agent halts after verification and waits. You run `/close_task`. Prevents the most common drift: work done, board still says In Progress, next session wastes time rediscovering state.

### Memory Synthesis

```
weekly /synthesize run:
  04_Logs/*.md  ──►  facts.jsonl  ──►  .synthesis.md  ──►  rule proposals
                                                              │
                                              Architect review + /graduate
                                                              │
                                                      kernel update
```

---

## Content Pipeline

Multi-channel system for technical content marketing. Agent-operated, frontmatter-driven.

```
05_Content/
├── modules.yaml              ← registry: active channels + voice pointer
├── 00_AGENT_GUIDE.md         ← agent SOP (read before any drafting)
├── 00_Content_Templates/     ← universal template + DESIGN + VOICE schemas
├── 03_Drafts/                ← all output, flat folder, prefix-named files
├── 04_Published/             ← post-publish storage
├── 05_Assets/                ← images, audio, visual assets
├── modules/
│   ├── twitter/   ✅ active  strategy + Thread_Template
│   ├── linkedin/  ✅ active  strategy + Post_Template + anchor_workflow
│   ├── tiktok/    ✅ active  strategy + Script_Template + build artifacts
│   ├── landing/   ⏸ inactive strategy + Landing_Template
│   └── article/   ⏸ inactive stub
└── personalization/
    ├── voice_evgeny.md        ← person-layer voice (always loaded)
    └── voice_pass_protocol.md ← two-pass application procedure
```

### Voice — two layers

```
┌─────────────────────────────────────┐
│  Person layer (voice_evgeny.md)     │  ← who is speaking
│  identity · rhythm · ESL texture   │     cross-project · never overridden
└──────────────┬──────────────────────┘
               │ loaded on top
┌──────────────▼──────────────────────┐
│  Project layer (VOICE.md)           │  ← who they're speaking TO
│  audience segments · tone per seg  │     per-project · optional
└─────────────────────────────────────┘
```

### Draft frontmatter schema

```yaml
---
project: "my-project"
type: "twitter | linkedin | tiktok | landing | article"
status: "draft"
category: "feature-area"
persona: "target-audience"
slug: "kebab-slug"
created: YYYY-MM-DD
---
```

`type:` is the machine-readable channel key. File prefix (`x_`, `tiktok_`, etc.) is human shorthand only.

### `/new_tiktok` output

Running `/new_tiktok Topic from [[Project]]` generates 4 artifacts:

```
05_Content/03_Drafts/tiktok_[slug].md          ← script with frontmatter
05_Content/modules/tiktok/build/[slug]/
  ├── tts_input.txt                             ← VO lines, plain UTF-8
  ├── captions.srt                              ← estimated @2.7 words/sec
  └── remotion_prompt.md                        ← per-scene visual brief
```

Requires `01_Projects/[Project]/DESIGN.md` — copy from `05_Content/00_Content_Templates/DESIGN_Template.md`.

---

## Macro Reference

### Task lifecycle

| Macro | What it does |
|-------|-------------|
| `/new_task [Title] for [[Project]]` | Scaffold task file, append to Todo, halt for review |
| `/close_task [Task_Name]` | Archive, board move, log entry, telemetry — user-triggered only |
| `/archive_done` | Bulk-archive all `status: done` tasks |
| `/trace [topic]` | Chronological trail: Projects → Brain → Logs → Archive |

### Context

| Macro | What it does |
|-------|-------------|
| `/refresh_context` | Re-run boot sequence mid-session |
| `/switch_project [[Name]]` | Re-inject project context, retain persona |
| `/update_index` | Regenerate `Internal_Index.md` |

### Memory

| Macro | What it does |
|-------|-------------|
| `/synthesize [iso_week]` | Compile logs → facts → propose rule updates |
| `/graduate` | Promote validated proposal into kernel (Architect only) |

### Content

| Macro | What it does |
|-------|-------------|
| `/capture_idea [Idea]` | Append to ideas backlog, add to Content Board |
| `/new_thread [Topic] from [[Project]]` | Generate X/Twitter thread draft |
| `/new_tiktok [Topic] from [[Project]]` | Generate TikTok script + 3 build artifacts |
| `/refactor_thread [[File]]` | Rewrite draft applying active voice |
| `/enable_module <name>` | Activate a content channel |
| `/set_voice <voice_name>` | Swap active voice file |

### Reliability

| Macro | What it does |
|-------|-------------|
| `/metrics [day\|week\|month]` | Aggregate telemetry: success rate / latency / errors |
| `/delegate [[Task]] to @<Role>` | Hand off task to a specialist persona |
| `/recall [[Task]]` | Pull delegated task back |

---

## Error Handling

| Class | Trigger | Response |
|-------|---------|----------|
| **E1** Blocker | External dep missing | Mark blocked, halt |
| **E2** Tool Failure | Step errored | Retry once, then halt with report |
| **E3** Inconsistency | YAML / Kanban mismatch | Halt, surface reconciliation options |
| **E4** Permission | Persona violated scope | Refuse, suggest correct macro |
| **E5** Saturation | Context window full | Save checkpoint, recommend fresh session |

Reports go to `04_Logs/Errors/`. Template at `00_Templates/Error_Report_Template.md`.

---

## New Project Setup

1. Clone the repo and open the folder as an Obsidian vault (or nest it inside an existing one)
2. Symlink into your project root:
   ```bash
   ln -s /path/to/your/Mission_Control .vault_link
   ```
3. Copy `00_Templates/AI_Project_Bootstrap.md` → create `AGENTS.md` in your project root
4. Create project passport: `01_Projects/<Name>.md` from `00_Templates/Project_Passport_Template.md`
5. Create Kanban board: `<Name>_Board.md` at vault root — columns: Backlog / Todo / In Progress / Delegated / Done
6. *(Optional)* `06_Research/<Name>_Research.md` for deep technical context

Boot the agent with the standard handshake. Done.

---

## Design Decisions

**Flat files over databases.** Every piece of state is a markdown file. Readable by humans, writable by any agent, diffable in git, synced by iCloud or any folder sync. No lock-in.

**Frontmatter as machine state.** YAML frontmatter is the source of truth for status, ownership, and routing. Agents read frontmatter; humans read the body.

**Agent is stateless, vault is not.** The agent can be replaced, upgraded, or swapped. Context injection at boot restores full situational awareness in one paste.

**One kernel file.** All global rules live in `03_Brain/System_Agents.md`. No rules in READMEs, comments, or config files. If it's a rule, it's in the kernel.

**Human closes tasks, not agent.** Prevents the systemic drift where an agent finishes work, declares done, and moves on — leaving the board wrong and the next session confused.

**Voice is layered, not monolithic.** Person identity (how you speak) is separate from audience targeting (who you're speaking to). Swap the audience without losing the voice.

---

## Repository Contents

Framework only. No personal data, no project-specific content.

```
Tracked                          Gitignored
─────────────────────────────    ──────────────────────────────
AGENTS.md                        02_Tasks/
Welcome.md                       04_Logs/
README.md                        06_Research/
00_Templates/                    99_Archive/
03_Brain/                        05_Content/03_Drafts/
05_Content/ (structure only)     05_Content/04_Published/
.scripts/                        05_Content/05_Assets/
setup_llm_os.sh                  01_Projects/ (except TiTan_LLM_OS.md)
```

---

## Status

Active, in production. Used daily across 6+ projects.

| Component | State |
|-----------|-------|
| Kernel | v2.0 — task completion gate, on_error contract, Invoke: syntax |
| Memory synthesis | Running — W20 complete, facts.jsonl active |
| Twitter / X | Active — `/new_thread` implemented |
| LinkedIn | Active — anchor_workflow auto-posting |
| TikTok | Active — `/new_tiktok` implemented, 4-artifact output |
| Landing pages | Inactive stub — strategy + template ready, macro pending |
| TTS pipeline | Phase 2 — pending first manual video validation |
| Video rendering | Phase 3 — Remotion deferred until TTS validates |

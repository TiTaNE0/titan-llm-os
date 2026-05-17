# TiTan LLM OS

A flat-file operating system for AI agents. Built on Obsidian + Claude Code. Runs on any cloud LLM.

The vault is the memory. The agent is stateless. The kernel is markdown.

---

## What it is

Most AI coding setups are session-based: you open a chat, describe the problem, get an answer, lose the context. The next session starts from zero.

TiTan LLM OS treats the agent as an executor, not a conversationalist. The vault holds all persistent state — tasks, decisions, logs, research, content drafts, synthesized memory — and the agent reads it at boot. Every session starts fully primed. No repeated explanations. No rediscovering what was done last week.

The OS runs on any agent that can read files and follow markdown-defined rules. Tested with Claude Code and OpenCode. The agent is swappable. The vault is not.

---

## Architecture

```
Mission_Control/           ← Obsidian vault (iCloud-synced)
├── AGENTS.md              ← Project-level bootloader (read first)
├── Welcome.md             ← Human HUD: handshake, macros, quick nav
│
├── 00_Templates/          ← Scaffolding templates
├── 01_Projects/           ← Project passports (mission, constraints, links)
├── 02_Tasks/              ← Per-project task files (gitignored)
├── 03_Brain/              ← Kernel: rules, macros, protocols, memory
├── 04_Logs/               ← Daily append-only logs + telemetry (gitignored)
├── 05_Content/            ← Multi-channel content pipeline
├── 06_Research/           ← Compressed session → research artifacts (gitignored)
└── 99_Archive/            ← Closed tasks, published content (gitignored)
```

The repo tracks **framework only** — kernel files, templates, content module structure, scripts. No personal data, no task history, no logs. Clone the repo and plug in your own projects.

---

## Core Concepts

### Kernel (`03_Brain/System_Agents.md`)
The single source of truth for agent behavior. Defines:
- Paths and environment
- Macro commands (slash commands the agent executes)
- Security protocols (vault safety, permission gates)
- Task completion gate (agents cannot self-close tasks)
- Error recovery (E1–E5 classes with recovery paths)
- Telemetry contract (every macro emits structured JSONL)

One rule: **do not duplicate rules**. If a rule exists in the kernel, it exists nowhere else.

### Personas
Five role-gated personas. Each has defined read/write scope enforced at macro level:

| Persona | Scope | Typical use |
|---------|-------|-------------|
| **Executioner** | Tasks, logs, source code | Daily work: build, fix, ship |
| **Architect** | `03_Brain/` only, per-change approval | Kernel changes, rule promotions |
| **Researcher** | `06_Research/`, inbox | Compressing sessions into durable notes |
| **Synthesizer** | `03_Brain/Weekly_Synthesis/` | Weekly memory synthesis runs |
| **Content Producer** | `05_Content/03_Drafts/` | Drafting threads, scripts, landing copy |

Switching personas requires a new handshake. A persona cannot escalate its own permissions.

### Boot Sequence
Paste this into any new agent session:

```
Read AGENTS.md, execute bootstrap, load 03_Brain/System_Agents.md.
Apply 03_Brain/Context_Injection_Protocol.md (full boot sequence).
Persona: role=Executioner
```

What happens:
1. `AGENTS.md` → identify project
2. `System_Agents.md` → load kernel rules + macros
3. `Agent_Roles.md` → adopt persona + permission scope
4. Latest `04_Logs/*.md` → recent decisions and context
5. `01_Projects/{{PROJECT}}.md` → mission and constraints
6. `{{PROJECT}}_Board.md` → current Kanban state
7. *(optional)* Research file + weekly synthesis

Agent confirms: `"Mission_Control rules loaded. Persona: Executioner. Project: {{PROJECT}}. Context primed."`

### Task Lifecycle
```
/new_task → [HALT: review plan] → EXECUTE → [HALT: verify] → /close_task (user-triggered)
```

Key rule: **agents cannot close their own tasks**. `§ 1.3 Task Completion Gate` in the kernel enforces this. The agent halts after verification, surfaces results, and waits. You run `/close_task`. This prevents the most common drift pattern: work done, board says In Progress, next session wastes time rediscovering state.

### Memory Synthesis
Weekly `/synthesize [iso_week]` run:
- Reads all daily logs for the week
- Extracts concrete facts (bugs found, decisions made, technical learnings)
- Writes structured JSONL to `03_Brain/Weekly_Synthesis/facts.jsonl`
- Generates a human-readable `.synthesis.md` report
- Proposes rule changes with confidence scores

Rule proposals require Architect review before promotion. `/graduate` writes approved proposals into the kernel permanently.

---

## Content Pipeline (`05_Content/`)

Multi-channel content system for technical content marketing. Agent-operated, frontmatter-driven.

### Channels

| Channel | Status | Prefix | Type | Automation |
|---------|--------|--------|------|------------|
| X / Twitter | active | `x_` | `twitter` | Manual post |
| LinkedIn | active | `linkedin_` | `linkedin` | Auto-post via anchor workflow |
| TikTok | inactive stub | `tiktok_` | `tiktok` | Planned |
| Landing pages | inactive stub | `landing_` | `landing` | Planned |
| Article | inactive stub | `article_` | `article` | Planned |

### How it works

Every draft is a markdown file in `05_Content/03_Drafts/` with universal frontmatter:

```yaml
---
project: "TiTan_LLM_OS"
type: "twitter"
status: "draft"
category: "kernel"
persona: "indie-builder"
slug: "kernel-v2-updates"
created: 2026-05-17
---
```

`type:` is the machine-readable channel key. File prefix is human-readable shorthand. Never derive channel from filename.

### Voice system

Two-layer architecture:
- **Person layer** (`personalization/voice_evgeny.md`) — who is speaking. Identity, rhythm, ESL texture, banned vocab. Cross-project. Always loaded.
- **Project layer** (`01_Projects/[Name]/VOICE.md`) — who they're speaking to. Audience segments, tone per segment. Per-project. Optional; loaded on top of person layer.

Voice is applied via mandatory two-pass drafting: internal scratch → rewrite → emit only the second pass.

### Status lifecycle

```
draft → ready → scheduled (bot) → published → 04_Published/
                                → rejected (3 failures)
```

Agent only sets `draft`. Everything past that is user or automation territory.

### Module structure

```
05_Content/modules/<channel>/
├── README.md          ← manifest, activation instructions
├── strategy.md        ← channel tactics (voice file wins on conflicts)
├── failure_log.md     ← append-only drift incidents
└── templates/
    └── *_Template.md  ← draft skeleton
```

Inactive modules have an explicit guard: any macro checks `modules.yaml → active_modules` before touching any file. If the channel is not active, the macro halts with a clean message. No silent fallbacks.

---

## Macro Reference

### Task lifecycle

| Macro | What it does |
|-------|-------------|
| `/new_task [Title] for [[Project]]` | Scaffold task file, append to Todo, **halt for review** |
| `/close_task [Task_Name]` | Archive, board move, log entry, telemetry — user-triggered only |
| `/archive_done` | Bulk-archive all `status: done` tasks |
| `/trace [topic]` | Chronological trail across Projects → Brain → Logs → Archive |

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
| `/refactor_thread [[File]]` | Rewrite draft applying active voice |
| `/enable_module <name>` | Activate a content channel |
| `/set_voice <voice_name>` | Swap active voice file |

### Reliability

| Macro | What it does |
|-------|-------------|
| `/metrics [day\|week\|month]` | Aggregate telemetry into success rate / latency / errors |
| `/delegate [[Task]] to @<Role>` | Hand off task to a specialist persona |
| `/recall [[Task]]` | Pull delegated task back |

---

## Error Handling

Every macro failure gets classified before anything else:

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

1. Symlink the vault into your project root:
   ```bash
   ln -s ~/Library/Mobile\ Documents/iCloud~md~obsidian/Documents/Mission_Control .vault_link
   ```
2. Copy `00_Templates/AI_Project_Bootstrap.md` → create `AGENTS.md` in your project root
3. Create project passport: `01_Projects/<Name>.md` from `00_Templates/Project_Passport_Template.md`
4. Create Kanban board: `<Name>_Board.md` at vault root with columns: Backlog / Todo / In Progress / Delegated / Done
5. *(Optional)* Create `06_Research/<Name>_Research.md` for deep technical context

Boot the agent with the standard handshake. It reads your new project files automatically.

---

## Design Decisions

**Flat files over databases.** Every piece of state is a markdown file. Readable by humans, writable by any agent, diffable in git, synced by iCloud. No lock-in.

**Frontmatter as machine state.** YAML frontmatter is the source of truth for status, ownership, and routing. Agents read frontmatter; humans read the body.

**Agent is stateless, vault is not.** The agent can be replaced, upgraded, or swapped. Context injection at boot restores full situational awareness in one paste.

**One kernel file.** All global rules live in `03_Brain/System_Agents.md`. No spreading rules across READMEs, comments, or config files. If it's a rule, it's in the kernel.

**Human closes tasks, not agent.** Prevents the systemic drift where an agent finishes work, declares done, and moves on — leaving the board wrong and the next session confused.

**Voice is layered, not monolithic.** Person identity (how someone speaks) is separate from audience targeting (who they're speaking to). Swap the audience without losing the voice.

---

## Repository Contents

This repo tracks framework only. No personal data, no project-specific content.

```
Tracked:
  AGENTS.md, Welcome.md, README.md
  00_Templates/          ← task, project, error, inbox templates
  03_Brain/              ← full kernel
  05_Content/            ← content pipeline structure (no actual drafts)
  .scripts/              ← telemetry, index generation, migration tools
  setup_llm_os.sh        ← vault symlink helper (macOS / iCloud path)

Gitignored:
  02_Tasks/              ← personal task files
  04_Logs/               ← daily logs, telemetry, errors
  06_Research/           ← research notes
  99_Archive/            ← archived tasks and published content
  05_Content/03_Drafts/  ← actual draft files
  05_Content/04_Published/
  05_Content/05_Assets/
  01_Projects/ (except TiTan_LLM_OS.md)
```

---

## Status

Active, in production. Used daily across 6+ projects.

Current kernel version: v2 (2026-05-17).
Weekly memory synthesis: running (2026-W20 complete).
Content pipeline: Twitter + LinkedIn active; TikTok + Landing stubs registered.

Not yet built: per-project `VOICE.md` + `DESIGN.md` system, `/new_tiktok` full implementation, TTS + video generation pipeline.

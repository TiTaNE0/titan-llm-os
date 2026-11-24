# AGENTS.md (Root OS Loader)

## 0. GLOBAL ENGINE
- **BOOTSTRAP:** Kit subagents (`planner`, `builder`, `backend-builder`, `frontend-builder`, `researcher`, `story-writer`, `spec-writer`, `test-verifier`, `validator`, `pm-reviewer`, `failure-panel`) skip `BOOTSTRAP` and obey their Vault firewall + `CLAUDE.md` — do NOT read `./03_Brain/System_Agents.md`. Top-level sessions follow `./03_Brain/Context_Injection_Protocol.md`: build-chain invocations (`/new_task`, `/execute_task`, `/close_task`, `/orchestrator_tick`) read `./03_Brain/System_Agents.md` only up to and including `<!-- CONTENT PIPELINE` (`Context_Injection_Protocol.md § 3`, e.g. `EndLine: 200` / `sed -n '1,/<!-- CONTENT PIPELINE/p' ./03_Brain/System_Agents.md`) and read content/maintenance macros after that marker on demand; non-build-chain / content sessions (or if the marker is missing) load it in full BEFORE proceeding. *(Note: no .vault_link prefix needed here since we are at the root)*

## 0.1 HERMES VAULT BRIDGE
- **Vault path:** `/Users/titane0/Library/Mobile Documents/iCloud~md~obsidian/Documents/Mission_Control/`
- **Allowed note work:** Read, search, create, and edit Markdown notes in this vault.
- **Safety rule:** Never delete or mass-edit vault files without explicit confirmation.
- **Cross-linking:** When project work under `/Users/titane0/Programming` is relevant, connect it back to the vault notes instead of keeping it isolated.
- **Skills:** Available skills live at `.agent/skills/<skill-name>/SKILL.md`. Each has YAML frontmatter (`name`, `description`, `scope`, `read_paths`, `write_paths`, `forbidden_writes`) — read on relevant requests. Current catalog: [[.agent/skills/twitter-drafting/SKILL|twitter-drafting]].

## 1. PROJECT PASSPORT: TiTan_LLM_OS
- **Identity:** This project is `[[TiTan_LLM_OS]]`.
- **Board:** Local board is located at `./TiTan_LLM_OS_Board.md`.
- **Mission:** Maintain, refactor, and expand the local LLM Operating System.

## 2. LOCAL CONSTRAINTS
- **Dogfooding:** All upgrades to the OS must be tracked as tasks on the OS board.
- **Single Source of Truth:** Do not create duplicate rule files. All global rules go to `03_Brain/System_Agents.md`.

**Identity:** This project is `[[TiTan_LLM_OS]]`

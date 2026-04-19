---
project: [[TiTan_LLM_OS]]
source: Gemini 3.1 Pro
created: {{date}}
type: Inbox draft
---

Here is the complete post-mortem and architectural blueprint of the **Obsidian LLM OS** we just built. We went through a lot of trial by fire to get here, but the result is a highly deterministic, portable, and RAG-optimized environment.

### 🏗️ The Core Architecture (The LLM OS Blueprint)

The system relies on a decentralized, "hub-and-spoke" model where global logic is separated from local project execution.

**1. The Local Bootloader (`AGENTS.md`)**

- **Location:** Sitting in the root of your local project folder (e.g., `nearest-address-codes`).
    
- **Purpose:** This is the entry point. It acts as the "Identity Card" for the agent. It strictly defines the `[[Project_Name]]`, points directly to the project's specific Kanban board, outlines the tech stack, and dictates local terminal commands.
    
- **The Handshake:** Its most critical job is the "Bootstrap" instruction, forcing the agent to cross the symlink into the vault and read the global rules before acting.
    

**2. The Central Brain (`.vault_link/03_Brain/System_Agents.md`)**

- **Location:** Accessed via a symlink to your central Obsidian vault.
    
- **Purpose:** The global operating system kernel. This contains the universal laws of your workflow.
    
- **Mechanics:** It houses the "Synthetic Macros" (like `/new_task`), anti-token-waste protocols, YAML formatting rules, directory mapping, and the strict requirement to use Obsidian Wiki-Links (`[[filename]]`).
    

**3. The State & Memory (Vault Directories)**

- **`01_Projects/`:** Contains Project Passports (high-level goals, tech stacks).
    
- **`02_Tasks/`:** Flat structure for individual Markdown task files. Each contains YAML frontmatter (`status`, `project`, `priority`) that _must_ mirror the board.
    
- **Root (`/`) Boards:** Project-specific Kanban boards (e.g., `nearest-address-codes_Board.md`).
    
- **`04_Logs/`:** Daily session logs (e.g., `2026-04-18.md`) for context restoration on cold starts.
    
- **`99_Archive/`:** The graveyard for stale tasks and legacy docs to keep the active RAG context clean.
    
- **`00_Templates/`:** Standardized blueprints for new tasks and passports.
    

---

### 🏆 What Worked (The Architectural Triumphs)

- **"One Project, One Board" Routing:** Moving away from a monolithic board to localized, project-specific boards placed in the vault root. This made the agent's pathfinding deterministic and eliminated cross-project pollution.
    
- **Synthetic Macros:** We successfully taught a standard LLM to execute complex, multi-step procedures (identifying context, sourcing templates, generating files, and appending links to a board) simply by reading a text file. It proves the logic is entirely tool-agnostic.
    
- **Decoupled State and Execution:** By keeping the "Brain" in Obsidian and treating OpenCode just as a dumb "Runner," you created a Portable Developer Persona. If you switch to Codex, Cursor, or another IDE tomorrow, the OS goes with you.
    
- **Wiki-Link Integration:** Forcing the agent to format relationships as `[[Task_Name]]` means your Obsidian graph view remains perfectly intact and explorable, bridging the gap between CLI tools and GUI knowledge management.
    

---

### 💥 Major Fallbacks and Pitfalls (The Battle Scars)

We hit several critical failure points that caused token-wasting death spirals and forced us to pivot:

- **1. The "Master Board" Fallacy:** Initially, we tried to route all status updates to a single `Master_Board.md`. This contradicted the localized nature of the projects. The agent got confused trying to reconcile local tasks with a global tracking file, leading to routing errors.
    
- **2. Native Tool Hijacking (The "Cold Start" Problem):** We assumed passive JSON configs (`opencode.json`) would make the agent proactively read `AGENTS.md`. We were wrong. The underlying model's hardcoded training overrode our rules. When it heard "todo," it hijacked the prompt to search for GitHub projects or trigger its native `TodoWrite` tool. **The Fix:** We had to adopt a brute-force terminal command (`Read AGENTS.md and execute bootstrap`) to manually wake the agent up and load the context window.
    
- **3. The Identity Crisis (Name Mismatches):** When the project folder was named `nearest-address-codes` but the `AGENTS.md` header said `PWA_Courier`, it created a logical paradox. The agent couldn't find the `PWA_Courier_Board.md` and panicked, running `ls -la` on your entire vault and burning massive amounts of tokens. **The Fix:** Absolute strictness in naming conventions. The folder, the bootloader identity, and the board must share the exact same string.
    
- **4. The "Plan Mode" Death Loop:** When the IDE was in a Read-Only/Plan mode, but the agent was instructed to execute a file-writing macro (`/new_task`), it became trapped. It knew it _should_ execute the steps but was physically blocked from writing, so it just kept reading files endlessly to create an ever-expanding "plan."
    
- **5. Success Hallucinations:** The agent moving a task to `Done` simply because it finished writing Markdown, completely ignoring real-world CI/CD realities (like `pnpm run agent:check` failing). It required manual feedback loops or "Reject" protocols to force the agent to revert its status and actually fix the code.
    
- **6. APFS Case Sensitivity:** A classic MacOS trap. The agent failed to read `agents.md` because our configs strictly looked for `AGENTS.md`, and the APFS file system stubbornly treated them as identical when we tried to `cp` or `mv`them, blinding the agent on startup.
    

### Final Verdict

You’ve effectively built a "BIOS" for an AI agent. It’s slightly clunky on the very first boot of a session (requiring that manual initialization command), but once the context is loaded, it operates as a highly disciplined, self-documenting autonomous developer.
---
project: [[TiTan_LLM_OS]]
source: Gemini 3.1 Pro
created: {{date}}
type: Inbox draft
---
Our current vault is designed as a **decentralized, local-first LLM operating system** where the "Brain" is decoupled from the AI runner. This structure ensures that your project context is portable and that the AI always operates under a strict, predetermined protocol.

### 🏗️ Vault Structure

The vault uses a "hub-and-spoke" architecture, where global logic lives in the core folders and project execution happens in specific nodes:

- **`00_Templates/`**: Stores standardized Markdown blueprints for new tasks and project passports, using variables for automation.
    
- **`01_Projects/`**: Contains "Project Passports" that define the mission, tech stack, and hard constraints for each active project.
    
- **`02_Tasks/`**: A flat directory of individual Markdown task files, each containing YAML frontmatter that tracks state and links back to the project board.
    
- **`03_Brain/`**: The "Kernel" of the OS, specifically the `System_Agents.md` file which contains global rules, anti-token-waste protocols, and synthetic macros like `/new_task`.
    
- **`04_Logs/`**: Daily session logs used by the agent to restore context during cold starts.
    
- **`99_Archive/`**: A destination for stale tasks and legacy documentation to keep the active RAG (Retrieval-Augmented Generation) context clean.
    
- **Root (`/`)**: Houses project-specific Kanban boards (e.g., `nearest-address-codes_Board.md`) for immediate visibility.
    

---

### 🛠️ Core Plugins

To make this structure functional for an AI agent, we rely on a few key Obsidian plugins:

- **Kanban**: Used to create the visual project-specific boards in the root. The agent is strictly instructed to move task links between columns to sync its internal state with your visual workflow.
    
- **Templater**: Powers the automation logic in `00_Templates`. It allows the agent to generate new tasks with dynamic fields like `{{date}}` and `{{title}}` during the execution of synthetic macros.
    
- **Dataview (Implied)**: While not explicitly discussed, the YAML frontmatter in `02_Tasks` (tracking `status`, `project`, and `priority`) is optimized for Dataview queries to generate project reports or dashboards.
    

### ⚡ The "Handshake" Mechanism

The most critical part of this setup isn't a plugin, but the **`AGENTS.md`** file in your project's local directory. It acts as a bootloader, commanding the agent to follow the symlink into the vault and load the `System_Agents.md` rules before it begins any work.
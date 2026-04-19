---
project: [[TiTan_LLM_OS]]]
source: Gemini 3.1 Pro
created: {{date}}
type: Inbox draft
---


Here is the clean, pristine blueprint for building your Obsidian-integrated LLM OS. This guide is structured as a flawless deployment manual, outlining the exact steps to create a decentralized, tool-agnostic environment where your AI runner and your knowledge base work in perfect harmony.

As per your standing preference, I have outlined all file contents and templates using standard text formatting rather than code blocks.

---

### Phase 1: Constructing the Vault Architecture (The Brain)

The foundation of the OS is your Obsidian Vault. It acts as the central intelligence hub, storing all context, rules, and state.

**Step 1: Create the Core Directories**

Set up the following flat folder structure in a dedicated Obsidian vault:

- **00_Templates:** Stores your standard Markdown templates for new tasks and passports.
    
- **01_Projects:** Houses your Project Passports (high-level goals, tech stacks).
    
- **02_Tasks:** The flat directory where all individual task files live.
    
- **03_Brain:** Stores your global operating rules and system prompts.
    
- **04_Logs:** Holds daily session logs for context restoration.
    
- **99_Archive:** The destination for completed or stale tasks to keep the active RAG clean.
    

**Step 2: Create the Global Rules Engine**

Inside the `03_Brain` folder, create a file named **System_Agents.md**. This is the kernel of your OS. It must explicitly define:

- **Vault Security:** Read-only access for templates and passports; Read/Write access for tasks, logs, and project boards.
    
- **Wiki-Link Mandate:** A strict rule that all internal file references must use Obsidian's bracket format (e.g., `[[Task_Name]]`).
    
- **Kanban Management:** The protocol stating that a task's internal status must always match its exact column on the project-specific board.
    
- **Synthetic Macros:** Define your custom commands, such as `/new_task`. Instruct the agent that when this command is triggered, it must auto-identify the current project, source the task template, generate the file in `02_Tasks`, and append the link to the local project board.
    

---

### Phase 2: Project Node Initialization (The Spoke)

With the central brain built, you now set up the individual project environment on your local machine.

**Step 1: The Symlink Bridge**

Inside your local project folder (e.g., the directory for your courier application), create a symbolic link named **.vault_link** that points directly to your central Obsidian vault. This gives the local CLI agent physical access to the global brain.

**Step 2: The Project Board**

Open Obsidian and create a Kanban board directly in the root of the vault. Name it exactly after your project (e.g., **ProjectName_Board.md**). Set up your standard columns: Backlog, Todo, In Progress, Done.

**Step 3: The Project Passport**

Inside `01_Projects`, create a file named after your project (e.g., **ProjectName.md**). Document the core mission, tech stack, and hard architectural constraints.

---

### Phase 3: The Local Bootloader

The AI runner needs a localized set of instructions to orient itself before it accesses the global brain.

**Step 1: Create the Loader File**

In the root of your local project folder, create a file named exactly **AGENTS.md** (respecting upper-case file naming to avoid APFS case-sensitivity blindness).

**Step 2: Define the Local Identity**

Write the following sections into the AGENTS.md file:

- **Global Engine Bootstrap:** A critical instruction commanding the agent to physically read the `.vault_link/03_Brain/System_Agents.md` file before taking any other action.
    
- **Project Identity:** Explicitly declare the project name using Wiki-links and define the exact path to the project's local Kanban board.
    
- **Local Constraints:** Define specific rules for this codebase, such as preferred routing methods, styling libraries, and default terminal commands for testing or building.
    

---

### Phase 4: The Execution Workflow

With the system fully integrated, you operate the OS using a deliberate, two-step "Plan-First" workflow to ensure deterministic behavior.

**Step 1: The Cold Start Command**

At the beginning of any new terminal session, you must manually load the context window to override the AI's factory settings. Issue your start command:

> Read AGENTS.md and execute the bootstrap protocol.

The agent will read the local identity, follow the symlink to read the global rules, and optionally read the latest file in `04_Logs` to restore context.

**Step 2: Issuing Synthetic Commands**

Once bootstrapped, you interact with the agent using your defined macros. To safely trigger actions without accidental execution, use a planning directive:

> Execute /new_task [Task Name], but PLAN ONLY. Do not write files until approved.

The agent will outline its intention to create the file, assign the correct YAML frontmatter, and link it to the project-specific board. Once approved, give the green light for execution.
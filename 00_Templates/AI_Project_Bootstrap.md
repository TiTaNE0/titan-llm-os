# 🤖 AGENTS.md: Mission_Control Bootloader

## 🚨 CRITICAL: BOOTSTRAP PROTOCOL
You are an AI Agent connecting to a structured **LLM Operating System**. Before performing any task, writing any code, or responding to user requests, you MUST execute the following handshake:

1.  **Locate the Vault Link**: Identify the `.vault_link` symlink in the current project root. 
2.  **Access the OS Kernel**: Traverse the link to access the global rules at `.vault_link/03_Brain/System_Agents.md`.
3.  **Adopt System Identity**: Internalize the system rules, synthetic macros, and security protocols defined in `System_Agents.md`.
4.  **Confirm Readiness**: State clearly: *"Mission_Control rules loaded. I am ready to operate within the defined architecture."*

---

## 🏗️ Project Context
This repository is a "Spoke" in the **Mission_Control** architecture. 
* **Project Passport**: Local context is stored in `.vault_link/01_Projects/` under the corresponding Project name.
* **Deep Memory**: Technical summaries and compressed session logs live in `.vault_link/06_Research/`.
* **Task Board**: Current work state is managed via `.vault_link/TiTan_LLM_OS_Board.md` (or the project-specific Kanban board).

---

## 🛠️ Mandatory Workflow
1.  **PLAN-FIRST**: For every request, you must first output a **Plan** for approval.
2.  **Wiki-Link Mandate**: Always use `[[Wiki-Links]]` when referencing files, tasks, or research nodes to maintain vault integrity.
3.  **Human-in-the-Loop**: You are strictly prohibited from writing to disk or deleting files during state-changing macros (like `/process_inbox` or `/new_task`) without a manual "Go" signal.

---

## 🔧 Infrastructure Reference (Internal Only)
If the `.vault_link` is broken or missing, the user must run the following on macOS to re-anchor the brain:
```bash
ln -sfn ~/Library/Mobile\ Documents/iCloud~md~obsidian/Documents/Mission_Control .vault_link
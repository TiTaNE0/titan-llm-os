---
title: OpenCode + Obsidian vault pipeline for perfect agent context
status: Draft
source_project: [[01_Projects/TiTan_LLM_OS]]
tags: #AICoding #Obsidian #AgentContext #DevWorkflow
publish_date: 
---

**Tweet 1 (Hook)**
Every AI session starts the same: "Hi, here's my entire project again..."
[Insert Vault Diagram from 05_Assets/]
Got tired of it. Built a vault-first memory layer. Now OpenCode, Claude, Cursor —
they all start informed. No re-onboarding. No context tax.

**Tweet 2 (Problem)**
The bottleneck isn't your LLM.
It's that your project knowledge lives in chat history that expires every session.
Architecture? Gone. Constraints? Gone. Why you made that call 2 weeks ago? Definitely gone.
The agent is stateless. Your context is the real asset.

**Tweet 3 (The Key Reframe)**
Vault is local. Agent doesn't have to be.
Decouple the Brain (Obsidian markdown) from the Executioner
(whatever LLM you're using this week).
Claude Code → OpenCode → Cursor → Codex. Same vault. Same context. Swap freely.

**Tweet 4 (Architecture)**
Structure:
• 01_Projects/ — mission, tech stack, hard constraints
• 02_Tasks/ — YAML-linked kanban
• 03_Brain/ — rules kernel (System_Agents.md)
• 04_Logs/ — session history for context restoration

Bootstrap: AGENTS.md → System_Agents.md → agent loads rules before touching code.

**Tweet 5 (Critical Mechanism)**
The handshake: .vault_link symlink + AGENTS.md bootloader.
New tool? Point it at AGENTS.md. Self-onboards from the vault in seconds.
IDEs with built-in RAG (Cursor, Codex) index the vault via symlink. Free upgrade.

**Tweet 6 (Demo)**
Watch it: /new_thread command [Insert Terminal Output from 05_Assets/]
Directories. Templates. Brain rules updated. One command.
That's the whole system in motion.

**Tweet 7 (CTA)**
The result: your project soul lives in files, not chat history.
Agents are workers reading your blueprints. You're the architect.
What's your worst AI context headache? Drop it below.
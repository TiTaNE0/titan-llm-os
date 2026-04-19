---
project: [[TiTan_LLM_OS]]
source: Gemini 3.1 Flash
created: {{date}}
type: Inbox draft
---
Exactly. You’ve hit on the core "magic trick" and the biggest friction point of this setup: those `/commands` are **synthetic macros**, not native OpenCode tool definitions.

Because they aren't part of the runner's hardcoded binary, the model has to "think" its way through them by looking up the instructions in your brain. Adding a space (e.g., `/ new_task`) is a clever way to break the pattern-matching and stop the agent from automatically entering "Protocol Execution Mode".

---

### 🧠 Synthetic Macros vs. Native Tools

The difference is critical for how you manage your workflow:

- **Native Tools (`ls`, `cat`, `gh`):** These are "reflexes." The model doesn't need to read a file to know how to list a directory; it just calls the tool.
    
- **Synthetic Macros (`/new_task`, `/update_log`):** These are "procedures." The model sees the keyword, goes to `System_Agents.md`, and reads a 6-step manual on how to act.
    

### 🛠️ The "Space Hack" and a Better Fix

If you find yourself manually adding spaces just to keep the agent from jumping the gun, we should actually build a **"Plan-Only" toggle** directly into your `System_Agents.md` protocol.

**We can update your Macro section to include a "Safety Valve":**

> _"If a /command is followed by the word 'PLAN', do NOT execute file writes. Instead, provide a step-by-step summary of the intended changes for approval."_

This way, you don't have to mess with the syntax; you just say `/new_task PLAN nearest-address-codes_Index_Docs`, and the agent will stay in its lane until you give the green light.

---

### 🚀 Why this "Synthetic" approach is actually better

Even though it's not "native" to OpenCode, this instruction-based approach is what makes your vault **truly portable**.

If you move to a different AI tool (like Codex or a raw LLM via API), a "native" OpenCode command would be useless. But because your logic is stored in `System_Agents.md`, you can teach _any_ model how to use your Obsidian OS just by pointing it to that file. You aren't just using a tool; you've built a **standardized protocol**.

### The Solutions Architect Move

Since you're the one holding the keys to the `03_Brain`, you should decide: do you like the "Space Hack," or should we formalize a **`PLAN`** keyword in your global rules so the agent stops "acting" and starts "thinking" by default?

How would you prefer to handle that "pre-execution" phase?
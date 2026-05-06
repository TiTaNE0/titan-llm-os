---
project: [[TiTan_LLM_OS]]
status: in_progress
priority: high
created: 2026-05-04
type: task
tier: 1
---

# ⚡ Task: Implement Context Injection Protocol

## 📋 Declarative Objective
- [ ] Make the agent handshake automatically inject relevant project state, latest log, and research summaries into context BEFORE task execution begins. Move from "agent reads files when needed" to "context is pre-loaded strategically" (Karpathy: *"The bottleneck is not the LLM; it's the context."*).

## 🎯 Definition of Done (Success Criteria)
- [ ] `03_Brain/Context_Injection_Protocol.md` exists and defines the load order
- [ ] `Welcome.md` handshake updated to include the injection steps
- [ ] `System_Agents.md` references the protocol as part of bootstrap
- [ ] A fresh agent session, after handshake, can answer "what's the active project state?" without re-reading files

## 🧪 Verification Gateway
- [ ] **Test Command:** Open a new agent session. Run handshake. Ask: "Summarize the last log and current Todo column without reading new files."
- [ ] **Protocol:** Agent answers correctly from injected context.

## 📝 Agent Implementation Plan
1. Create `03_Brain/Context_Injection_Protocol.md` with:
   - Load order: AGENTS.md → System_Agents.md → latest `04_Logs/*.md` → active project passport → research summary
   - Conditional injection rules (skip Research if file missing)
   - Token budget guidance (cap at ~30% of context)
2. Update `Welcome.md` Enhanced CLI Agent Handshake to reflect new boot sequence
3. Add reference to the protocol in `System_Agents.md` Section 1 (Paths & Environment)

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** TBD
- **Deviations:** TBD
- **Debt/Future:** TBD
- **Verification Proof:** TBD

## 🔗 Related Context
- **Karpathy Source:** Year in Review 2025 — context engineering > prompt engineering
- **Plan File:** `~/.claude/plans/read-agents-md-now-i-glimmering-stream.md` Section 3.1

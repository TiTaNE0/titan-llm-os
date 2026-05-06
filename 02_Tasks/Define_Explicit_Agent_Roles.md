---
project: [[TiTan_LLM_OS]]
status: in_progress
priority: high
created: 2026-05-04
type: task
tier: 1
---

# ⚡ Task: Define Explicit Agent Roles

## 📋 Declarative Objective
- [ ] Formalize agent personas (Executioner, Architect, Researcher, Synthesizer) using CrewAI's Role/Goal/Backstory pattern. Replace the implicit "you are the Executioner" line with a structured, swappable role definition.

## 🎯 Definition of Done (Success Criteria)
- [ ] `03_Brain/Agent_Roles.md` exists, listing every persona with Role/Goal/Backstory/Constraints/Allowed_Tools
- [ ] Handshake in `Welcome.md` accepts a role parameter (`role=Executioner` default)
- [ ] Each role has scoped write permissions matching the Vault Security Protocol
- [ ] At least 2 personas are defined (Executioner + Architect minimum)

## 🧪 Verification Gateway
- [ ] **Test Command:** Run handshake with `role=Architect`. Ask agent to write to `02_Tasks/`. Agent must refuse (Architect is read/write only on `03_Brain/`).
- [ ] **Protocol:** Permission boundary enforced via role context.

## 📝 Agent Implementation Plan
1. Create `03_Brain/Agent_Roles.md` with 4 personas:
   - **Executioner** — task execution, R/W on tasks/logs/boards
   - **Architect** — rule curator, R/W on `03_Brain/`, halt-only on `02_Tasks/`
   - **Researcher** — read-only across vault, writes only to `06_Research/`
   - **Synthesizer** — runs `/synthesize`, writes to `03_Brain/Weekly_Synthesis/`
2. Wire the handshake in `Welcome.md` to load role file
3. Reference roles in macro definitions (e.g., `/graduate` → Architect; `/new_task` → Executioner)

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** TBD
- **Deviations:** TBD
- **Debt/Future:** TBD
- **Verification Proof:** TBD

## 🔗 Related Context
- **CrewAI Pattern:** Role / Goal / Backstory triplet
- **Plan File:** Section 3.3

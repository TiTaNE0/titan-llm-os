---
project: [[TiTan_LLM_OS]]
status: in_progress
priority: high
created: 2026-05-04
type: task
tier: 1
---

# ⚡ Task: Implement Memory Synthesis Loop

## 📋 Declarative Objective
- [ ] Convert raw daily logs into a structured, queryable knowledge base. Add `/synthesize` macro that runs weekly, extracts facts, detects contradictions, and proposes rule updates. Implement Karpathy's *"memory should be synthesis, not retrieval"*.

## 🎯 Definition of Done (Success Criteria)
- [ ] `03_Brain/Memory_Schema.md` defines the JSON fact format + decay rules
- [ ] `03_Brain/Weekly_Synthesis/` directory exists for outputs
- [ ] `/synthesize [week]` macro registered in `System_Agents.md`
- [ ] Macro halts for human approval before writing rule proposals to `03_Brain/`
- [ ] First synthesis produces at least 1 extracted pattern from existing logs

## 🧪 Verification Gateway
- [ ] **Test Command:** `/synthesize 2026-W18`
- [ ] **Protocol:** Output JSON synthesis file with: facts[], contradictions[], rule_proposals[]. Halt for approval.

## 📝 Agent Implementation Plan
1. Create `03_Brain/Memory_Schema.md`:
   - Fact format: `{id, claim, source_log, date, citations, confidence}`
   - Decay: 90-day no-citation → archive; 5+ citations → promote to Core Principles
   - Contradiction detection: same claim_id, opposite values
2. Create `03_Brain/Weekly_Synthesis/` directory (with .gitkeep)
3. Add `/synthesize` macro to `System_Agents.md` (read-only on logs, write to Weekly_Synthesis/, halt before rule changes)
4. Update `Welcome.md` macro index

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** TBD
- **Deviations:** TBD
- **Debt/Future:** TBD
- **Verification Proof:** TBD

## 🔗 Related Context
- **Karpathy Source:** LLM Wiki gist — "synthesis-based memory"
- **Plan File:** Section 3.2

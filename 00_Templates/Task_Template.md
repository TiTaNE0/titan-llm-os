---
project: [[Project_Name]]
status: todo
priority: medium
created: {{date}}
type: task    # or `bug` — bug tasks REQUIRE a regression-test entry in Implementation Plan
---

# ⚡ Task: {{title}}

## 📋 Declarative Objective
- [ ] (What we want to achieve)

## 🎯 Definition of Done (Success Criteria)
- [ ] (Success criteria)

## 🧪 Verification Gateway
- [ ] **Test Command:** (Command to run)
- [ ] **Protocol:** Execute and verify exit code 0.

> ⚠ **Section-presence checks must use `grep_section.sh`.** If your Test Command
> checks for the presence of a `## Section Name` header in a task .md or any
> template-derived file, do NOT use literal `grep -q "## Section Name"` — the
> template uses emoji-prefixed headers (`## 🔬 Research Notes`, `## 📐 Spec`,
> etc.), and literal patterns silently miss them. Use the canonical helper:
>
> ```bash
> .vault_link/.scripts/grep_section.sh <file_path> "<section name>" [present|empty|populated]
> ```
>
> Handles emoji-prefixed AND bare headers identically. Modes: `present` (default
> — header exists, body irrelevant), `empty` (header exists, body is only
> blockquote/blank), `populated` (header exists, body has non-blockquote content).
> Exit 0 on match, 1 on no-match, 3 on header-not-found.
>
> Promoted as canonical 2026-05-28 by [[TiTan_Kit_Integration_Phase2]] after a
> Phase 1 verification bug (deviation #2 in
> [[TiTan_Kit_Integration_Phase1|TiTan_Kit_Integration_Phase1 (Archived)]]).

## 📝 Agent Implementation Plan
- (Filled by agent during planning)

> ⚠ **Bug-task rule:** If YAML `type: bug`, the plan MUST include a regression test
> that would have caught this bug. Builder agents will refuse to populate `## Spec`
> without it. Folded into `/new_task` per Phase 1 design decision 5 — no separate
> `/new_bug` macro exists.

## 🔬 Research Notes
> Populated by `invoke_researcher` during `/execute_task` step 6. Cached thereafter
> unless `/execute_task --refresh` is invoked. May be empty for tasks created outside
> the `/execute_task` flow — that is acceptable; the section is a slot, not a contract.
<!-- write_task_section section=research_notes -->

## 📐 Spec
> Populated by `invoke_spec_writer` during `/execute_task` step 7, after user approval
> at the spec gate. May be empty for tasks not run through `/execute_task`.
<!-- write_task_section section=spec -->

## ✅ Validator Report
> Populated by `invoke_validator` during `/execute_task` step 11. Contains
> SHIP | FIX | BLOCK verdict plus severity-tagged issue list. May be empty for tasks
> not run through `/execute_task`.
<!-- write_task_section section=validator_report -->

## 📊 Verification Output
> Populated by the Verification Gateway test command during `/execute_task` step 12.
> Captures the exact command, stdout, and exit code at run time. Distinct from
> `## 🧪 Verification Gateway` above — that section is the contract (what to run);
> this section is the result. May be empty for tasks not run through `/execute_task`.
<!-- write_task_section section=verification_output -->

## 🏁 COMPLETION SUMMARY (Post-Mortem)
> ⚠️ **Completion Gate:** Agents must NOT fill this section and declare the task done autonomously. The user must explicitly trigger `/close_task` after reviewing the Verification Gateway output. Filling this section without user instruction is a kernel violation (§ 1.3).
- **Technical Meat:** (Filled by agent: What was actually changed? Any new dependencies?)
- **Deviations:** (Did the plan change? Why?)
- **Debt/Future:** (What should we clean up later?)
- **Verification Proof:** (Paste the final success output/hash here.)

## 🔗 Related Context
- **Skills:** [[.agent/skills/Relevant_Skill/SKILL]]
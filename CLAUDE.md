# CLAUDE.md — TiTan_LLM_OS (Claude Code entrypoint)

## 0. BOOTSTRAP (CRITICAL — do this BEFORE responding to the first instruction)
This vault runs an LLM OS. Claude Code auto-loads THIS file, not `AGENTS.md`, so the OS bootstrap must start here.
- Read and adopt `./03_Brain/System_Agents.md` in full — kernel, macros, personas, error framework, telemetry contract.
- Then follow `[[Context_Injection_Protocol]]`: pre-load kernel + active role + latest `04_Logs/` entry + project state before acting on the first instruction.
- `AGENTS.md` (root) is the canonical OS loader for non-Claude agents (Codex/OpenCode/etc.); this section mirrors its §0 so Claude Code boots identically. Keep the two in sync.

## 1. PROJECT PASSPORT: TiTan_LLM_OS
- **Identity:** `[[TiTan_LLM_OS]]`  ·  **Board:** `./TiTan_LLM_OS_Board.md`
- **Mission:** maintain, refactor, and expand the local LLM OS.
- **Default persona:** Executioner (switch via `role=<Name>` at handshake).
- **Constraints:** vault security (`03_Brain/`, `01_Projects/` read-only) and dogfooding (OS upgrades tracked as board tasks) per `System_Agents.md §2` / `AGENTS.md §2`.

## 1b. PIPELINES (run-phrase → runbook)
- **"Run the @ogrizkov Twitter reply pipeline."** → load and follow `05_Content/accounts/ogrizkov/channels/twitter/skill/twitter-reply-orchestrate.md`, the current runbook (version-agnostic — the runbook itself is the source of truth for the active version). It is self-contained and points to its own roster / role-specs / PRD / overview. That one sentence is the entire start prompt; everything else lives in the runbook.

## 2. CODING GUIDELINES

Behavioral guidelines to reduce common LLM coding mistakes. Merge with the OS rules and the global `~/.claude/CLAUDE.md` as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

### 2.1 Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

### 2.2 Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.w
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

### 2.3 Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

### 2.4 Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

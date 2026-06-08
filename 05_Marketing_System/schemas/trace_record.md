---
type: pipeline-artifact
artifact: trace-record-schema
prd_ref: "§11, §8.9"
locked: 2026-06-01
---

# Trace record schema (non-blocking)

Every agent step is traced by a **non-blocking post-step hook that ALWAYS fires** (§8.9). A trace failure must NEVER halt a run; a guardrail rejection must still be traced. Trace **observes**, it never blocks.

## Location
Per-run subfolder: `runs/<date>_run<NN>/` (atomic, greppable; a corrupt run can't poison the log — §11). One file per step:
```
runs/2026-06-01_run01/
  00_scout.md  01_strategist.md  02_creator.md
  03_gatekeeper.md  04_debate.md  05_judge.md  06_producer.md
```

## Per-step record
```markdown
## [NN]_[agent] — [timestamp]
- agent: [Scout|Strategist|Creator|Gatekeeper|Critic/Judge|Producer]
- model: [exact id, e.g. anthropic/claude-opus-4.8]
- provider: [openrouter|xai-oauth|openai-codex]
- tokens_in: [n]      # source of cost-per-piece
- tokens_out: [n]
- input_summary: [what it read — files / prior step]
- output: [full, or key excerpts]
- decision: [score 0–1 | verdict | pass/fail | n/a]
```

## Run summary (appended at end of run)
- total cost / total tokens
- per-step tokens
- failures / friction
- **gatekeeper kill-rate** (validate the 40–70% band — §10.1)

## Rules
- Always write, even on guardrail rejection or step error.
- Never throw from the trace hook.
- `tokens`, `model`, `provider` are mandatory — they ARE the cost instrument.

---
type: pipeline-artifact
artifact: judge-rubric
prd_ref: "§10.2, §8.1, §8.2, §3.3"
locked: 2026-06-01
---

# Judge rubric (full, 0–1 weighted)

Scored by the cross-family Critic/Judge (`gpt-5.5`, provider `openai-codex`) — see `role_specs/critic_judge.md`. The Judge **scores; it never rewrites** (§3.1). Subjective criteria are scored by **similarity to gold standards**, not abstract ideals.

## Criteria (0–1 each, weighted — tune weights after first runs)
1. Strong, specific **hook** (interpreted per content_type — below).
2. Clearly shows the **before → after intuition benefit** (CANON Manifest).
3. Matches the **target channel/audience voice** (vs gold standards).
4. Clear, **low-friction CTA**.
5. Would the **target audience actually save/share** this?  ← sharpens once CANON audience is real
6. **Consistent with CANON** (hero, manifest, continuity from LEDGER).

## Gate
- **threshold: ≥ 0.75** → pass to Producer. Below → back to the debate loop, **within the 2× cap** (§4). On cap-exhaust → log DECISIONS (rejected, stage=judge) and stop.

## Per content-type interpretation
The "hook" and "save/share" bars read by `content_type`:
- `video_short` (Phase 1) → first-2-seconds hook; save/share = would a viewer save for later or send to a friend.
- carousel / x_post → not scored in Phase 1.

## Gold-standard dependency (real sequencing constraint — §10.2)
Gold standards are **per (channel × content_type)**. Phase 1 loads `video_short` only. **Criteria 3 and 5 are scored against `gold_standards/video_short/` and sharpen once CANON audience is set** — until then, score them provisionally and flag low confidence. Winners get promoted to gold standards over time (§8.5).

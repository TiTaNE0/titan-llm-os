---
type: pipeline-artifact
artifact: viability-gatekeeper-rubric
prd_ref: "§10.1, §8.8, §3.1"
locked: 2026-06-01
---

# Viability Gatekeeper rubric (cheap, 0–1)

Scored fast by Haiku (`anthropic/claude-haiku-4.5`, openrouter). The **primary margin lever** (§8.8): kills weak directions BEFORE frontier tokens (Opus + GPT) hit the debate loop. Automated gate — no human (§7).

## Score (0–1, average of three axes)
1. **CANON alignment** — does it fit hero / manifest at all?
2. **Hook potential** — is there a plausible strong hook here?
3. **Trend fit** — does it match the Scout's current winning formats?

## Gate
- **threshold: ≥ 0.55** → enter the debate loop. Below → **KILL** here: log to DECISIONS (decision=killed, stage=gatekeeper, score), skip.

## Calibration (logged + reviewed every run)
- Target kill rate **40–70%** (2026 best-practice band). A run at 65% is on-trend, not broken.
- Recalibrate threshold/rubric ONLY if it kills **<30%** (too soft — frontier tokens wasted) or **>75%** (too harsh — starving the loop).

## Per content-type interpretation
"Hook potential" is read by `content_type`:
- `video_short` (Phase 1) → **first-2-seconds** scroll-stop.
- carousel → cover-slide scroll-stop · x_post → first-line unfold. *(not evaluated in Phase 1)*

## Mindset (Tier-3 spec)
Score fast and cheap; this is triage, not full review. A weak idea = generic, off-manifest, or no plausible hook. When torn between 0.5 and 0.6, lean to the side that holds kill-rate in band.

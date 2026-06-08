---
type: pipeline-artifact
artifact: gate-config-per-content-type
prd_ref: "§8.10, §10.2"
created: 2026-06-05
---

# Per-content-type gate config (ADDITIVE — the gates READ this; scoring LOGIC unchanged)

The gatekeeper + judge **rubrics** hold the scoring logic (criteria, weights, thresholds 0.55 / 0.75) and are **unchanged**. The criteria that are *content-type-specific* live HERE, so a new type plugs in additively. A gate reads its type's row; if a type is absent it falls back to the rubric's `video_short` defaults.

## Hook semantics (criterion 1 — "first-2s" is a video-only default)
| content_type | what "hook" means |
|---|---|
| video_short | first-2-seconds of motion (rubric default) |
| slideshow | the **COVER SLIDE** (slide 1) — the scroll-stop is the first still image, not motion |

## Craft constraints (gatekeeper + judge enforce per type)
| content_type | hard rule |
|---|---|
| video_short | (none beyond the rubric) |
| slideshow | **CONFESSIONAL only** — experiential / on-pain personal story; **NEVER formula/teaching**. Unit-confusion is a *beat inside the story*, not the subject. A formula/teaching slideshow is a **KILL** regardless of other scores. (T0 signal: confessional @elleosiliwood 530 shares vs formula card @mathmadeeasywithpat 2K.) |

## Gold-standards set (criteria 3 voice & 5 save/share scored by similarity)
| content_type | dir |
|---|---|
| video_short | `gold_standards/video_short/` |
| slideshow | `gold_standards/slideshow/` |

## Success metric — SELF-RELATIVE, not market-relative (validation-model fix)
We are **MANUFACTURING** the slideshow niche, not entering one. A thin scrape of an empty niche proves nothing — so the market-relative T0 test ("did we beat existing creators / does demand already exist") is the **WRONG** test. Success = a piece beats **OUR OWN earlier runs** on **Swipe-Through Rate (STR) + saves/shares** (captured in `Campaigns/<product>/ANALYTICS.md`). Never market-relative reach.

## Kill condition (pre-committed — bounds "the niche is small, give it time")
Produce + post **N = 10** slideshows over **X = 4 weeks**; if self-relative STR + saves/shares show **no upward trend by run K = 6**, re-spec the approach. (N/X/K committed 2026-06-05; adjust only with operator sign-off.)

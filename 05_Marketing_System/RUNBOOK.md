---
type: pipeline-artifact
artifact: operator-runbook
status: active
created: 2026-06-10
applies_to: TikTok faceless slideshow (module tiktok__slideshow__faceless)
worked_example: Intuiscale run07 (2026-06-10_run01)
---

# RUNBOOK — slideshow pipeline, start to finish

The repeatable run for a TikTok faceless slideshow: scrape → 7-agent chain → draft →
render prep → image generation → fuse → post. Each phase lists **who** does it, the
**command**, and the **output**. Paths are relative to the vault root (the directory
holding `05_Marketing_System/` and `05_Content/`). The worked example is Intuiscale;
swap the campaign dir for another product.

**Automated & deterministic:** Phases A, B, C, E.
**Operator (you):** the CANON inputs, go/no-go judgment, Phase D (generation in Antigravity), Phase F (post + analytics).

---

## Prerequisites
- `APIFY_TOKEN` in `~/.hermes/profiles/marketing/.env` (Phase A scrape).
- `OPENROUTER_API_KEY` in the same file (agent chain if Hermes-routed; from Claude Code the agents are driven directly).
- `CANON.md` in the campaign dir — the FIXED inputs (audience, Hero, Manifest). Not edited per run; changing it is a deliberate BREAK + change-log entry.
- `brand_guidelines.json` in the campaign dir (palette / refs / accent — read by `asset_prompt.sh`).
- Remotion project at `/Users/titane0/AI_Workflow/remotion` (installed; renders the UI screenshots).
- `jq`, `perl`, `python3` (+ Pillow, numpy) available.

---

## Phase A — Scrape fresh signal  ·  automated
1. Create the run dir: `05_Content/Campaigns/<Campaign>/runs/<YYYY-MM-DD>_runNN/`.
2. Write `_apify_input.json` (hashtags + search queries for the niche).
3. Scrape (source the token first):
   ```bash
   ( set -a; . "$HOME/.hermes/profiles/marketing/.env"; set +a
     curl -sS -X POST \
       "https://api.apify.com/v2/acts/clockworks~tiktok-scraper/run-sync-get-dataset-items?token=$APIFY_TOKEN&format=json" \
       -H 'Content-Type: application/json' --max-time 540 \
       --data @"<run>/_apify_input.json" > "<run>/_apify_scrape.json" )
   ```
4. Build `_scrape_digest.md` (format ceilings slideshow-vs-video, top performers, on-pain confessional samples, noise to drop).

**Out:** `_apify_scrape.json`, `_scrape_digest.md`. Engagement is REAL — never fabricate signal (the scout schema bans it).

---

## Phase B — 7-agent chain → finished draft  ·  automated
One subagent per role, each reading its role spec + the prior artifact. Specs in `05_Marketing_System/role_specs/`, `rubrics/`, `schemas/`, `gold_standards/`, `gate_config/`.

| # | Agent | Reads | Writes | Gate |
|---|-------|-------|--------|------|
| 1 | Scout | digest, CANON, gold standard | `00_scout.md` | must pass `validate_scout_schema.sh --file <00_scout.md>` (5 headers + source-honesty) |
| 2 | Strategist | scout, CANON, LEDGER, DECISIONS | `01_strategist.md` | picks ONE angle; continuity-checked vs already-shipped runs |
| 3 | Creator | strategist, gold standard | `02_creator.md` | 3 concepts, CONFESSIONAL only (formula/teaching = kill) |
| 4 | Gatekeeper | creator, `gatekeeper_rubric.md`, `gate_config/content_types.md` | `03_gatekeeper.md` | ≥0.55 + slideshow KILL rules; advances ONE |
| 5 | Debate | the survivor, `judge_rubric.md`, gold | `04_debate.md` | adversarial; fixes binding gaps; final block is self-contained |
| 6 | Judge | the FINAL block (fresh context), `judge_rubric.md` | `05_judge.md` | **≥0.75 PASS**; flags low-confidence criteria |
| 7 | Producer | judge verdict, `producer_profiles.md` | `drafts/runNN_*.md`, `06_producer.md`, LEDGER row | emits `## Slide Brief` + `## Asset Inventory` JSON blocks |

**Out:** the canonical draft in `drafts/` (carrying the two fenced-JSON blocks the render scripts parse) + a LEDGER row at status `produced`.

**Voice note:** slide copy + post caption are authored in the lowercase confessional voice. Casing is NOT fixed in the draft — the render layer applies device-autocorrect (`i → I`) deterministically. Draft = the voice; render = the device.

---

## Phase C — Render prep  ·  automated · deterministic
```bash
05_Marketing_System/bin/render_prep.sh \
  --draft 05_Content/Campaigns/<Campaign>/drafts/runNN_*.md \
  --campaign 05_Content/Campaigns/<Campaign>
# default screen-mode = model-fuse. Add `--screen-mode python-warp` only if the
# image model garbles on-screen text and you want guaranteed-crisp screens instead.
```
Runs `render_manifest.sh` (→ `render_manifest.json` + `GENERATE.md`; captions and the post caption auto-corrected `i→I`) then `render_ui.sh` (→ `ui/slide_N_ui.png`, the Remotion screenshots).

**Out:** `render_manifest.json`, `GENERATE.md` (the generation runbook), `ui/*.png`.

**Two screen modes:**
- `model-fuse` (default): the Remotion UI screenshot is rendered FIRST and handed to the image model as a reference; the model paints it onto the phone during generation (native glow/reflections). Python then only burns captions.
- `python-warp` (fallback): the phone screen is generated as flat `#FF00FF`; Python chroma-keys + perspective-warps the crisp UI on. Guarantees text fidelity, flatter look.

---

## Phase D — Generate base photos  ·  OPERATOR (Antigravity)
The one manual step. Image generation runs in **Antigravity** (Nano Banana / Gemini 2.5 Flash Image) — the headless `gemini` CLI has no image tool wired.

1. Open Antigravity with the vault root as workspace.
2. Point it at `runs/<run>/GENERATE.md` and have it follow the AGENT INSTRUCTIONS:
   - generate the **anchor slide first**, save as `assets/slide_<anchor>_base.png`; reference it on every other slide so the world stays identical;
   - on SCREEN slides, **attach `ui/slide_N_ui.png`** and render it onto the phone with the full device-realism treatment (emissive screen, glossy glass + reflections, scene lighting) — text reproduced verbatim, never redrawn;
   - save each to its exact `assets/slide_N_base.png` (1080×1920).
3. Eyeball on-screen text on the UI slides. If garbled, re-run Phase C with `--screen-mode python-warp` and regenerate those screens as flat `#FF00FF`.

**Out:** `assets/slide_1..N_base.png` (real photos).

---

## Phase E — Fuse  ·  automated · deterministic
```bash
05_Marketing_System/bin/render_run.sh --run-dir 05_Content/Campaigns/<Campaign>/runs/<run>
```
model-fuse → burns captions onto the photos (UI already in them). python-warp → also warps the UI onto the keyed screens. Either way builds the finished slides + a contact sheet.

**Out:** `composed/slide_N.png` + `composed/contact-sheet.png` (review this).

---

## Phase F — Post & close the loop  ·  OPERATOR
1. Post the `composed/` slides to TikTok in order. **Toggle AI-content disclosure ON** (photoreal AI imagery; SynthID is embedded regardless).
2. Paste the post caption from `GENERATE.md` → "## Post caption" (already `i→I` corrected).
3. Move the LEDGER row `produced → posted`.
4. When numbers arrive, paste into `ANALYTICS.md` (views, saves, shares, STR = % who reach the last slide). This is the ONLY thing that turns the self-relative gates from hypotheses into measured ground truth — the next run's Strategist reads it. Kill condition: N=10 posts / 4 weeks / re-spec if no upward trend by run K=6 (`gate_config/content_types.md`).

---

## Script reference
| Script | Phase | Signature |
|--------|-------|-----------|
| `validate_scout_schema.sh` | B | `--file <00_scout.md>` |
| `asset_prompt.sh` | (legacy) | `--draft --campaign` → `visual_identity.json` + `07_asset_prompt.md` |
| `slide_brief.sh` | (legacy) | `--draft --campaign` → `08_generation_brief.md` (human Path B brief) |
| `render_manifest.sh` | C | `--draft --campaign [--screen-mode]` → manifest + GENERATE.md |
| `render_ui.sh` | C | `--run-dir [--remotion]` → `ui/*.png` |
| `render_prep.sh` | C | `--draft --campaign [--screen-mode] [--remotion]` (runs manifest + ui) |
| `fuse_slides.py` | E | `--run-dir` → `composed/*` |
| `render_run.sh` | E | `--run-dir` (runs fuse) |

`asset_prompt.sh` / `slide_brief.sh` are the original asset-library / human-brief lineage (→ `visual_identity.json` for cross-run asset accumulation). The validated operational render path is `render_prep` → (Antigravity) → `render_run`. The Hermes-routed `debate_loop.sh` / `gatekeeper_decide.sh` exist but need a Hermes profile; from Claude Code the agent chain (Phase B) is driven directly.

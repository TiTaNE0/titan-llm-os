# _schema — DEPRECATED (v2.x reference only)

The three files in this directory (`01_candidates.json`, `02_anchored.json`, `03_tactical_brief.json`)
are reference schemas for the v2.x single-agent runs only. Do not write these files in a v3 run.

v3 (PRD v3.0 Agentic) uses the 5-stage artifact chain defined in:

    ../../agents/schemas.md

which covers: `00_candidates.json` → `01_anchored.json` → `02_drafts.json` → `03_review.json`
→ `replies_to_post.md`.

---
title: <Post title — short, internal-use only; not posted to LinkedIn>
module: linkedin
status: drafting
source_project: [[01_Projects/...]]
tags: []
target_publish_date:        # YYYY-MM-DD — optional. If empty, FIFO by file mtime
publish_window:              # optional override of post_schedule from config.json
publish_attempts: 0
publish_error:               # bot fills on failure
urn:                         # bot fills on success
published_at:                # bot fills on success
---

<!--
  PHASE E DRAFT TEMPLATE — LinkedIn Post

  Status workflow (you control it manually):
    drafting  — work in progress; bot ignores
    ready     — bot will publish on next anchor run
    scheduled — bot has locked the draft for publication (auto-set; do not edit)
    published — bot has successfully published; file moves to 04_Published/
    rejected  — 3 publish attempts failed; needs your investigation

  Format checklist (see strategy.md for full rules):
    [ ] Hook line front-loaded (first 200 chars carry the insight)
    [ ] No # H1 headings (LinkedIn doesn't render Markdown headings)
    [ ] Line breaks between paragraphs (1–3 lines each)
    [ ] Length 1200–1800 chars (sweet spot)
    [ ] No raw URLs in body (put links in first comment after publish, manually)
    [ ] 3–5 hashtags at end
    [ ] Voice matches `accounts/<account>/voice.md` (default account: `ogrizkov`)

  Body goes below this comment block. Plain text or light Markdown (LinkedIn
  strips most Markdown but accepts line breaks and emoji).
-->

<Post body — replace this placeholder with the actual post text.>

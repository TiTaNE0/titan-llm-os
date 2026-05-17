---
project: "[Project Name]"
type: "[tiktok | twitter | landing | article | linkedin]"
status: "draft"
category: "[feature_or_module_context]"
persona: "[target_audience_segment]"
slug: "[kebab-case-id]"
created: YYYY-MM-DD
---

<!-- AGENT INDEXING RULE: `type:` is the absolute source of truth for channel routing.
     File prefix (tiktok_, x_, landing_, article_, linkedin_) is a human visual fallback only.
     Never derive the channel from the filename. Always read frontmatter. -->

<!-- STATUS LIFECYCLE:
     draft → ready → [scheduled by bot] → published | rejected
     Only touch status manually up to "ready". Bot owns the rest. -->

<!-- CHANNEL-SPECIFIC BODY STRUCTURE — delete unused sections:

     type: x         → See 05_Content/modules/twitter/templates/Thread_Template.md
     type: tiktok    → See 05_Content/modules/tiktok/templates/Script_Template.md
     type: landing   → See 05_Content/modules/landing/templates/Landing_Template.md
     type: article   → See 05_Content/modules/article/templates/ (when active)
     type: linkedin  → See 05_Content/modules/linkedin/templates/Post_Template.md

     This universal template defines the frontmatter schema only.
     Copy the channel-specific template for the full body structure. -->

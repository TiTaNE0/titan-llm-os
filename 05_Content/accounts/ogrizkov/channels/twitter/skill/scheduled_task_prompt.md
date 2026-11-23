---
name: twitter-reply-pipeline
description: Run the @ogrizkov Twitter reply pipeline twice a day in unattended mode and email the passed reply ideas for manual posting
---

Working directory: /Users/titane0/Library/Mobile Documents/iCloud~md~obsidian/Documents/Mission_Control

Scheduled starts: 15:30 and 20:00 Israel, as in `agents/params.json` (a session starts about 11 minutes later).

Run the @ogrizkov Twitter reply pipeline in unattended mode: load and follow `05_Content/accounts/ogrizkov/channels/twitter/skill/twitter-reply-orchestrate.md`, section UNATTENDED MODE. That section owns every unattended rule; nothing in this prompt overrides it.

Do not commit anything.

Final message: slot id, batch ids, attempts used, critic model used, items delivered and recommended, whether the mail was verified in Sent, minutes to Sent, grok calls used.

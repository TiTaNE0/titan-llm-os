---
name: weekly-synthesize
description: Run the weekly /synthesize in unattended mode as the Synthesizer and surface rule proposals in the daily log
---

Working directory: /Users/titane0/Library/Mobile Documents/iCloud~md~obsidian/Documents/Mission_Control

This task starts Monday 09:00 Israel (Asia/Jerusalem).

Run the weekly synthesis in unattended mode as the Synthesizer: load and follow `.scripts/runbooks/synthesize.md`, section UNATTENDED MODE. That section owns every unattended rule, including the handshake; nothing in this prompt overrides it.

Skip the default post-boot session-state handshake: the runbook's keyed handshake in UNATTENDED MODE owns it, and the legacy .session_state.json is never written.

Do not commit anything.

Final message: as UNATTENDED MODE lists.

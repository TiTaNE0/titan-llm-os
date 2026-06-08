# Analysis — Account Performance Snapshots

This folder holds dated account-review snapshots produced by [[System_Agents|/x_review]]. Each file is a **perishable data point**, not strategy.

## Rules

- **Observation, not instruction.** Reviews record what happened in a period — follower counts, top posts, reply rates, deltas, pattern reads. They are evidence for the human to weigh, not directives an agent should act on.
- **Strategy is human-edited.** `[[accounts/<account>/channels/<channel>/strategy]]` is doctrine. It is edited by a human informed by these reviews. `/x_review` never writes to `strategy.md`.
- **Files chain backward.** Each review's `prev_review:` frontmatter points at the previous dated file in this folder. The macro fills this automatically.
- **Naming:** `YYYY-MM-DD_account_review.md`. One review per day max — the macro refuses if today's file already exists.
- **`/x_review` does NOT invent metrics.** It writes a skeleton with empty metric fields. The human fills them, or pastes a third-party summary into Snapshot and rewrites.
- **`n/a` vs blank.** If a metric isn't available in a given period (X Analytics dashboard may not surface it for small accounts), write `n/a`. **Never leave a metric field ambiguously blank.** Blank means "human hasn't filled this yet"; `n/a` means "not available this period". The distinction matters when the next review computes a delta — `blank ≠ n/a ≠ 0`.

See also: [[accounts/README]] (two-axis model), [[modules/<channel>/templates|channel templates]] (skeleton source).

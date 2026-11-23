# Pending spec revision (not applied yet)

State on 2026-11-23, about 21:15: the planner was stopped by the account's 5-hour usage limit (resets 01:00 Asia/Jerusalem) before it applied this revision. The spec in the task file is the version with hooks, the 10 audit fixes, maximum delivery and the large-account lane. The operator said "proceed" after reading the system summary; the main session treats that as approval of the spec and of the build, once this revision is in.

Apply these points, then run spec_rubric.sh, then build (execute_task Step 10 onward).

## A. From the hook study (`E5_reply_hooks.md`, `reply_patterns.md`)
1. Remove any cap on the share of questions. A question must name one concrete detail of the post and must not ask what the post already says.
2. Rank on two signals: authors who answer (as now) and post momentum (a fresh post past, or heading past, 20,000 views). Record `parent_views_at_capture`, show it in the mail, make the threshold a parameter.
3. Starters: 40 words at most; never open with a verdict on the post, never restate it, never end on a maxim. Point the Drafter at the sheet's X ids; do not duplicate rules.
4. Delete the stale Risks note that says the Definition of Done is behind.
5. Open point for the measurement plan, not a rule change: in the study the Clean core move ("one checkable point") was the most common move among losing replies (15 winners, 13 controls), and short reactions won views as often as anything (26 winners, 10 controls) while drawing only thank-you answers. Log the move per posted reply so day 14 can test this on his account.

## B. Grok is expensive: use it only when necessary (operator, 2026-11-23)
The grok CLI stopped with "402 Payment Required: Grok Build usage balance exhausted". He is on a mid-tier subscription.
1. Grok is used only for what nothing else can do: the discovery search on X. Budget: at most 3 grok calls per run, a parameter; the preflight does not spend a grok call on a probe when the last run's call succeeded.
2. Everything that reads known posts uses the public conversation endpoint the hook study used (`api.fxtwitter.com/2/conversation/<post id>` and its status lookup), with grok only as a fallback: thread snapshots and top replies, his reply count for today, the 24 h and 48 h readings for the reply log, author answers, the pattern refresh.
3. `runs_per_window` stays 1 at launch (a second in-window check would double the grok calls). Day 14 decides.
4. No grok call for research by the main session without a stated need; batch questions into one call.
5. The preflight reports "grok balance exhausted" with its own exit code; the slot counts as a non-delivery with that reason.
6. Risk to state in the spec: the public endpoint is unofficial and can change; every use has a grok fallback and a clear failure reason.

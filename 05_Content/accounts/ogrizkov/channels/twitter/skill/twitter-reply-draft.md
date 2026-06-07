# Skill: twitter-reply-draft (Run 2 — generate drafts)

Grok Build runbook. **Run 2 of 2.** Generates full reply drafts from the feed, ready to
review and post. Writes a file; never posts.

> **Operator decision (2026-06-08):** this is a **generator**, not a polisher. The operator
> will NOT supply a per-tweet take. This overrides the "Evgeny drafts, AI polishes" clause
> in `drafting_contract.md` for replies. Truthfulness is protected by the `[VERIFY]` rule
> below instead of by a required human anchor.

## Read first
- `runs/<YYYY-MM-DD>_batch/reply_feed.md` — targets + analytics/converting angles
- `../../voice.md` — account-level voice (`accounts/ogrizkov/voice.md`)
- `../drafting_contract.md` — voice, tone, never-list (apply ALL except the anchor-required clause)

## Steps (per target the operator names; default = the feed's top picks)
1. Draft a full reply in Evgeny-B voice, grounded in: the tweet's actual content + the
   documented voice + the converting angles in `reply_feed.md` (harness/loops,
   CLAUDE.md+memory, eval-inside-the-loop, context-as-bottleneck, local-LLM perf,
   stable-simple-over-complex).
2. **Never invent specific personal facts** (hardware, tok/s numbers, "I built/ran X")
   the operator hasn't documented. If a specific claim would strengthen the reply, either
   keep it as a general take / observation / question, OR insert `[VERIFY: ...]` for the
   operator to confirm or fill before posting. A reaction/opinion grounded in his known
   stances is fine; a fabricated experience is not.
3. Voice: flat, first-person, specific, no hype, no end-question bait, no `!`, 25–45 words.
4. Gate in-loop: run `../bin/gate.sh <draft>`; rewrite until exit 0 (max 2 retries).
5. Write to `runs/<YYYY-MM-DD>_batch/replies_to_post.md` — each entry: target link, the
   DRAFT reply, and any `[VERIFY]` flags. Mark all as DRAFT.

## Hard rules
- Generate drafts; do not require operator input per tweet.
- Never invent specific personal experience/numbers/hardware → use `[VERIFY]`.
- Call `gate.sh` in-loop before finalizing each draft.
- Never post. End state is `replies_to_post.md` for human review. Day-job never referenced.

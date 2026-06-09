# Skill: twitter-reply-draft (Run 2 — generate drafts)

Grok Build runbook. **Run 2 of 2.** Generates full reply drafts from the feed, ready to
review and post. Writes a file; never posts.

> **Rev 2026-06-08 (operator):** the first live run posted nine near-identical replies
> (`memory/persistence/harness` reworded nine times, ~0 engagement). Root cause: the drafter
> was grounded only in an abstract "converting angles" list, so it produced abstractions.
> Fix: ground each reply in a **real entry from `../project_authority.md`** (the anchor
> projects' actual architecture), **one distinct entry per target, no entry reused in a
> batch**. That single rule kills both genericness (every claim now has real substance) and
> repetition (N targets force N different entries).
>
> Still a **generator**, not a per-tweet human anchor. Truthfulness is protected by the
> ledger-citation rule + `[VERIFY]` below: a draft may only state a fact that exists in a
> `project_authority.md` entry, and every entry is sourced to a passport/board/brain-file.

## Read first
- `runs/<YYYY-MM-DD>_batch/reply_feed.md` — targets, each carrying `ground_with`, `pillar`, `touches`.
- `../project_authority.md` — the grounding spine across 3 pillars (Development / Agentic /
  Marketing); the ONLY source of concrete claims.
- `../../voice.md` — account voice + hard refusals.
- `../reply_register.md` — the Twitter-reply casual-typing register (occasional real-typing texture).
- `../drafting_contract.md` — tone, never-list (apply all except the human-anchor-required clause).

## Steps (per target the operator names; default = the feed's top picks)

1. **Bind one entry (1:1).** Take the target's `ground_with` candidate from the feed; confirm
   its `tags` actually fit the tweet. If it doesn't fit, pick another `project_authority.md`
   entry that does. **No entry may be bound to two targets in the same batch.** Respect each
   entry's `reuse` cooldown (don't ground a reply on an entry posted within its cooldown).
   If you run out of distinct fitting entries → **draft fewer replies.** Skip is free.

2. **Draft in Evgeny-B voice**, grounded in three things only: the tweet's actual content +
   the bound entry's `substance` + `angle` + the documented voice. The converting angles in
   the feed are *framing* (what tends to land), never *substance* — the substance is the bound
   entry. Vary structure across the batch (rotate openers: flat correction, steelman-then-turn,
   "the part that moved it was…", "still mid-wiring…" honest-gap). Do NOT reuse one sentence
   shape for every reply. **Vary length too** — length fits the tweet and what you actually have to
   say. **Skew short — one sentence is the default and the norm.** The median reply is one short
   sentence; at least half a batch should be ≤12 words. A long reply (~18+ words) is the rare
   exception, only when the point truly needs the room (on a low-visibility thread a long reply is
   itself a flag — nobody types 48 words under a post no one reads). **Vary the opener even when two
   targets are on the same topic — no two replies may lead with the same phrase.** Don't pad to a
   length, don't make them the same length or the same shape; the batch gate now rejects too few short
   replies, duplicate openers, and too many lowercase openers.
   **Apply `reply_register.md`** — let an occasional real-typing imperfection through (lowercase
   opener, a dropped period, a small typo), sparingly and inconsistently; never break meaning and
   never touch a tool name or number that carries the concrete signal. Perfect grammar on every
   reply is itself a tell.

3. **Never invent.** Every concrete claim must trace to the bound entry. No hardware/perf
   numbers, no "I ran X on a Mac Mini." **Reply as the builder of the projects only — the
   operator's personal life and employment are out of scope and must never be inferred into a
   reply.** (Project domains are fine: `nearest-address-codes` is a delivery/logistics PWA — talk
   about the product and its engineering, nothing about who runs it.) If a sharper specific would
   strengthen the reply but isn't in the entry, write the general version OR insert
   `[VERIFY: ...]`. A reaction/opinion grounded in a `postable_as: opinion` entry is fine;
   fabricated experience is the one unrecoverable failure. **Numbers and specifics in the TARGET's
   own tweet are the other person's, not your experience** — you may acknowledge or attribute them
   ("your 6-day verification figure tracks with…"), but never present them as your own. Your concrete
   claims come only from the bound entry.

4. **Gate in-loop (per draft).** Run `../bin/gate.sh <draft>`: word count in [5,45] (low floor —
   short sharp replies are welcome; no rigid band), zero `!`, and >=1 concrete signal (number /
   tool / proper noun — the v2.2 specificity check). Rewrite until exit 0 (cap 2 retries).

5. **Batch gate (whole queue).** After all drafts, run `../bin/gate.sh --batch <queue_file>`:
   no abstraction keyword may appear in more than ceil(N/2) drafts, no two drafts may share >=7
   content words, and **the drafts must not all be ~the same length** (word range must span >=8).
   If it fails, rewrite the flagged drafts (same words → re-bind/re-angle; clustered lengths →
   make some shorter, some longer to fit each tweet).

6. **Asset step (aurora-frost → PNG, asset-worthy targets only).** For the top **1–2 asset-worthy**
   targets in the batch (strongest reach + groundable — NOT every reply), after the draft passes the
   gate, generate a branded asset while the context is live (this only works here, in Run 2 — the
   target tweet + bound entry are gone after):
   - **Format:** `insight` by default (no numbers needed — the quote is the reply's grounded point,
     ≤25 words with the punchy part wrapped in `<em>`; the 3 chips = the bound entry's specifics like
     tools/facts). Use `stats` only when the bound entry carries real numbers (hero + 4 cells). Never
     `shipped` (session-only).
   - **Fill the vault template** `../../../_shared/asset_partners/aurora-frost/<format>.html` (vault,
     agent-agnostic — not `~/.claude/skills/`): `{{HANDLE}}=ogrizkov` (the public handle, **never the
     first name**), fill the format fields from {reply + bound entry}. Keep brand DNA; no new colours,
     don't touch the "Built with Claude" footer. Same discipline as the `/recap` macro (System_Agents.md).
   - **Write HTML** to `../../../05_Assets/reply-<YYYYMMDD>-<batch>-t<N>-<format>.html` (css + avatar
     already live in `05_Assets`). Then **render PNG:** `../bin/render_asset.sh <html> <png> 1200x1500`
     (Playwright-first, Chrome/wkhtmltoimage fallback). If it exits non-zero (no renderer), keep the
     HTML and note "open + screenshot" — do not fail the batch. The render does an element crop of
     `.card` (via Playwright) — a tight branded card, no surrounding page background.

7. **Write** to `runs/<YYYY-MM-DD>_batch/replies_to_post.md` — each entry: target link, bound entry
   ID, the DRAFT reply, any `[VERIFY]` flags, and for asset-worthy targets the **asset paths
   (html + png)**. Mark all DRAFT. Print path. **Never post.**

## Hard rules
- **1:1 binding:** one distinct `project_authority.md` entry per target, no reuse in a batch.
- Grounding source is `project_authority.md` ONLY (3 pillars). Never the raw `04_Logs`, never the
  operator's personal life/employment, never hardware/perf flexes. (Project domains and their
  engineering are allowed — see step 3.)
- Both gates run in-loop before the file is final: per-draft `gate.sh`, then `gate.sh --batch`.
  `gate.sh` requires **bash ≥ 4** (Homebrew bash, e.g. `/opt/homebrew/bin/bash`); it exits loudly
  under macOS's default bash 3.2 — never hand-shim it, invoke a modern bash.
- Generator, not a per-tweet human anchor. But fabricated experience → stop and `[VERIFY]`.
- Never post. End state is `replies_to_post.md` for human review.

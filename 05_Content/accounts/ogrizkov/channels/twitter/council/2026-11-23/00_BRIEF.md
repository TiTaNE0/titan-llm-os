# Growth council brief, 2026-11-23

Purpose: decide, with evidence and a cross-family debate (Claude, Grok, Gemini), how the @ogrizkov X reply pipeline should work so that it drives **steady account growth**. The output must be decisions with numbers, not options.

## 1. The account and the setup (facts)

- Account: @ogrizkov on X. Indie AI builder, Russian native, writes English as a second language. Blue verified. Follower count in the vault is stale (52 in May 2026, ~67 in `strategy.md`); the current number must be fetched live.
- An automated pipeline finds X discussions, drafts replies, gates them and emails the drafts to him. **He posts every reply by hand from his phone.** The pipeline never posts to X.
- Hard rules that are not up for debate: never invent personal facts or experience; the pipeline never posts by itself; the email contains only real replies (no status or error mail).
- No measured data exists on which of his replies work: `runs/_analytics/wins.md` is empty. Any claim about "what works for this account" must come from a live look at the account.
- His own `strategy.md` currently says: "Quality over quantity", "2-4 high-signal pieces per week", "Best window: Israel evening (US East morning)", "Avoid looking like a reply guy", "Never post low-signal content just to maintain cadence". If the council decides on a higher volume, it must say how `strategy.md` changes and why.

## 2. What happened so far

- Batch `runs/2026-11-22_batcha/` shipped 8 replies. The operator's verdict: **"A real piece of my work is taken and stretched hard onto the post's topic just to have something to comment on. The comments are simply not interesting."** Two reviews also found 3-4 of 8 read as AI.
- A first panel of five Claude specialists reviewed it: `REPLY_QUALITY_REVIEW_2026-11-22.md` (edit plan E1-E30, full reports in its section 5). Its core finding: the pipeline forces "me too, plus my project" replies (Matcher accepts agreement as a contribution; the Critic rewards inserting project nouns; targets were 27-44 h old; TARGET=5 acts as a quota).
- That panel proposed a cap of **3 replies per run**, no minimum, and accepting empty runs. **The grounding for "3" is weak:** it came from `strategy.md` ("2-4 pieces a week", "avoid looking like a reply guy") and from repetition of the same ~31 project facts. The panel had no account data and no verified 2026 knowledge of the X ranking; its strategist marked that as unverified.
- Issues log with incidents and risks: `SCHEDULED_RUNS_ISSUES.md`.

## 3. The operator's positions (2026-11-23)

1. Volume: "This needs a comprehensive approach. What is 'only 3 replies per run' based on? I based my numbers on discussions with Grok, which knows me and my account."
2. Empty runs: "What is an 'empty run without an email'? The email is just a way to deliver results to the user." (He expects results from a run; an empty run is not a normal outcome for him.)
3. Timing of the runs: decide together with Grok.
4. Mentioning the automation publicly: "Good question. It seems disclosing automation for posting on X is not punished, but again this must be checked with Grok."
5. The council may ask Grok about the current state of the account.
6. The goal: results for **constant, ongoing promotion** of the account.

## 4. Grok's proposal (verbatim, pasted by the operator)

> Prompt for the agent rewriting the Reply Pipeline
> You are rewriting the reply generation pipeline for the @ogrizkov account. The goal is intensive but controlled growth. Target: up to 15 replies per day.
>
> Core Principles
> 1. Volume over perfection. 5-8 solid replies are better than 1 perfect reply or zero. A completely empty run should be rare.
> 2. Two types of replies:
>    - Deep — tied to real experience from the user's projects (when something relevant exists).
>    - Clean — short, precise, on-point replies. Obvious but relevant points are acceptable. Do not force a personal insight if there isn't one.
> 3. Post sources:
>    - Priority: large AI accounts (Anthropic, OpenAI, Google DeepMind, their sub-accounts, major builders).
>    - Also include relevant posts on agentic systems, Claude Code, harnesses, local models, tool calling, memory, etc.
>    - Do not over-filter at the discovery stage. Prefer finding more candidates.
> 4. Paste risk:
>    - Under accounts with >150-250k followers: prefer slightly rewritten or shorter replies.
>    - Under medium accounts: pasting is acceptable.
> 5. Do not mention the pipeline, agents, or "I use AI to reply" publicly.
>
> Schedule
> - Morning run: 14:00-15:00 Israel time (to catch fresher US posts).
> - Evening run: 19:00-20:00 Israel time.
> - Target per run: 5-8 replies (total daily target up to 15).
> - Minimum per run: aim for at least 3-4 when possible.
>
> Output Requirements for Each Reply
> - Short and concrete.
> - In the user's voice (flat, specific, minimal hype, slight ESL texture is fine).
> - Prefer one clear point over polished multi-sentence structure.
> - Avoid engagement-bait questions at the end unless natural.
>
> Additional Rules
> - Allow simple, accurate replies even if they don't reference a unique personal project.
> - Prioritize posts from major AI labs and high-visibility builders.
> - Quality gate should reject only clearly weak, generic, or off-topic drafts — not everything that lacks a deep personal insight.
> - Log which replies were Deep vs Clean for later review.
>
> Rewrite the pipeline (prompts, filters, scoring, and scheduling logic) according to these rules. Keep the existing architecture where possible, but loosen overly strict filters that force every reply to contain a unique project insight.

## 5. Where the two views agree and conflict

- **Agree:** do not force a personal project insight into every reply. (Grok: "Clean" replies; first panel: forced anchor is the root cause.)
- **Conflict, volume:** up to 15 a day and 5-8 per run (Grok) vs at most 3 per run with no minimum (first panel).
- **Conflict, bar:** "obvious but relevant points are acceptable", "volume over perfection" (Grok) vs a reply must give a stranger something the thread does not already have (first panel). The operator's own complaint was that replies are **not interesting**.
- **Conflict, targets:** prioritise the largest AI accounts (Grok) vs fresh, small-to-mid live discussions where the author answers (first panel).
- **Conflict, empty runs:** rare (Grok, operator) vs a correct outcome (first panel).
- **Open:** run timing; public mention of automation; paste and duplication risk.

## 6. Decision questions (every seat answers all of them, with numbers)

- **D1 Volume.** Replies per day and per run for an account of this size. Is the number a target, a ceiling or a floor? Should it ramp over weeks? What is the evidence?
- **D2 Reply types.** Deep vs Clean: definitions, the quality bar for a Clean reply, the ratio, and whether an "obvious but relevant" reply helps or hurts growth.
- **D3 Targets.** Which posts: largest AI accounts, mid accounts, small live threads? Freshness window, reply-count limits, top-level vs sub-replies. What does a reply from a small account get under a 500k-follower account?
- **D4 Timing.** Run slots in Israel time. Note the latency: the run takes ~30 min, then he posts by hand when he reads the email.
- **D5 Disclosure.** May replies mention the pipeline, agents or AI assistance? What do X rules say about automation and AI-written replies when a human posts them by hand?
- **D6 Paste and duplication risk.** Similar wording across replies, repeating the same project facts, identical replies under several posts.
- **D7 Empty or thin runs.** What the run does when few candidates pass: widen search, lower the bar, or deliver fewer. What is the floor?
- **D8 Quality gate.** What exactly the gate rejects, so that replies are neither forced nor boring. Reconcile Grok's "reject only clearly weak" with the operator's "not interesting".
- **D9 Measurement.** Which metrics show the plan works (profile visits, follows, author replies, impressions per reply, by type Deep/Clean and by target tier), over what period, and the rule for raising or lowering volume.
- **D10 Account risk.** Reply-guy perception, spam or low-quality downranking, limits on small verified accounts, anything in the current X ranking that punishes high-volume replying.

## 7. Evidence standard

Every factual claim carries one tag:
- `[SOURCE: url, date]` — a document, post or code that can be opened. Prefer 2025-2026 material; say when a source is older.
- `[ACCOUNT DATA]` — observed on @ogrizkov live, with the query used.
- `[MODEL OPINION]` — the seat's own judgement, with no source.

A recommendation that rests only on `[MODEL OPINION]` must say so, and must propose the measurement that would settle it.

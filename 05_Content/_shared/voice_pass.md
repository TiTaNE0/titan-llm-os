# Voice Pass Protocol

> Cross-module application procedure for any active voice file in `personalization/`. Channel-agnostic. Read alongside whichever voice file is currently active per `05_Content/modules.yaml` → `voice.path`.

## Why This Exists

The voice file describes **what the voice is**. This protocol describes **how to apply it during drafting**. The voice file alone is *constraints*; this protocol turns it into a *generative source*.

Documented failure mode (see `modules/<channel>/failure_log.md`): an agent reads the voice file, treats it as a filter applied to a technical draft, and ships prose with assistant-flavored language ("source of truth", "human-agent orchestration", etc.) that the voice file's `<avoid>` list didn't explicitly catch. The fix is the second pass below.

---

## The Mandatory Two-Pass Rule

Every draft, every channel, every macro:

1. **Pass 1 — Technical draft.** Capture facts, sequence, files, commands, model names, screenshots-needed. Write it as straight technical scratch. This pass is internal.

2. **Pass 2 — Voice pass.** Rewrite the prose using the active voice file as the *generative source*, not a filter. This is the only pass the user sees.

3. **Final.** Emit only pass 2. The pass-1 artifact is scratch — do not ship it, do not show it.

If you skip pass 2, you have failed the protocol regardless of how many `<avoid>` items you scrubbed.

---

## Voice-Pass Procedure (Ordered)

1. Load the active voice file (path resolved from `modules.yaml` → `voice.path`).
2. For every sentence in pass 1, ask: **would the speaker — per their `<voice_fingerprint>` — say this in a hallway to another engineer?**
3. If no → rewrite using the voice file's prose patterns (whatever they are: ESL texture, two-beat rhythm, flat declarative, etc.). Don't smooth ESL away if the voice file protects it. Don't insert signature phrases the voice file marks as anti-mannerism.
4. Strip assistant vocabulary (banned register below).
5. Replace "what this architecture does" with "what happened."
6. Preserve concrete filenames, commands, model names, numbers — but wrap them in lived sequence, not docs language. "I ran X, it broke at Y, fixed by Z" beats "The Y subsystem is configured to handle Z via X."

---

## Banned Assistant-Vocab Register

Delete on sight. This list complements — does not duplicate — the voice file's own `<avoid>` phrase bank.

- "source of truth", "single source of truth"
- "human-agent orchestration", "human-in-the-loop" *(in prose; fine in technical specs)*
- "final gate", "semantic boundary"
- "first-class", "battle-tested"
- "leverage" (as verb), "unlock" (as verb in non-technical contexts)
- "operationalize", "surface" (as verb)
- "this enables", "this allows", "this provides"
- Any sentence that starts with "By doing X, we..."
- "deep dive", "step-function", "force multiplier"
- "north star", "true north"

These are AI-tells that do not appear in the voice file's avoid list because the voice file was authored by a human — they are drift artifacts that emerge when an LLM reaches for "professional" defaults.

---

## Final Checklist

A draft fails if any box is unchecked:

- [ ] No hype hook (no 🚨, no "Most people don't realize…", no "Hot take")
- [ ] No engagement-bait close (no "What do you think?", no "Curious to hear…", no "Tag someone…")
- [ ] No generic AI polish — run the banned-vocab register against every line
- [ ] At least 3 concrete details (filenames, model names, numbers, exact commands, error strings)
- [ ] At least 2 short cutting lines (two-beat rhythm if the active voice file specifies it; otherwise: short sentences that land flat)
- [ ] Sounds like a builder reporting from the floor, not a tutorial walking the reader through architecture
- [ ] Hallway engineer test passes line-by-line, per the active voice file's `<decision_rules>`

---

## Failure-Mode Definition

**If the draft sounds like documentation, it failed.**

Symptoms:
- Reads like onboarding material for a teammate
- Verbs are "enables / provides / allows / surfaces"
- Architecture is described top-down ("The system consists of X, Y, Z")
- Reader gets a tour, not a story

Recovery: throw out the draft, re-do pass 2 with the voice file open in a side window. Don't iterate on a documentation-shaped draft — restart from the technical scratch and rewrite.

---

## Inheritance

This protocol applies wherever the personalization voice file is loaded. Twitter, linkedin, video, article, and any future module inherit it via the **Voice Application Contract** in `personalization/README.md`. No per-channel duplication. No per-channel override.

If a future channel needs a different protocol, add a sibling file (`voice_pass_protocol_<channel>.md`) — do not edit this one to special-case channels.

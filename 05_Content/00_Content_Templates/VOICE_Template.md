---
project: "[Project Name]"
type: "voice"
inherits: "05_Content/accounts/<account>/voice.md"
created: YYYY-MM-DD
---

# [Project Name] — Project Voice

> Copy this file to `01_Projects/[ProjectName]/VOICE.md` and fill in all fields.
> This is the PROJECT LAYER of the voice system — it defines who you're speaking TO.
> The ACCOUNT LAYER (`05_Content/accounts/<account>/voice.md`) defines how you speak. Both are always loaded together.
>
> Resolution rule: account layer wins on identity conflicts (rhythm, ESL texture, banned assistant vocab).
> Project layer wins on audience/tone guidance (register per segment, project-specific vocabulary).
>
> If this file is absent, the macro warns once and continues with account layer only.

---

## Audience Segments

Define who reads or watches this project's content. Each segment gets its own tone guidance.

### Segment 1: [Name, e.g. "indie builders"]

**Who they are:** [1–2 sentences. Job, context, what they're doing when they encounter this content.]

**What they care about:** [3–5 bullet points. Concrete concerns, not abstract values.]

**What they distrust:** [What makes them scroll past. Buzzwords, hype, generic claims.]

**Register for this segment:** [How the account's voice shifts when addressing them. e.g. "more technical, assume they know what a symlink is" / "less jargon, more outcome-focused"]

---

### Segment 2: [Name, e.g. "technical founders"]

**Who they are:**

**What they care about:**

**What they distrust:**

**Register for this segment:**

---

<!-- Add more segments as needed. Most projects need 2–3 max. -->

---

## Project-Specific Vocabulary

### Preferred terms
<!-- Words or phrases this project owns. Use consistently. -->
- [e.g. "vault" not "notes folder"]
- [e.g. "macro" not "command" or "skill"]
- [e.g. "kernel" not "config" or "settings"]

### Banned terms (project-specific)
<!-- In addition to the banned list in `accounts/<account>/voice.md` -->
- [e.g. "automate your workflow" — too generic for this project]
- [e.g. "AI-powered" — product name is specific enough]

---

## Example Lines

For each segment, one good line and one bad line showing the register difference.

### Segment 1: [Name]

**Good:** "[Write a real example line in the correct register]"

**Bad:** "[Write what the wrong register sounds like for this segment]"

---

### Segment 2: [Name]

**Good:**

**Bad:**

---

## Content Mapping

Which segments does each content channel target?

| Channel | Primary segment | Secondary segment |
|---------|----------------|-------------------|
| X / Twitter | | |
| TikTok | | |
| Landing page | | |
| LinkedIn | | |

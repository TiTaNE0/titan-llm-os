---
project: "[Project Name]"
type: "design"
version: "1.0"
created: YYYY-MM-DD
---

# [Project Name] — Design System

> Copy this file to `01_Projects/[ProjectName]/DESIGN.md` and fill in all fields.
> Required by `/new_tiktok` and any future video/landing macros before generation starts.
> The macro halts if this file is missing — there is no default fallback.

---

## Color Palette

| Role | Hex | Usage |
|------|-----|-------|
| Background | `#000000` | Main video/page background |
| Text primary | `#FFFFFF` | Headlines, body copy |
| Text secondary | `#AAAAAA` | Captions, subtext |
| Accent | `#FF0000` | CTAs, highlights, key callouts |

<!-- Add more rows as needed. Keep to 4–6 colors max. -->

---

## Typography

| Role | Font | Weight | Size |
|------|------|--------|------|
| Headline | Inter | 700 | 48px |
| Body | Inter | 400 | 24px |
| Caption (video) | Inter | 600 | 28px |
| Code / terminal | JetBrains Mono | 400 | 22px |

<!-- Caption size for video: readable on mobile, min 26px. -->

---

## Motion Language

**Cut timing:** [e.g. "hard cuts only, no dissolves" / "0.15s ease-in between scenes"]

**Transition style:** [e.g. "none — jump cuts" / "slide left between sections"]

**Pacing:** [e.g. "fast — cut every 3–5s" / "measured — let code outputs breathe"]

**Text animation:** [e.g. "word-by-word appear on VO beat" / "static, no animation"]

---

## Caption Style

**Format:** [burn-in / overlay / none]

**Max characters per line:** [e.g. 32]

**Line breaks:** [e.g. "break at natural speech pauses, never mid-phrase"]

**Banned in captions:** [list any words/phrases that must not appear in captions]

**Highlight rule:** [e.g. "accent color on key technical terms" / "no highlights"]

---

## Safe Zones

| Platform | Aspect | Avoid |
|----------|--------|-------|
| TikTok | 9:16 | Bottom 20% (UI overlay), top 8% (status bar) |
| YouTube Shorts | 9:16 | Bottom 20%, top 8% |
| Twitter/X video | 16:9 or 1:1 | Bottom 10% |

**Active area for text:** Top 8% → Bottom 20% = 72% of screen height.

---

## Brand Notes

<!-- Any other visual rules specific to this project.
     e.g. "always show terminal in dark mode", "never use gradients",
     "product screenshots use device frame: iPhone 16 Pro graphite" -->

[Add project-specific visual constraints here.]

---
slug: sapphire
account: "[[accounts/titan_proxy/account]]"
variant_key: b
status: active
created: 2026-05-19
source_of_truth: src/app/globals.css [data-variant="b"]
---

# Sapphire — Design System

Premium midnight-blue keynote aesthetic. Apple-style ambient glow, rounded glass cards, gradient hero. Used by Variant B (ru_business persona). Default theme: dark.

## Color tokens

Source of truth: `src/app/globals.css` block `[data-variant="b"]`. Any edit here must be mirrored there.

### Dark (default)
| Token | Value | Use |
|-------|-------|-----|
| `--bg` | `#0a0e17` | Deep midnight base |
| `--bg-gradient` | `radial-gradient(circle at top right, #1c2431 0%, #0a0e17 100%)` | Applied to body bg |
| `--bg-card` | `rgba(255, 255, 255, 0.05)` | Frosted glass cards |
| `--border` | `rgba(255, 255, 255, 0.1)` | Hairline dividers |
| `--text` | `#ffffff` | Body |
| `--text-muted` | `#8e8e93` | Apple-style secondary grey |
| `--accent` | `#007aff` | Apple blue (primary) |
| `--accent-end` | `#00c6ff` | Cyan blue (gradient end) |
| `--accent-gradient` | `linear-gradient(135deg, #007aff, #00c6ff)` | CTAs, accent fills, AuroraText |
| `--accent-glow` | `rgba(0, 122, 255, 0.4)` | Drifting light spot A |
| `--success` | `#34c759` | Apple-system green |
| `--success-glow` | `rgba(52, 199, 89, 0.4)` | Heartbeat pulse |

### Light
| Token | Value |
|-------|-------|
| `--bg` | `#f5f5f7` (Apple light grey) |
| `--bg-gradient` | `radial-gradient(circle at top right, #ffffff 0%, #f5f5f7 100%)` |
| `--bg-card` | `rgba(255, 255, 255, 0.3)` |
| `--border` | `rgba(0, 0, 0, 0.05)` |
| `--text` | `#1d1d1f` |
| `--text-muted` | `#86868b` |

### Body fallback
- dark: `#0a0e17`
- light: `#f5f5f7`

## Geometry

| Token | Value | Use |
|-------|-------|-----|
| `--radius` | `28px` | Cards, hero block |
| `--radius-button` | `16px` | CTAs |
| `--radius-icon` | `18px` | Icon containers |

Generously rounded — premium product hardware register (think iPhone bezel).

## Typography

| Role | Font | Weight | next/font key |
|------|------|--------|----------------|
| Display + body | Inter | 400, 600, 700 | `--font-inter` |

No mono. Sans-only throughout. Headlines lean on AuroraText (gradient sweep) for the "ВАШУ РАБОТУ" accent line.

## Effects

| Effect | Status | Source |
|--------|--------|--------|
| Hero video | ENABLED | `/assets/variant-b/hero-*.{mp4,webm,jpg}` |
| Hero video overlay | midnight wash `rgba(10,14,23,0.32→0.7)` | `--hero-video-overlay` |
| Drifting light spots (`.titan-spot--a`, `.titan-spot--b`) | ENABLED | Slow Apple-keynote ambient glow, 18s + 24s loops |
| Heartbeat pulse (`.titan-heartbeat`) | ENABLED | Calm 2s ease-in-out |
| Aurora text (`animate-aurora`) | ENABLED | 10s linear gradient sweep on hero accent |
| Card backdrop blur | `blur(20px)` | Glass-card pattern |
| Transition | `0.25s ease` | Mid-tempo |

## Imagery

- Hero footage: skyline at dusk, corporate boardroom calm, drifting bokeh, sapphire glass
- Iconography: outline icons, 1.5px stroke, rounded ends
- No emoji
- No ASCII brackets — pure visual

## Theme defaults

- Layout sets `data-theme="dark"` by default
- Theme tokens for `<meta name="theme-color">`: dark uses `#0a0e17`

## Cross-pipeline use

When this design powers a non-landing channel (video, social), preserve:
- Midnight blue base (`#0a0e17`) with radial gradient toward `#1c2431`
- Apple-blue → cyan gradient on accents (`#007aff` → `#00c6ff`)
- Generous rounding (28px on prominent shapes)
- Drifting ambient bokeh (or slowly-panning b-roll equivalent)
- Apple-system grey for muted (`#8e8e93`)
- No mono, no terminal punctuation

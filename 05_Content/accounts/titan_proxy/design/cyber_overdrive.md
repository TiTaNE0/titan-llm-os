---
slug: cyber_overdrive
account: "[[accounts/titan_proxy/account]]"
variant_key: a
status: active
created: 2026-05-19
source_of_truth: src/app/globals.css [data-variant="a"]
---

# Cyber Overdrive — Design System

Terminal / network-lab aesthetic. Pure black canvas, cyan-on-black diagnostics register. Used by Variant A (ru_devops persona). Default theme: dark.

## Color tokens

Source of truth: `src/app/globals.css` block `[data-variant="a"]`. Any edit here must be mirrored there.

### Dark (default)
| Token | Value | Use |
|-------|-------|-----|
| `--bg` | `#050505` | Page background (near-void) |
| `--bg-card` | `rgba(5, 5, 5, 0.55)` | Glass cards — translucent so fixed hero video bleeds through |
| `--bg-card-solid` | `#0a0a0a` | Opaque card fallback |
| `--grid` | `rgba(255, 255, 255, 0.04)` | 24px grid overlay |
| `--border` | `rgba(255, 255, 255, 0.1)` | Section dividers + card edges |
| `--text` | `#ffffff` | Body |
| `--text-muted` | `#aaaaaa` | Captions, descriptions |
| `--accent` | `#00f0ff` | Primary cyan — accents, brackets, kickers |
| `--accent-glow` | `rgba(0, 240, 255, 0.4)` | Glow halos |
| `--success` | `#00ff94` | Operational green — status dots, "works" |
| `--success-glow` | `rgba(0, 255, 148, 0.5)` | Pulse halo around status dots |

### Light
| Token | Value |
|-------|-------|
| `--bg` | `#f4f4f5` |
| `--bg-card` | `rgba(244, 244, 245, 0.3)` |
| `--grid` | `rgba(85, 85, 85, 0.18)` (mid-grey lines, normal blend) |
| `--text` | `#050505` |
| `--text-muted` | `#555555` |
| `--accent` | `#00a3ff` (slightly bluer to survive bright bg) |

### Body fallback (when variant root height < viewport)
- dark: `#050505`
- light: `#f4f4f5`

## Geometry

| Token | Value | Note |
|-------|-------|------|
| `--radius` | `0px` | No rounded corners anywhere — terminal aesthetic |
| `--radius-micro` | `2px` | Tightest acceptable rounding (rare) |

Corner ticks: cards display `[`/`]` style decoration via `borderTop + borderRight` (or `borderTop + borderLeft`) 2px slabs anchored to the corner — see `src/app/a/page.tsx` diag/caps/arch sections.

## Typography

| Role | Font | Weight | next/font key |
|------|------|--------|----------------|
| Display + body | Inter | 400, 700, 900 | `--font-inter` |
| Mono (status lines, body where mono is used) | JetBrains Mono | 400 | `--font-jetbrains-mono` |

- Display sizes use uppercase + letter-spacing `-2px` (headlines) or `+3px` (kickers, status badges).
- Body uses 13px mono in cards for descriptions; sans for paragraphs.

## Effects

| Effect | Status | File |
|--------|--------|------|
| Hero video (mobile portrait + desktop landscape) | ENABLED | `/assets/variant-a/hero-*.{mp4,webm,jpg}` |
| Hero video filter | `blur(2px) saturate(1.1)` (dark) / `+ brightness(0.7)` (light) | — |
| Hero video overlay | dark wash `rgba(5,5,5,0.32→0.7)` | `--hero-video-overlay` |
| Grid overlay (`.titan-grid-overlay`) | ENABLED | `mix-blend-mode: screen` (dark) / `normal` (light) |
| Scanline (`.titan-scanline`) | ENABLED | 4s linear infinite, 25vh sweep |
| Status-dot pulse (`.titan-pulse-cyber`) | ENABLED | 1.6s ease-out infinite |
| Card backdrop blur | `blur(20px)` | Required for legibility over moving video |
| Transition | `0.15s ease-out` | Fast, snappy |

## Imagery

- Hero footage: phone-screen close-ups, network terminals, signal diagnostics, dark lab desktops
- Iconography: ASCII-style `+` / `×` / `//` / `[XX]` — NOT outline icons
- No emoji
- Status badge has a pulsing green dot (`--success` with `--success-glow`)

## Theme defaults

- Layout sets `data-theme="dark"` by default
- `ThemeToggle` allows user override; tokens swap atomically

## Cross-pipeline use

When this design powers a non-landing channel (video, social), preserve:
- Cyan-on-black palette (`#00f0ff` on `#050505`)
- Grid backdrop @ 24px @ 4% alpha
- Scanline sweep (or a slowed video equivalent)
- Mono terminal copy with `//` / `_` / `[XX]` punctuation
- No rounded corners on any UI overlay

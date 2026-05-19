---
slug: ember
account: "[[accounts/titan_proxy/account]]"
variant_key: c
status: active
created: 2026-05-19
source_of_truth: src/app/globals.css [data-variant="c"]
---

# Ember — Design System

Warm cream-and-amber family register. Soft amber glow, very rounded shapes, shiny-text marketing accents. Used by Variant C (ru_family persona). Default theme: dark (but light mode is the canonical visual register; CSS treats light as default fallback).

## Color tokens

Source of truth: `src/app/globals.css` block `[data-variant="c"]`. Any edit here must be mirrored there.

### Light (canonical visual register)
| Token | Value | Use |
|-------|-------|-----|
| `--bg` | `#faf9f6` | Cream paper base |
| `--bg-card` | `rgba(255, 255, 255, 0.3)` | Frosted glass |
| `--bg-card-solid` | `#ffffff` | Opaque fallback |
| `--border` | `rgba(45, 36, 30, 0.1)` | Warm brown 10% — never neutral grey |
| `--text` | `#2d241e` | Warm near-black |
| `--text-heading` | `#451a03` | Deep burnt-umber for h1/h2 |
| `--text-muted` | `#78716c` | Warm taupe |
| `--accent` | `#f59e0b` | Amber 500 |
| `--accent-end` | `#fb923c` | Orange 400 (gradient end) |
| `--accent-gradient` | `linear-gradient(135deg, #f59e0b, #fb923c)` | CTAs, halo, shiny-text |
| `--accent-glow` | `rgba(245, 158, 11, 0.2)` | Soft halo |
| `--success` | `#f59e0b` | Same as accent — warm cohesion (no green) |
| `--success-glow` | `rgba(245, 158, 11, 0.3)` | — |

### Dark
| Token | Value |
|-------|-------|
| `--bg` | `#161412` (warm near-black) |
| `--bg-card` | `rgba(31, 27, 24, 0.5)` |
| `--bg-card-solid` | `#1f1b18` |
| `--border` | `rgba(253, 230, 138, 0.12)` (warm yellow line) |
| `--text` | `#faf9f6` |
| `--text-heading` | `#fde68a` (amber 200) |
| `--text-muted` | `#a8a29e` (warm stone) |

### Body fallback
- light: `#faf9f6`
- dark: `#161412`

## Geometry

| Token | Value | Use |
|-------|-------|-----|
| `--radius` | `36px` | Cards, hero panel — very rounded |
| `--radius-button` | `22px` | CTAs |
| `--radius-icon` | `26px` | Icon tiles |
| `--radius-pill` | `9999px` | Pills, status chips |

Heaviest rounding of any variant — radiates softness and approachability.

## Typography

| Role | Font | Weight | next/font key |
|------|------|--------|----------------|
| Display + body | Manrope | 500, 800 | `--font-manrope` |

No mono. Body uses 500. Display uses 800. Headlines feel handwritten-warm.

## Effects

| Effect | Status | Source |
|--------|--------|--------|
| Hero video | ENABLED | `/assets/variant-c/hero-*.{mp4,webm,jpg}` |
| Hero video overlay | cream wash light `rgba(250,249,246,0.08→0.28)` / warm-dark wash `rgba(22,20,18,0.32→0.7)` | `--hero-video-overlay` |
| Warm halo (`.titan-warm-halo`) | ENABLED | 7s ease-in-out breathing amber + orange dual-radial |
| Animated shiny text (`.animate-shiny-text`) | ENABLED | 8s gradient sweep on hero accent |
| Tier card smooth swap (`.titan-tier-card`) | ENABLED | 320ms cubic-bezier — bg / color / border / shadow all transition |
| Card backdrop blur | `blur(20px)` | Glass-card pattern |
| Transition | `0.4s ease` | Slowest of the three — calm, deliberate |

## Imagery

- Hero footage: family hands holding a phone, child smiling at a video message, golden-hour kitchen, video circles loading
- Iconography: soft rounded outline icons OR no icons (warm typography preferred)
- Emoji: occasional warm-tone (📸 🤍) acceptable but never decorative spam
- No ASCII brackets

## Theme defaults

- Layout sets `data-theme="dark"` by default (overridable)
- Meta theme-color for the variant: light `#faf9f6`, dark `#161412`

## Cross-pipeline use

When this design powers a non-landing channel (video, social), preserve:
- Cream `#faf9f6` light base OR warm-black `#161412` dark base
- Amber → orange gradient (`#f59e0b` → `#fb923c`)
- Burnt-umber heading color in light (`#451a03`)
- Heavy rounding (36px on cards)
- Warm halo / golden-hour glow as ambient effect
- Manrope (or close warm geometric sans)
- Calm 7s breathing animations — never snap

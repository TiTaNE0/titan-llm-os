---
title: "Fix dark mode styling throughout app"
status: done
created: "2026-04-27"
updated: "2026-04-27"
completed: "2026-04-27"
priority: high
project: [[intuiscale_project]]
context: "Dark mode toggle only affected hero ring + gear; canvas, text, tiles, and Settings sheet stayed light. Cards then collapsed onto warm-black canvas due to invisible AO shadows."
---

## Summary

Make Settings → Appearance → Dark genuinely flip the entire app, not just the ring. Drives the dashboard, greeting/title text, streak pill, domino tile cards, and the Settings sheet itself into the canonical Warm Dual-Mode Palette (zero blue), while preserving the V2.1 "Refined Spatial Claymorphism" depth in dark mode and ensuring the Settings sheet updates live (no close-and-reopen).

## Problem

The previous merge to main (`4effecb`) brought reactive `@AppStorage` propagation and theme-aware shadow assets, but several issues remained when the user toggled Dark from Settings:

1. **Dashboard force-locked to light.** `DashboardView` had `.preferredColorScheme(.light)` shadowing AppView's user-selected scheme.
2. **Hardcoded hex literals** in the header ("Today" title, streak pill) and in `DominoTile` (title text, side-wall steps) didn't respond to the scheme.
3. **Asset gaps**: `MarketingScreenBackground`, `CreamTileBackground`, `InkSecondary`, `InkTertiary` had no Dark Appearance entries — rendered light in either mode.
4. **Two existing asset dark variants violated zero-blue** (`BackgroundPrimary` was actually canonical on disk; `TextPrimary` confirmed).
5. **AO shadow opacities (0.04–0.06) collapsed against `#121110`** — black-on-warm-black at that alpha is invisible, so cards lost their elevation in dark mode.
6. **Settings sheet stayed in old appearance** until close + reopen — sheets capture `.preferredColorScheme` at present-time and don't replay parent updates through the captured environment.

## Changes Landed

### Code
- **`DashboardView.swift`** — removed the `.preferredColorScheme(.light)` lock; replaced 4 hardcoded hex literals (Today title `#111111` → `Color.intuiscaleText`; streak icon/text `#4A6645` → `Color.intuiscaleStreakPillForeground`; capsule `#D9E6D5` → `Color.intuiscaleStreakPillBackground`).
- **`Features/Marketing/DominoTile.swift`** — title `#111111` → `Color.intuiscaleText`; added `@Environment(\.colorScheme)` and split the 6-step side-wall gradient into `stepColorsLight` / `stepColorsDark` (warm umber range `#2A2520 … #1B1611`). Brown drop shadows kept unchanged per design intent.
- **`Core/Color+Semantic.swift`** — exposed two new semantic colors: `intuiscaleStreakPillBackground`, `intuiscaleStreakPillForeground`.
- **`UIComponents/IntuiSurfaceModifier.swift`** — added `@Environment(\.colorScheme)` to `IntuiCeramicSurface` and `IntuiFloatingObjectModifier`. Both shadow layers (contact + diffuse) multiply opacity by `2.0` in dark mode. So `level1` diffuse `0.04 → 0.08`, `level2` `0.06 → 0.12`, `level3` `0.08 → 0.16`. Cards visibly elevate again on warm-black.
- **`Features/Settings/SettingsView.swift`** — added `@AppStorage("settingsColorTheme")` and `.preferredColorScheme(...)` modifier on the body so the sheet declares its own preference. Settings now flips live when the user toggles Appearance from inside the sheet.

### Assets
- **`MarketingScreenBackground.colorset`** — added Dark `#121110`.
- **`CreamTileBackground.colorset`** — added Dark `#1D1B1A`.
- **`InkSecondary.colorset`** — added Dark `#C0B6AC` (warm light grey, ~70% of TextPrimary dark).
- **`InkTertiary.colorset`** — added Dark `#8E847A` (warm mid grey).
- **`StreakPillBackground.colorset`** (NEW) — Light `#D9E6D5` / Dark `#2A3326`.
- **`StreakPillForeground.colorset`** (NEW) — Light `#4A6645` / Dark `#B8CFB0`.

### Spec Documentation
- **`Documentation/Specs/DESIGN_SYSTEM.md`** — inserted §0.5 **Dual-Mode Palette (Canonical)** with the user-supplied table (`BackgroundPrimary`, `SurfacePrimary`, `TextPrimary`, `AccentTerracotta`, `TravelCardBackground`, `WorkCardBackground`, `GeneralCardBackground` — light + warm-dark + rationale). §6 "Manifesto" reference now points to §0.5.
- **`Documentation/Specs/DASHBOARD_V2_2.md`** — inserted §0 **Color Palette** with the same canonical table; bare-hex references in §1/§2 (Background `#F9F9F9`, Terracotta `#C85A3C`) now show both light/dark values alongside the semantic asset name.

## Acceptance Criteria

- [x] Dashboard canvas, greeting, "Today" title, streak pill, and Calibration/Travel tiles flip simultaneously with the toggle.
- [x] Cards visibly elevate above the warm-black canvas in dark mode (AO shadows readable).
- [x] Streak pill recedes correctly in dark mode (warm sage on warm-sage shadow, no light pollution).
- [x] DominoTile side-walls have warm-grey gradient steps in dark mode; brown drop shadows unchanged in both modes.
- [x] Settings sheet flips **live** when user toggles Appearance from inside it (no close-and-reopen).
- [x] Spec docs carry the canonical Dual-Mode Palette table with zero-blue mandate; bare hex replaced with semantic asset names.
- [x] Build succeeds (iPhone 17 Pro Simulator, iOS 26.3) with zero asset warnings.
- [x] Visual verification on simulator — dark-mode dashboard + Settings sheet captured, light-mode regression confirmed.

## Completion Summary

**Status:** ✅ Complete and visually verified on iPhone 17 Pro Simulator (iOS 26.3).

**Verification artifacts** (this session):
- `/tmp/v2_dark_dashboard.png` — dark-mode dashboard with elevated CTA, dark cream tiles.
- `/tmp/v2_dark_final.png` — confirms dark choice persists across app relaunch via `@AppStorage`.
- Live picker test: toggling Appearance Light → Dark → Light inside the open Settings sheet flipped the sheet immediately each time.
- Zoomed Settings screenshot: Profile/Training/System cards visibly float with soft AO halos in dark mode (the V2.1 "Refined Spatial Claymorphism" depth is preserved).

**Out of scope / not changed:**
- DominoTile warm-brown drop shadows (`#503728`, `#3A2418`, `#6E4A2E`) — intentionally unchanged in both modes per user decision; they stylize the tile as "ceramic on paper" and read correctly under cream and warm-dark surfaces alike.
- Portal void core/rim hex literals in `Color+Semantic.swift` — mode-agnostic by design.
- `SettingsFeatureTests.swift` compile failure (uses removed `.binding(.set(...))` API) — pre-existing, unrelated, spawned as a separate task chip.

## Next Steps

None — task fully closed. Any future dark-mode tuning should reference §0.5 of DESIGN_SYSTEM.md as the canonical palette source.

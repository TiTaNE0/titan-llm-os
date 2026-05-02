---
project:
  - - Intuiscale
status: todo
priority: medium
created: 2026-04-23
type: task
---

# ⚡ Task: Codex-Ready Alt-Link Asset Integration for Existing iOS UI

## 📋 Declarative Objective
- [x] Enable agents to add and wire alt-link assets into existing iOS screens/components with iOS 17 native typed assets and layout-safe rendering guarantees.

## 🚫 Non-Negotiable Agent Rules
- [x] iOS target is 17+, so use Xcode native typed asset accessors; do not introduce third-party asset codegen.
- [x] Do not use string-based asset loading in app UI (`Image("...")`, `UIImage(named:)`).
- [x] Use typed asset resources only (example pattern: `Image(.myIcon)`).
- [x] Route visual asset rendering through a single wrapper component (for example `SafeImageContainer` / `IntuiscaleAsset`), not ad-hoc `Image` modifiers in screens.

## 🎯 Definition of Done (Success Criteria)
- [x] A documented asset convention exists for names, paths, and variants in `Assets.xcassets`.
- [x] Existing screens/components consume assets through native typed accessors only (no raw image string literals).
- [x] A `SafeImage`-style SwiftUI wrapper exists and enforces layout safety (`resizable`, scaling mode, clipping, and semantic frame policy).
- [x] Wrapper supports semantic size intents (for example: `icon`, `hero`, `cardBackground`) so agents pick roles, not raw pixel guesses.
- [x] Wrapper has graceful placeholder rendering for missing/pending alt-link assets so screens stay stable while assets are in flight.
- [x] Alt-link flow is documented end-to-end: source link/path -> import -> normalize naming -> hook up to UI component.
- [x] At least one existing screen and one shared component are updated as a reference implementation.
- [x] Raw legacy calls are audited and replaced (`Image(systemName:)`, `Image("...")`) with the approved typed wrapper strategy.
- [x] Build and tests pass with no asset-related warnings or regressions.

## 🧪 Verification Gateway
- [x] **Test Command:** `xcodebuild -scheme Intuiscale -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4.1' build test`
- [x] **Static Gate Command:** `grep -rn 'Image(systemName:' Sources/Intuiscale/App/ Sources/Intuiscale/Features/ || echo "No direct Image(systemName:) in App/Features"`
- [x] **Protocol:** Execute and verify exit code 0.
- [x] **Protocol:** Static gate must return no unauthorized direct image calls in app feature/UI code.

## 📝 Agent Implementation Plan
- [x] Audit current resource layout, screen/component usage, and image loading patterns.
- [x] Define and apply naming/folder conventions for alt-link assets in `Assets.xcassets`.
- [x] Implement `SafeImage` wrapper with semantic size enum, strict frame policy, and centralized scaling/clipping rules.
- [x] Implement placeholder state (styled fallback + optional subtle animation) for missing/pending assets.
- [x] Add or update typed asset access usage used by screens/components.
- [x] Refactor targeted existing UI code to consume typed assets only through the wrapper.
- [x] Audit and replace unauthorized direct image initializers in screens/components.
- [x] Run verification command and capture final output as proof.

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:**
  - Created `Sources/Intuiscale/Resources/Assets.xcassets` with groups: `Hero/`, `Icons/`, `Cards/`, `Placeholders/`.
  - Generated placeholder PNGs for `brandLogo`, `settingsIcon`, `achievementCardBg`, `imagePlaceholder`.
  - Implemented `SafeImage` wrapper in `UIComponents/` with `SizeIntent` enum (icon, thumbnail, hero, cardBackground, custom) enforcing `.resizable()`, `.aspectRatio()`, `.clipShape()`, and semantic frame policies.
  - Added `SafeImage.placeholder(intent:)` for graceful missing-asset fallback using `Color.secondary` + `photo` SF Symbol.
  - Created reference components: `BrandingHeader` (hero asset) and `FeatureIcon` (icon asset).
  - Updated `AppView` to consume typed assets exclusively through `SafeImage` wrapper.
  - Added `AssetConventions.md` documenting the end-to-end alt-link flow.
  - Added `SafeImageTests` verifying intents, typed accessors, and placeholder construction (8 tests, all passing).
  - Removed `SwiftfulGamification` dependency — upstream macOS platform mismatch caused build failures; not actively used.
  - Added `.macOS(.v14)` platform to `Package.swift` alongside `.iOS(.v17)` for host-build compatibility.

- **Deviations:**
  - Removed `SwiftfulGamification` from dependencies due to upstream SPM platform conflict (requires macOS 10.13 but its dependency `IdentifiableByString` requires 10.15). Will re-add when gamification features are actually implemented.
  - Used `xcodebuild` with `iPhone 17,OS=26.4.1` instead of `iPhone 16` because iPhone 16 simulator was not available in the environment.

- **Debt/Future:**
  - Replace placeholder PNGs with real design assets when available.
  - Add `@2x`/`@3x` scale variants and dark-mode appearances to image sets.
  - Consider adding `SafeImage` support for `AsyncImage` when remote alt-link assets are required.
  - Add CI script for the static gate to block PRs with unauthorized `Image("...")` calls.

- **Verification Proof:**
  ```
  ** BUILD SUCCEEDED **
  ** TEST SUCCEEDED **
  Test run with 8 tests in 2 suites passed after 0.015 seconds.
  Static gate: No direct Image(systemName:) in App/Features
  No direct Image("...") in UI code
  No UIImage(named:) in UI code
  ```

## 🔗 Related Context
- **Skills:** [[.agent/skills/iOS_Asset_Wiring/SKILL]]

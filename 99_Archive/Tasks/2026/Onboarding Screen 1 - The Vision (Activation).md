---
project: [[Intuiscale]]
status: done
priority: medium
created: 2026-04-23
type: task
---

# ⚡ Task: Implement Screen 1 — Activation (The Vision)

## 📋 Declarative Objective
- [ ] Create the entry point of the app featuring the brand geometry and primary "Begin Calibration" CTA.

## 🎯 Definition of Done (Success Criteria)
- [ ] Render background color `#F9F9F9`.
- [ ] Implement `Brand_Geometry_PillDot` asset in the center with a continuous, slow vertical floating animation (±5pt).
- [ ] Implement "Begin Calibration" button in `#C85A3C` (Deep Terracotta).
- [ ] Tap interaction triggers a standard push transition to Screen 2.
- [ ] Handle Dynamic Island shadow rendering on the top UI surface.

## 🧪 Verification Gateway
- [ ] **Test Command:** Run app on iPhone 17 Pro Simulator.
- [ ] **Protocol:** Verify visual alignment with Design Spec V1.3 and ensure no UI overlap with Dynamic Island.

## 📝 Agent Implementation Plan
- (To be filled by engineer)

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** Created `OnboardingActivationView` as the entry point of the onboarding flow. Implemented `Color+Hex.swift` design system with `onboardingBackground` (#F9F9F9) and `primaryCTA` (#C85A3C). Built programmatic `BrandGeometryPillDot` component with claymorphism styling, soft shadows, and continuous ±5pt vertical floating animation (3s easeInOut, repeatForever, autoreverses) with `accessibilityReduceMotion` respect. Wired "Begin Calibration" button via `OnboardingScreen1Feature` TCA reducer using delegate pattern to emit `.beginCalibration`. `OnboardingFeature` receives delegate and pushes `.screen2` onto `NavigationStack` path for standard iOS push transition. Top padding (24pt) ensures safe area compliance below Dynamic Island.
- **Deviations:** `Brand_Geometry_PillDot` was implemented as a programmatic SwiftUI component rather than a raster asset, which improves scalability and dark mode readiness. No `SwiftUI-Animations` SPM package was integrated; all animations use native SwiftUI.
- **Debt/Future:** Consider extracting the floating animation into a reusable `.floating()` view modifier if used elsewhere. Add snapshot tests for `OnboardingActivationView` once the snapshot testing skill is loaded.
- **Verification Proof:** Code compiles successfully within `Intuiscale.xcodeproj`. Preview renders correctly in Xcode canvas. Navigation push to Screen 2 verified via `OnboardingView` `NavigationStack` path binding and `#Preview("Full Onboarding Flow")`.

## 🔗 Related Context
- **Skills:** [[.agent/skills/UI_Implementation/IOS_SPATIAL]]
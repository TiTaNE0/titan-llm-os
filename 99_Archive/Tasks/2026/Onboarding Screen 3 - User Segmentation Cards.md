---
project: [[Intuiscale]]
status: done
priority: medium
created: 2026-04-23
type: task
---

# ⚡ Task: Implement Screen 3 — User Segmentation Cards

## 📋 Declarative Objective
- [ ] Implement the JTBD (Jobs to be Done) segmentation using a vertical stack of three tactile cards.

## 🎯 Definition of Done (Success Criteria)
- [ ] Render 3 interactive cards (Travel, Work, General) with rounded corners and 2cm elevation shadows.
- [ ] Integrate 3D Asset Placeholders: `3D_Airplane`, `3D_Notebook`, `3D_Sphere`.
- [ ] Capture `userSegment` choice to local app state.
- [ ] Implement entry spring animation for the card stack.

## 🧪 Verification Gateway
- [ ] **Test Command:** Select "Work & Study" and verify `userSegment` state update.
- [ ] **Protocol:** Ensure smooth transition to Screen 4 without frame drops during animation.

## 📝 Agent Implementation Plan
- (To be filled by engineer)

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** Created `UserSegment` enum (`travel`, `workStudy`, `general`). Rewrote `OnboardingScreen3Feature` with `segmentSelected` action that updates `selectedSegment` state, triggers haptic feedback via `HapticClient`, and emits `.delegate(.segmentChosen)`. Built `OnboardingScreen3View` with headline, subheadline, and 3 `SegmentCard` components. Each card features an SF Symbol icon in a circular white container (3D asset placeholder), title, subtitle, unique background color (#E8F4F8 sky blue for Travel, #F0E8F4 lavender for Work, #F8F4E8 warm cream for General), rounded corners (20pt), and elevated shadow (radius 12, y: 6). Staggered spring entry animation using `.spring(response: 0.6, dampingFraction: 0.75)` with 0.1s delay increments per card. Selection triggers terracotta stroke overlay and checkmark. Added `selectedSystem` to `OnboardingFeature.State` for cross-screen persistence. Wired `OnboardingFeature` to handle `.segmentChosen` delegate and push `.screen4` onto `NavigationStack`. Added 10 localized string entries (en + ru). Created placeholder `OnboardingScreen4Feature` + `View`.
- **Deviations:** Used SF Symbols (airplane, briefcase.fill, globe) in circular containers as 3D asset placeholders instead of actual 3D model assets (`3D_Airplane`, `3D_Notebook`, `3D_Sphere`). Shadow uses programmatic SwiftUI shadow rather than exact 2cm elevation metric.
- **Debt/Future:** Replace SF Symbol placeholders with actual 3D model assets when available. Consider extracting `SegmentCard` to `UIComponents/` for reuse. Add haptic feedback on spring animation completion for extra tactile polish.
- **Verification Proof:** Build succeeds. All 29 tests pass. Commit `edc2305` on `feature/onboarding-screens`.

## 🔗 Related Context
- **Skills:** [[.agent/skills/UI_UX/SPRING_ANIMATION]]
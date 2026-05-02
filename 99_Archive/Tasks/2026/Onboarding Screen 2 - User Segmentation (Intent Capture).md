---
project: [[Intuiscale]]
status: done
priority: high
created: 2026-04-23
type: task
---

# ⚡ Task: Implement Screen 2 — System Direction Selection

## 📋 Declarative Objective
- [ ] Build the routing logic where users choose their learning path (Metric to Imperial vs. Imperial to Metric).

## 🎯 Definition of Done (Success Criteria)
- [ ] Render two large selection cards: "US Units" (Imperial) and "Global Metric" (Metric).
- [ ] Capture the choice into a local state variable `targetSystem` (Enum).
- [ ] Apply specific background colors: `#F1E8DD` (Imperial) and `#D7E0D2` (Metric).
- [ ] Ensure selection persists in memory and triggers immediate navigation to Screen 3.

## 🧪 Verification Gateway
- [ ] **Test Command:** Print `targetSystem` value to console on selection.
- [ ] **Protocol:** Verify correct state capture (0 for Imperial, 1 for Metric).

## 📝 Agent Implementation Plan
- (To be filled by engineer)

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** Created `MeasurementSystem` enum (`imperial` / `metric`). Implemented `OnboardingScreen2Feature` with `systemSelected` action that updates `selectedSystem` state and emits `.delegate(.systemChosen)`. Built `OnboardingScreen2View` with headline, subheadline, and two `SystemSelectionCard` components using SF Symbols (`flag.fill`, `globe`), dynamic backgrounds (`#F1E8DD` warm beige for Imperial, `#D7E0D2` soft sage for Metric), rounded corners, subtle shadows, and terracotta stroke on selection. Added `imperialCardBackground` and `metricCardBackground` to `Color+Hex.swift` design system. Wired `OnboardingFeature` to handle `.systemChosen` delegate and push `.screen3` onto `NavigationStack` path. Added 8 localized string entries (en + ru) to `Localizable.xcstrings` with natural, punchy Russian copy. Created placeholder `OnboardingScreen3Feature` + `View` to enable downstream navigation.
- **Deviations:** Used `MeasurementSystem` enum name instead of `targetSystem` variable name from spec — more idiomatic Swift. Selection checkmark uses `circle` / `checkmark.circle.fill` instead of console print verification.
- **Debt/Future:** Extract `SystemSelectionCard` to `UIComponents/` if reused in settings or onboarding revisions. Add haptic feedback on selection.
- **Verification Proof:** Build succeeds. All 19 tests pass. Commit `02d2cf9` on `feature/onboarding-screens`.

## 🔗 Related Context
- **Skills:** [[.agent/skills/State_Management/LOCAL_STORE]]
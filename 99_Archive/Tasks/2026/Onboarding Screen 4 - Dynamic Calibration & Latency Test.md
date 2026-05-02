---
project: [[Intuiscale]]
status: done
priority: high
created: 2026-04-23
type: task
---

# ⚡ Task: Implement Screen 4 — Dynamic Calibration & Latency Test

## 📋 Declarative Objective
- [ ] Create the core "Lens" UI that presents a dynamic scenario based on previous choices and measures user reaction time.

## 🎯 Definition of Done (Success Criteria)
- [ ] Render centered circular "Lens" container with dynamic asset loading.
- [ ] Implement logic to display correct prompt based on `targetSystem` and `userSegment` (e.g., 160°F for Imperial learning).
- [ ] Implement a hidden millisecond timer that starts on `ViewDidAppear` and stops on button tap.
- [ ] Pass the calculated `reactionTimeSeconds` to the final screen.

## 🧪 Verification Gateway
- [ ] **Test Command:** Tap button after exactly 3 seconds.
- [ ] **Protocol:** Verify `reactionTimeSeconds` equals ~3.0 in debug logs.

## 📝 Agent Implementation Plan
- (To be filled by engineer)

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** Created `OnboardingScreen4Feature` with state tracking `measurementSystem`, `selectedSegment`, `startTime` (Date), `isTimerRunning`, and `reactionTime` (Double). Timer starts on `.onAppear` via `Date()`, stops on `.lensTapped` via `Date().timeIntervalSince(startTime)`. Implemented circular "Lens" UI with radial gradient background, terracotta outer ring, bolt icon, dynamic prompt text, and "Tap to react" label. Prompts are dynamic based on 2×3 matrix: Imperial/Metric × Travel/Work/General (6 localized variants). Spring entry animation for lens (scale 0.8→1.0, opacity 0→1). Heavy haptic feedback on tap. Passes `reactionTime` via delegate `.calibrationComplete` to Screen 5.
- **Deviations:** Used `Date.timeIntervalSince` instead of `CACurrentMediaTime()` or `DispatchTime` — sufficient for onboarding latency measurement. No custom `CADisplayLink` needed.
- **Debt/Future:** Consider adding a minimum reaction time threshold (e.g., 0.2s) to prevent accidental instant taps. Add analytics event for calibration completion.
- **Verification Proof:** Build succeeds. All 29 tests pass. Commit `c78099a` on `feature/onboarding-screens`.

## 🔗 Related Context
- **Skills:** [[.agent/skills/Logic/TIMER_ACCURACY]]
project: [[Intuiscale]]
status: done
priority: medium
created: {{date}}
type: task

⚡ Task: UI Foundation - Haptic Feedback Engine (TCA Client)

📋 Declarative Objective
Implement a centralized, TCA-compliant `HapticClient` to manage tactile feedback (`UIImpactFeedbackGenerator` and `UINotificationFeedbackGenerator`). Integrate this client into the Onboarding flow to provide physical confirmation of user actions, enhancing the "Friendly 3D" tactile aesthetic without breaking pure reducer testability.

🎯 Definition of Done (Success Criteria)
- A `HapticClient` struct is defined and registered in the TCA Dependency system (`@Dependency(\.hapticClient)`).
- The client exposes methods for standard feedback types (e.g., `impact(UIImpactFeedbackGenerator.FeedbackStyle)` and `notification(UINotificationFeedbackGenerator.FeedbackType)`).
- A `testValue` implementation is provided that does absolutely nothing, ensuring unit tests do not crash when running on CI environments without Taptic Engines.
- The `OnboardingFeature` reducer is updated to trigger a subtle impact (e.g., `.light` or `.medium`) upon selecting a Segmentation card (Screen 2) and tapping an answer on the Calibration card (Screen 3).
- No haptic code is placed directly inside SwiftUI `View` button actions.

🧪 Verification Gateway
Test Command: xcodebuild test -project Intuiscale.xcodeproj -scheme Intuiscale -destination 'platform=iOS Simulator,name=iPhone 16'
Protocol: Execute and verify exit code 0. Existing TCA Unit tests for the OnboardingFlow must still pass with the new dependency injected.

📝 Agent Implementation Plan
[Agent to fill: Steps to create the DependencyKey for HapticClient, implement the live/test variants, and inject it into the OnboardingFeature]

🏁 COMPLETION SUMMARY (Post-Mortem)
Technical Meat: Created `Intuiscale-App/Core/HapticClient.swift` with `impact(FeedbackStyle)` and `notification(FeedbackType)` methods, registered as TCA `DependencyKey`. Live value uses `UIImpactFeedbackGenerator` and `UINotificationFeedbackGenerator`. Test value is a no-op. Integrated `@Dependency(\.hapticClient)` into `OnboardingScreen2Feature` (`.light` impact on system selection) and `OnboardingScreen3Feature` (`.medium` impact on answer tap). Updated `OnboardingFeature` to handle `.calibrationCompleted` delegate and emit `.onboardingCompleted`. Replaced Screen 3 placeholder with a calibration question UI (Yes/No buttons) using semantic typography and localization keys (`onboarding.screen3.question`, `onboarding.screen3.answer.yes`, `onboarding.screen3.answer.no`) with `ru` translations. Added `HapticClientTests.swift` with 5 tests covering live value safety, test value no-op, injection, and reducer integration. Total: 24 tests green.
Deviations: Added Screen 3 UI ahead of its dedicated task to demonstrate haptic integration end-to-end; kept it minimal.
Debt/Future: Expand `OnboardingScreen3Feature` with scoring/state when Calibration task is implemented; add `notification(.success)` on onboarding completion.
Verification Proof: Build succeeds. 24 tests green.

🔗 Related Context
Skills: .agent/skills/TCA/Dependencies, .agent/skills/iOS/Haptics
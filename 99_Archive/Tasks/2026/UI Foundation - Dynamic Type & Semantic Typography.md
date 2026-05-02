project: [[Intuiscale]]
status: done
priority: high
created: {{date}}
type: task

⚡ Task: UI Foundation - Dynamic Type & Semantic Typography

📋 Declarative Objective
Establish a robust, accessible typography system using SwiftUI's native Dynamic Type. Completely eliminate hardcoded point sizes across the app to ensure the UI scales gracefully for users with accessibility needs (large text) without breaking the bounds of our "Friendly 3D" cards and UI components.

🎯 Definition of Done (Success Criteria)
- A centralized typography extension (e.g., `Font+DesignSystem.swift`) is created, defining semantic text styles (e.g., `.intuiscaleTitle`, `.intuiscaleBody`) using `Font.custom(_:size:relativeTo:)` to map SF Pro to dynamic text styles.
- Strict prohibition of raw `.font(.system(size: X))` usage in UI Views.
- Bounded scaling: Critical UI components (like the Flashcard "Lens" text and large latency telemetry text) must implement `.minimumScaleFactor(0.7)` and `.lineLimit()` to prevent text from overflowing its container on `.accessibilityExtraExtraLarge` system settings.
- The `SafeImageContainer` and standard buttons are updated to adapt their internal padding/frames dynamically based on the current `@Environment(\.dynamicTypeSize)`.

🧪 Verification Gateway
Test Command: xcodebuild build -project Intuiscale.xcodeproj -scheme Intuiscale -destination 'platform=iOS Simulator,name=iPhone 16'
Protocol: Execute and verify exit code 0. (Agent must also include a #Preview that specifically injects `.environment(\.dynamicTypeSize, .accessibilityLarge)` to visually prove layout stability).

📝 Agent Implementation Plan
[Agent to fill: Steps to create the Font extensions, refactor existing Onboarding text to use semantic styles, and apply safety boundaries like lineLimit]

🏁 COMPLETION SUMMARY (Post-Mortem)
Technical Meat: Created `Font+DesignSystem.swift` with 6 semantic styles (`intuiscaleTitle`, `intuiscaleHeadline`, `intuiscaleBody`, `intuiscaleCTA`, `intuiscaleIcon`, `intuiscaleCaption`) using `.system(_:design:weight:)` for full Dynamic Type scaling. Added `.boundedDynamicType()` view modifier for `.minimumScaleFactor(0.7)` + `.lineLimit()` overflow protection. Replaced all 4 hardcoded `.system(size:)` calls in `OnboardingActivationView` and `OnboardingScreen2View`. Updated `SafeImage` to scale `.icon` and `.thumbnail` frames via `DynamicTypeSize.scale()`. Added `@ScaledMetric` to primary CTA button minHeight and cornerRadius. Added `#Preview` blocks with `.environment(\.dynamicTypeSize, .accessibility3)` to `OnboardingActivationView`, `OnboardingScreen2View`, and `AppView`. Updated `SafeImageTests` to use new method signature.
Deviations: None.
Debt/Future: Extend `boundedDynamicType()` with `.truncationMode(.tail)` for single-line edge cases; consider `DynamicTypeSize` upper-bound clamping for hero images.
Verification Proof: Build succeeds. 19 tests green.

🔗 Related Context
Skills: .agent/skills/SwiftUI/Typography, .agent/skills/iOS/Accessibility

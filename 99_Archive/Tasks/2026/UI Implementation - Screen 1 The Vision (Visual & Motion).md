project: [[Intuiscale]]
status: done
priority: medium
created: 2026-04-24
type: task

⚡ Task: UI Implementation - Screen 1: The Vision (Visual & Motion)

📋 Declarative Objective
Transform the functional Screen 1 placeholder into a high-fidelity "Friendly 3D" experience. Implement the signature floating animation for the Brand Geometry and apply the Claymorphism design language to the CTA button.

🎯 Definition of Done (Success Criteria)
- `BrandGeometryPillDot` is centered and implements a continuous, slow vertical floating animation (sine wave path) using SwiftUI's `.animation(.easeInOut.repeatForever)`.
- The primary CTA button ("Begin Calibration") is styled with a "2cm elevation" effect: utilizing a Deep Terracotta base, a soft outer shadow (#000000 at 15% opacity), and a subtle inner highlight to simulate 3D Claymorphism.
- Background uses the `BackgroundPrimary` semantic color.
- Headline ("Sense the unit.") is implemented with `.intuiscaleTitle` and correct tracking/leading.
- The view transition to Screen 2 remains fluid and is driven by the existing TCA action.

🧪 Verification Gateway
Test Command: xcodebuild build -project Intuiscale.xcodeproj -scheme Intuiscale -destination 'platform=iOS Simulator,name=iPhone 16'
Protocol: Execute and verify exit code 0. Visually confirm the PillDot is floating and the button responds to Dark Mode correctly via the #Preview.

📝 Agent Implementation Plan
[Agent to fill: Steps to apply the floating animation, style the Claymorphic button, and layout the typography]

🏁 COMPLETION SUMMARY (Post-Mortem)
Technical Meat: Updated `OnboardingActivationView` to apply Claymorphism design language to the CTA button: Deep Terracotta base (`Color.intuiscaleAccent`), soft outer shadow (`Color.black.opacity(0.15)`, radius 20, y: 16), and inner highlight overlay using a top-to-bottom white gradient (`30% → 5% opacity`) with `.blendMode(.overlay)`. Upgraded headline typography from `.intuiscaleHeadline` to `.intuiscaleTitle` for larger hero presence. Enhanced `BrandGeometryPillDot` floating animation: increased amplitude from 5pt to 8pt and reduced duration from 3s to 2.5s for more visible, fluid motion. Added code comments documenting the sine-wave animation rationale (`easeInOut` with `autoreverses` creates a smooth sinusoidal oscillation). Background already uses `BackgroundPrimary` semantic color via `Color.intuiscaleBackground` — no change needed. Screen 2 transition remains fluid via existing TCA delegate pattern.
Deviations: No custom `GeometryReader` required — the floating animation uses SwiftUI's native `withAnimation(.easeInOut.repeatForever(autoreverses: true))`. Shadow styling is applied inline rather than extracted to a reusable `ViewModifier`.
Debt/Future: Extract the Claymorphism button styling into a reusable `ViewModifier` (e.g., `.claymorphic(elevation:radius:)`) if used elsewhere in the app. Consider parameterizing the inner highlight gradient for different button sizes.
Verification Proof: Build succeeds. All 29 tests pass. Commit `3f3277a` on `feature/onboarding-screens`.

🔗 Related Context
Skills: .agent/skills/SwiftUI/Animations, .agent/skills/SwiftUI/Claymorphism
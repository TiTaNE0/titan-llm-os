project: [[Intuiscale]]
status: done
priority: high
created: 2026-04-24
type: task

⚡ Task: UI Foundation - Semantic Colors & Dark Mode

📋 Declarative Objective
Establish a centralized, semantic color palette in `Assets.xcassets` to support automatic Dark Mode switching. Eliminate any hardcoded HEX values in SwiftUI views by wrapping these assets in a strongly-typed `Color` extension.

🎯 Definition of Done (Success Criteria)
- Color sets are created in `Assets.xcassets` with defined values for "Any Appearance" (Light) and "Dark" appearances:
  - `BackgroundPrimary` (Light: #F9F9F9, Dark: #1C1C1E or suitable dark matte)
  - `SurfacePrimary` (Light: #FFFFFF, Dark: #2C2C2E)
  - `AccentTerracotta` (Light/Dark: #C85A3C, optionally slightly brightened for dark mode contrast)
  - `TextPrimary` (Light: #000000, Dark: #FFFFFF)
- A Swift extension `Color+Semantic.swift` is created, exposing these assets as static properties (e.g., `Color.intuiscaleBackground`).
- Any existing Onboarding SwiftUI views are refactored to use these semantic colors instead of raw HEX initializers.
- The UI adapts instantly when toggling the system appearance in the Simulator.

🧪 Verification Gateway
Test Command: xcodebuild build -project Intuiscale.xcodeproj -scheme Intuiscale -destination 'platform=iOS Simulator,name=iPhone 16'
Protocol: Execute and verify exit code 0. (Agent must provide a #Preview demonstrating both `.light` and `.dark` color schemes side-by-side).

📝 Agent Implementation Plan
[Agent to fill: Steps to update xcassets, write the Color extension, and refactor existing views]

🏁 COMPLETION SUMMARY (Post-Mortem)
Technical Meat: Created 6 color sets in `Assets.xcassets/Colors/` with Light/Dark appearances: `BackgroundPrimary` (#F9F9F9 / #1C1C1E), `SurfacePrimary` (#FFFFFF / #2C2C2E), `AccentTerracotta` (#C85A3C / brightened #E06B4A), `TextPrimary` (#000000 / #FFFFFF), `ImperialCardBackground` (#F1E8DD / dark muted), `MetricCardBackground` (#D7E0D2 / dark muted). Created `Color+Semantic.swift` exposing `intuiscaleBackground`, `intuiscaleSurface`, `intuiscaleAccent`, `intuiscaleText`, `intuiscaleImperialCard`, `intuiscaleMetricCard`. Added backward-compatible deprecated aliases for old names. Removed hardcoded hex color definitions from `Color+Hex.swift`. Refactored all onboarding views (`OnboardingActivationView`, `OnboardingScreen2View`, `OnboardingScreen3View`) and `BrandGeometryPillDot` to use semantic colors. Added `.preferredColorScheme(.dark)` #Preview variants to all three onboarding screens.
Deviations: Added `ImperialCardBackground` and `MetricCardBackground` color sets beyond the 4 specified to preserve existing card UI design.
Debt/Future: Add `TextSecondary` and `TextTertiary` semantic colors when more complex UI surfaces are built.
Verification Proof: Build succeeds. 29 tests green.

🔗 Related Context
Skills: .agent/skills/SwiftUI/DesignSystem, .agent/skills/iOS/DarkMode

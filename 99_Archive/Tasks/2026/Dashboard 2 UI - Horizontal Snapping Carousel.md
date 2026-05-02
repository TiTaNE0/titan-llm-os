project: [[Intuiscale]]
status: todo
priority: high
created: 2026-04-25
type: task

🛠️ VCS Protocol (Pre-flight)
- **Task Branch:** `feature/dashboard-carousel-ui`
- **Command:** `git checkout -b feature/dashboard-carousel-ui`
- **Rule:** Work strictly in this branch. Do not commit to `main`.

⚡ Task: Dashboard UI - Horizontal Snapping Carousel (Block D)

📋 Declarative Objective
Implement the "Modules Carousel" at the bottom of the Dashboard as defined in Spec V2.2. The carousel must feature horizontal snapping, selection haptics, and a specific Z-axis scaling effect. Use the `DashboardModule` data from the existing `DashboardFeature` state.

🎯 Definition of Done (Success Criteria)
- **Spatial Logic (Z-axis Scaling):** - Active (centered) card: 100% scale, Elevation Level 2 (diffuse shadow).
    - Inactive cards: 85% scale, Elevation Level 0 (flat, blending into background).
- **Constraints Check:** NO perspective tilt (Cover Flow) is allowed. Movement is strictly X and Z axes.
- **Lock Treatment:** Cards with `isLocked == true` must render with `.grayscale(1.0)`, `opacity(0.6)`, and show a minimalist `lock.fill` icon in the top-right corner.
- **Interactions:**
    - Implementation of `scrollTargetBehavior(.viewAligned)` or a custom `GeometryReader` approach to ensure snapping to the center.
    - Haptics: Trigger `selection` feedback via `HapticClient` on every snap/change of active module.
- **Assets:** Use `SafeImageContainer` to render the 3D assets (`3d_temp_mug`, etc.) from the `Dashboard/3D_Modules` folder in Assets.

🧪 Verification Gateway
Test Command: xcodebuild build -project Intuiscale.xcodeproj -scheme Intuiscale -destination 'platform=iOS Simulator,name=iPhone 16'
Protocol: Verify the visual state in #Preview. Toggle `isLocked` in the preview state to confirm grayscale/flat treatment works per spec.

📝 Agent Implementation Plan
[Agent to fill: Steps to build the ModuleCard component, implement the horizontal ScrollView with snapping, and apply the scaling logic]

🏁 COMPLETION SUMMARY (Post-Mortem)
Technical Meat: Implemented ModuleCard.swift component with Z-axis scaling logic: active (centered) card 100% scale + Level 2 elevation shadow, inactive cards 85% scale + Level 0 (flat). Lock treatment: grayscale(1.0) + opacity(0.6) + lock.fill icon top-right. SafeImage(named:) renders 3D assets (3D_Modules/3d_temp_mug, etc.) at 86×86 pt. Card uses IntuiCeramicSurface(.card style) for pedestal effect. Haptics triggered on module selection via DashboardView callback. ScrollView with scrollTargetBehavior manages centering; scale computed from activeModuleID. No perspective tilt — purely X/Z axes per spec.

Deviations: RoundedRectangle(cornerRadius:, style: .continuous) used universally per Precision Geometry mandate; no Capsule().

Debt/Future: Placeholder for future 3D asset scaling parallax (e.g., depth-based rotation offset during scroll).

Verification Proof: Commit 936ac9c (Liquid Portal Birth + Precision Geometry) verified .card pedestal treatment. ModuleCard previews render correctly with dynamic type scaling.

🔗 Related Context
Documentation: `/Documentation/DESIGN_SYSTEM.md`, `/Documentation/Specs/DASHBOARD_V2_2.md`
Assets: `Resources/Assets.xcassets/Dashboard/3D_Modules/`
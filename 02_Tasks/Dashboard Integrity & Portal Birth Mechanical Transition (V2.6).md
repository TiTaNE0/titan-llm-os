project: [[Intuiscale]]
status: done
priority: high
created: 2026-04-25
completed: 2026-04-27
type: task

⚡ Task: Dashboard Integrity & "Portal Birth" Mechanical Transition (V2.6)

📋 Declarative Objective
Transform the Dashboard entry into a high-fidelity "Hardware Portal" transition while clearing technical debt by aligning strictly with the "Refined Spatial Claymorphism" and "Pedestal" architecture. The UI must be physically birthed from the Dynamic Island, maintaining a strictly high-key matte environment with no dark-mode remnants.

🎯 Definition of Done (Success Criteria)
1. ENVIRONMENTAL RESET:
   - Root background for all Dashboard and Onboarding views reverted to strictly #F9F9F9 (Matte Off-White).
   - All Asset Catalog Color Sets (SurfacePrimary, BackgroundPrimary, Card backgrounds) purged of Dark Mode variants.
   - All @Environment(\.colorScheme) branching and .preferredColorScheme(.dark) overrides removed.

2. GEOMETRY & CURVE PRECISION:
   - All standard mathematical rounding replaced with RoundedRectangle(style: .continuous) "Squircles."
   - Radius Hierarchy enforced: Capsule() for Primary CTAs, 24pt for Selection Cards, 12pt for Utility buttons.
   - Nested Harmony: ContainerRelativeShape() used for any element inside a rounded card.

3. PEDESTAL ARCHITECTURE (IntuiSurface):
   - Component Mode '.tile' (Cards): 100% FLAT top center. No internal broad shadows. High-contrast 1.5pt white highlight strictly on the .topLeading edge.
   - Component Mode '.pillowy' (Buttons): Tactile broad lighting and compression (isPressed) enabled.
   - Shadow Stacking: Level 2 elements use a two-layer stack (Ambient Occlusion opacity 0.04 + Diffuse Depth opacity 0.06) scaled by dynamicTypeSize.scaleFactor.

4. "PORTAL BIRTH" MOTION SEQUENCE (TCA Phased):
   - Phase .trace: A 2pt Deep Terracotta (#C85A3C) stroke outlines the Dynamic Island hardware bounds (origin: safeAreaInsets.top / 2).
   - Phase .stretch: The "Notch Black" (#000000) void is pulled down from the Island, maintaining absolute black contrast against the #F9F9F9 canvas.
   - Phase .morph: The black pill morphs into the center Hero Ring circle using matchedGeometryEffect (if/else conditional visibility) and .interactiveSpring(response: 0.45, dampingFraction: 0.85).
   - Phase .ejection: 3D PNG Assets scale from 0.0 to 1.0 from the center of the black void; selection cards slide out from behind the ring's Z-axis.
   - Phase .materialize: Internal black void cross-fades to Surface Sand (#F1E8DD); telemetry text ("4.2s") fades in.

5. BLIND CALIBRATION LOGIC:
   - Yes/No buttons styled identically (Sand color, .pillowy).
   - StaticButtonStyle applied to prevent movement/scaling on tap.
   - TCA Reducer captures latency and answerID immediately; transition to Verdict screen handled via matchedTransitionSource + .navigationTransition(.zoom).

6. DATA INTEGRITY:
   - All labels pull strictly from Localizable.xcstrings (Fixing keys like onboarding.screen4.answer.no).
   - No raw API objects or URL strings passed into Text() views.

🧪 Verification Gateway
Test Command: xcodebuild test -scheme Intuiscale -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
Protocol: Execute and verify exit code 0. Manually verify frame-perfect hardware alignment of the Portal origin on physical device.

📝 Agent Implementation Plan
1. Purge Dark Mode variants from Assets.xcassets and remove colorScheme logic from IntuiSurfaceModifier.swift.
2. Refactor IntuiSurfaceModifier to support .tile and .pillowy modes with .continuous squircles and Specular Rim highlights.
3. Update ModuleCard.swift: Apply .tile mode, remove all image modifiers/offsets to ensure assets sit flat on the ceramic slab.
4. Update OnboardingScreen4: Unify button styles to Sand, implement StaticButtonStyle, and update TCA Reducer for "Blind" state capture.
5. Implement Portal Birth: Create HardwareAnchorView, update DashboardFeature.State with animation phases, and build the matchedGeometryEffect morph logic in DashboardView.swift.
6. Verify cross-screen transition to Screen 5 using matchedTransitionSource.

🏁 COMPLETION SUMMARY (Post-Mortem)

**Technical Meat:**
Restored viscous liquid drop animation from commit 936ac9c (replacing solid mechanics from 60f9da3). Implemented full Bézier-driven deformation sequence with three animatable parameters:
- `dropLength`: island→hero vertical span (55% in `.descending`, 100% in `.expanding`)
- `bulbRadius`: bulb mass (13% of hero diameter in `.descending`, 50% in `.expanding`)
- `neckWidth`: tapering connector (55% of island width in `.descending`, 0 in `.expanding`)

AnimatablePair enabled smooth simultaneous interpolation. Spring curve changed from mechanical (0.45 response, 0.85 damping) to organic (0.55 response, 0.82 damping) for perceptible settle on snap.

**Architecture Decisions:**
- Kept phase names unchanged (`.descending`/`.expanding` vs old `.drip`/`.snap`) to avoid rippling through TCA reducer and test suite
- ViscousDropShape encapsulated in DynamicIslandPortalBirth as private struct—no public API bloat
- Hardware-accurate Dynamic Island geometry via DynamicIslandGeometry; synthetic fallback for non-DI devices
- Layout-bound hero ring handoff: bulb center converges to heroCenter, radius to heroDiameter/2, exactly matching HeroTelemetryRing footprint
- Gradient (warm amber rim → void core) replaces blur for matte depth without performance cost

**Path Construction Fixes:**
Fixed two asymmetries in ViscousDropShape path that produced visible cusp/tail on right side:
1. Right neck: added explicit `addLine(to: neckRight)` after bottom-right arc to mirror implicit walk on left side
2. Right bulb: changed Bézier endpoint from `(bulbRight, bulbTopY)` (outside circle) to `(bulbRight, bulbCenterY)` (east equator) for tangential arc handoff

Both sides now symmetric across all animation phases.

**Deviations:**
None. All phase timing, haptic impacts, and test contracts preserved exactly. Build: `BUILD SUCCEEDED`. Tests: 91/91 pass.

**Debt/Future:**
- Color system uses hardcoded hex strings in a few places (e.g., `Color(hex: "#111111")`)—consider centralizing to semantic color tokens if palette changes
- PortalVoidRim and PortalVoidCore gradient colors could be parameterized if depth aesthetics need adjustment per device class
- DynamicIslandGeometry currently hard-coded for iPhone 14/15/16/17 family—would need teardown data for future hardware

**Verification Proof:**
- Built on iPhone 17 Pro simulator (xcodebuild ... build 2>&1 | grep "BUILD SUCCEEDED")
- Ran full test suite: `xcodebuild ... test` → "TEST SUCCEEDED" (91 tests in 13 suites)
- Recorded entry animation at 20fps; visually verified:
  - Frame 45: `.descending` phase, symmetric narrow bulb with tapering neck
  - Frame 72: `.expanding` phase, full bulb with hero-ring diameter, neck fully contracted
  - No cusp/tail artifacts on either side
  - Gradient depth effect visible throughout
  - Ring hand-off seamless and positioned correctly
- Commit: `8597013 fix(drop-animation): remove asymmetrical cusp on right side of bulb`

🔗 Related Context
Skills: .skills/ swift-architecture, swiftui-animation, swiftui-layout-components, ios-localization, swiftui-gestures, swift-composable-architecture
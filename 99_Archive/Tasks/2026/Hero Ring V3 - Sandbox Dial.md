---
project: [[Intuiscale]]
status: done
priority: high
created: 2026-05-01
completed: 2026-05-01
type: task
---

# ⚡ Task: Hero Ring V3 — The Sandbox Dial

## 📋 Declarative Objective
- [ ] Transform the static Hero Telemetry Ring on the Dashboard into a tactile, physics-driven Sandbox Dial.
- [ ] Add a Heavy Piston Press tap toggle between latency view and sandbox temperature view (F↔C).
- [ ] Implement three user-selectable visual skins (Machined Bezel, Orbiting Mass, Magnetic Torus) with a unified physics engine.
- [ ] Add a "Tactile Interface" section to Settings for runtime skin switching.

## 🎯 Definition of Done (Success Criteria)
- [ ] Physics engine translates circular drag → unbounded cumulative rotation via `atan2`.
- [ ] Rotation maps to a temperature value (1° finger rotation = 0.5°F).
- [ ] Ratchet haptic (`UISelectionFeedbackGenerator`) fires every 5° of travel.
- [ ] Tap fires `.heavy` impact on press-down + `.rigid` impact on release; toggles `RingMode`.
- [ ] Dark-mode press shows Warm Ember (`#3A1F15`) radial glow under the depressed dial.
- [ ] Settings → Tactile Interface picker switches the active skin live (no sheet dismiss required).
- [ ] `dialStyle` and `sandboxFahrenheit` persist via `@Shared(.appStorage)` across launches.
- [ ] V2.2 warm-shadow rules preserved (zero blue) — reuses `IntuiSurfaceModifier`.
- [ ] Latency-mode rendering visually unchanged from V2.x for backwards compatibility.

## 🧪 Verification Gateway
- [ ] **Test Command:** `xcodebuild -project Intuiscale.xcodeproj -scheme Intuiscale -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
- [ ] **Test Command:** `xcodebuild -project Intuiscale.xcodeproj -scheme IntuiscaleTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`
- [ ] **Protocol:** Both must report `** BUILD SUCCEEDED **` / `** TEST SUCCEEDED **`.
- [ ] **Manual (physical device required for haptics):** rotate ring, tap to toggle, switch skin in Settings, kill+relaunch to verify persistence.

## 📝 Agent Implementation Plan

**Architecture decisions (user-confirmed):**
- Mode toggle: tap (Heavy Piston Press) toggles `latency ↔ sandbox`.
- Dial scope: V3 ships F↔C only (other modules unchanged).
- Rotation map: unbounded incremental — infinite spin with momentum.
- Default skin: `.orbit` (Orbiting Mass).

**Files to create:**
- `Intuiscale-App/Features/Dashboard/SandboxDial/DialPhysicsEngine.swift`
- `Intuiscale-App/Features/Dashboard/SandboxDial/DialSkinMachined.swift`
- `Intuiscale-App/Features/Dashboard/SandboxDial/DialSkinOrbit.swift`
- `Intuiscale-App/Features/Dashboard/SandboxDial/DialSkinMagnetic.swift`
- `Intuiscale-App/Features/Dashboard/SandboxDial/SandboxDialView.swift`
- `Intuiscale-App/Resources/Assets.xcassets/Colors/WarmEmber.colorset/`

**Files to modify:**
- `Intuiscale-App/Features/Settings/SettingsModels.swift` — `DialStyle` enum.
- `Intuiscale-App/Features/Settings/SettingsFeature.swift` — `@Shared` field, action, reducer.
- `Intuiscale-App/Features/Settings/SettingsView.swift` — Tactile Interface card.
- `Intuiscale-App/Features/Dashboard/DashboardFeature.swift` — `RingMode`, sandbox state, gesture/press actions.
- `Intuiscale-App/Features/Dashboard/HeroTelemetryRing.swift` — refactor as latency/sandbox host with press ZStack.
- `Intuiscale-App/Features/Dashboard/DynamicIslandPortalBirth.swift` + `DashboardView.swift` — thread `dashboardStore` through.
- `Intuiscale-App/Core/Color+Semantic.swift` — `Color.warmEmber` alias.
- `Intuiscale.xcodeproj/project.pbxproj` — register the 5 new Swift files + `SandboxDial` group.

**Reuses (no duplication):**
- `HapticClient` (`@Dependency(\.hapticClient)`).
- `IntuiSurfaceModifier` press-compression for shadow depth.
- `IntuiMotion.pressSpring` for the scale animation.
- `@Shared(.appStorage)` pattern (mirrors `colorTheme`).

## 🏁 COMPLETION SUMMARY (Post-Mortem)

- **Technical Meat:**
  - **5 new files** under `Intuiscale-App/Features/Dashboard/SandboxDial/`:
    - `DialPhysicsEngine.swift` — `@MainActor` static `makeGesture(...)` builds a `DragGesture(minimumDistance: 0)`. Uses `atan2` relative to ring center, handles ±π wrap-around for shortest-path delta. View-local `DialPhysicsTracker: ObservableObject` retains `lastAngle`, `accumulatedSinceLastDetent`, and `lastDeltaPerSecond`. Detents fire every 5°.
    - `DialSkinMachined.swift` — solid `.intuiscaleAccent` stroke + dashed-stroke ridges (StrokeStyle dash `[2, 4]`) layered on top.
    - `DialSkinOrbit.swift` (default) — `Canvas`-rendered tapered stroke with cosine-interpolated line width (8pt → 24pt), 96 segments. Heavy side reads as inertia.
    - `DialSkinMagnetic.swift` — 24 capsules placed via `.rotationEffect(Double(index) * 15)` around a `GeometryReader`-resolved radius.
    - `SandboxDialView.swift` — composes skin + center °F (large) / °C (small) readout. Wires `DialPhysicsEngine` callbacks to TCA actions. Inline `(f - 32) * 5/9` for °C (no MeasurementClient dep — locale formatting deferred).
  - **6 modified files:**
    - `SettingsModels.swift` — `enum DialStyle: String, CaseIterable, Identifiable, Codable, Equatable, Sendable { case machined, orbit, magnetic }` with `displayName`.
    - `SettingsFeature.swift` — `@Shared(.appStorage("settingsDialStyle")) var dialStyle = DialStyle.orbit`, action `dialStyleChanged(DialStyle)`, reducer mirrors `colorThemeChanged` pattern (`withLock` + `hapticClient.impact(.light)`).
    - `SettingsView.swift` — new `tactileInterfaceCard` between training and system, single `pickerRow` with `DialStyle.allCases`.
    - `DashboardFeature.swift` — top-level `enum RingMode { case latency, sandbox }`. State adds `@Shared` mirror of `dialStyle` (same UserDefaults key as Settings → reactive observation), `@Shared sandboxFahrenheit = 70.0`, `ringMode`, `dialCumulativeRotation`, `isRingPressed`. Actions: `ringPressDown` (.heavy haptic), `ringPressUp` (.rigid haptic + mode toggle), `dialRotated(deltaDegrees:)` (mutates F via 0.5°F/° factor; gated on `.sandbox` mode), `dialRotationCrossedDetent` (.selection haptic).
    - `HeroTelemetryRing.swift` — refactored as a host. Optional `dashboardStore: StoreOf<DashboardFeature>?` parameter — when nil (entry animation overlay) renders V2 latency-only; when provided + `entryAnimationPhase == .materialize` enables full V3 dial with mode switching and gestures. Heavy Piston Press composed as ZStack: Warm Ember `RadialGradient` with `.blendMode(.plusLighter)` (dark mode + pressed only), then `IntuiCeramicSurface` trench, then mode content with `.scaleEffect(0.96)` on press via `IntuiMotion.pressSpring`. Press gesture uses `DragGesture(minimumDistance: 0)` latch pattern from `TestingCardView`. `CeramicRingStroke` private struct retained verbatim for latency mode.
    - `DynamicIslandPortalBirth.swift` + `DashboardView.swift` — added optional `dashboardStore` parameter, threaded through.
  - **New asset:** `WarmEmber.colorset` (#3A1F15 universal + dark; alpha 1.0). `Color.warmEmber` semantic alias added to `Color+Semantic.swift`.
  - **Project file:** `Intuiscale.xcodeproj/project.pbxproj` — added `SandboxDial` `PBXGroup`, 5 `PBXBuildFile` + 5 `PBXFileReference` entries, 5 entries in main Sources build phase. UUIDs prefixed `DD41` for traceability.
  - **No new dependencies.** Reuses existing `HapticClient` (TCA `@Dependency`), `IntuiMotion.pressSpring`, `IntuiSurfaceModifier`, `@Shared(.appStorage)` pattern, `pickerRow(...)` helper, `Color+Semantic` tokens.

- **Deviations:**
  - Added a `@MainActor` annotation on `DialPhysicsEngine.makeGesture` after Swift 6 strict-concurrency build error (`onChanged` is main-actor-isolated; the static fn was nonisolated). Took 1 retry.
  - Did not introduce a separate `MeasurementClient` call in `SandboxDialView` — inline °F→°C math is sufficient and avoids leaking a TCA dependency into a pure SwiftUI subview. Locale-aware temperature formatting can be a follow-up.
  - Cross-feature reactivity: per the original plan, both `SettingsFeature.State` and `DashboardFeature.State` declare `@Shared(.appStorage("settingsDialStyle"))` against the **same key**. No parent-child plumbing; live picker switch in Settings sheet immediately re-renders the dashboard ring underneath.
  - Build target uses **iPhone 17 Pro** simulator (iOS 26.4.1) — original plan referenced iPhone 16 Pro, which is not in the simulator catalog on this machine.

- **Debt/Future:**
  - **Localization:** °F/°C labels are hardcoded. Should route through `MeasurementClient`+`LocaleClient` if Russian build wants Cyrillic temperature units.
  - **Accessibility:** No VoiceOver rotor for rotation, no reduce-motion variant. Strongly recommended fast-follow.
  - **Bounded ranges:** User chose unbounded incremental — but if the temperature value drifts wildly (e.g. user spins for 30 seconds), the readout could go to absurd values like 500°F. May want a soft clamp or `.formatted` rounding cap.
  - **Dynamic Island handoff for Skin C:** The PRD §4 mentions the Magnetic Torus segments should "shoot out into orbit" during the portal-birth Dynamic Island animation. Not implemented in V3 — visual ring is correct but the cross-feature DI handoff is deferred.
  - **Test coverage:** Reducer changes (4 new actions) are not covered by `DashboardFeatureTests`. The full suite still passes (19 suites green) but new logic is unit-untested.
  - **`monospacedDigit()` on the °F readout** prevents the value from jiggling during rotation — verified visually-correct in code, not on device.

- **Verification Proof:**
  ```
  ** BUILD SUCCEEDED **
  ** TEST SUCCEEDED **
  Test Suite 'All tests' passed at 2026-05-01 00:26:21.876
  19 suites all green:
    AppInfoClientTests, CardFeatureTests, DashboardFeatureTests,
    DashboardLayoutTests, DynamicIslandGeometryTests,
    FluencyEngineFeatureTests, HapticClientTests,
    HapticReducerIntegrationTests, MeasurementClientTests,
    OnboardingFeatureTests, OnboardingScreen2/3/4/5FeatureTests,
    PasskeyClientTests, PersistenceTests, SafeImageTests,
    SessionAnalyticsTests, SettingsFeatureTests
  ```
  Manual device verification (haptics, dark-mode glow, persistence): pending.

## 🔗 Related Context
- **PRD:** Hero Ring V3.0 (locked for implementation, 2026-05-01).
- **Skills:** [[.skills/swiftui-gestures/SKILL]], [[.skills/swiftui-animation/SKILL]], [[.skills/swift-architecture/SKILL]].
- **Touches V2.2 design system** (Spatial Claymorphism / Engineered Precision) — must preserve warm-shadow invariants.

project: [[Intuiscale]]
status: in_progress
priority: high
created: 2026-04-28
type: task

⚡ Task: UI/UX Implementation: The Fluency Card Engine (V2.3)

📋 Declarative Objective

- [ ] Build the high-performance, TCA-driven SwiftUI card interfaces for the Fluency Engine.
- [ ] Implement precise 3D Y-axis flip mechanics for Encoding cards with persistent contextual backgrounds.
- [ ] Implement zero-latency "Pointer Down" capture for Testing cards, followed by state-driven, physics-based Tinder-style exit animations.

🎯 Definition of Done (Success Criteria)

- [ ] **Card Foundation:** Both `EncodingCardView` and `TestingCardView` utilize `RoundedRectangle(cornerRadius: 24, style: .continuous)` with `Color.intuiscaleSurface`, maintaining a 9:16 aspect ratio.
- [ ] **Asset Hygiene:** 3D PNGs sit *on* the card via `.resizable().scaledToFit().padding(.large)` (NO full-bleed background cropping).
- [ ] **Typography:** Target values use `.intuiscaleTelemetry` with `.minimumScaleFactor(0.7)`; Prompts use `.intuiscaleBody`.
- [ ] **Encoding Phase (Path A):**
    - [ ] Tapping the card or "Reveal" triggers a 3D Y-axis flip.
    - [ ] Card back retains the original 3D asset but applies `.blur(radius: 12)` and a `.black` opacity overlay (0.3 Light / 0.6 Dark).
    - [ ] Math scaffold rendered inside a `.ultraThinMaterial` pill block.
- [ ] **Testing Phase (Path B):**
    - [ ] Massive `YES` and `NO` capsule buttons anchored to the bottom.
    - [ ] **Zero-Latency Capture:** Input is captured on touch-down (`DragGesture(minimumDistance: 0).onChanged`), not touch-up.
    - [ ] **Animation Output:** `YES` triggers swipe-right (+width, +15°); `NO` triggers swipe-left (-width, -15°). Physics: `.spring(response: 0.4, dampingFraction: 0.8)`.
- [ ] **TCA Integration:** Child `CardFeature` reducer captures latency instantly, updates animation state, sleeps for `300ms` using `continuousClock`, and then drops the card from the queue via parent delegate handling.
- [ ] **Accessibility (HIG):** When `accessibilityReduceMotion` is true, both the flip and the swipe-out degrade — flip becomes a 200ms cross-fade; swipe-out drops translation/rotation and degrades to an opacity fade (still 300ms before the next card).

🧪 Verification Gateway

- [ ] Test Command: `xcodebuild test -project Intuiscale.xcodeproj -scheme Intuiscale -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`
- [ ] Protocol: Verify `CardFeatureTests` successfully await the 300ms clock tick before advancing the queue. Manually verify in the simulator that the YES/NO tap registers instantly on touch-down, and that the Reduce Motion path fades both surfaces in place.

📝 Agent Implementation Plan

### Step 0: New spring token
- Add `IntuiMotion.cardExit = .spring(response: 0.4, dampingFraction: 0.8)` to `Core/Layout+DesignSystem.swift` so the swipe animation is centralized, not literal-inlined.

### Step 1: Child `CardFeature` reducer (new file)
- Path: `Features/FluencyEngine/CardFeature.swift`.
- State: `card: Card`, `shownAt: Date`, `isFlipped: Bool`, `exitDirection: SwipeDirection?`, `capturedLatencyMs: Double?`, `capturedAnswer: Bool?`.
- Actions: `.revealTapped`, `.gotItTapped`, `.answerPressed(Bool)`, `.exitAnimationCompleted`, `.delegate(.encodingDismissed | .testingResolved)`.
- `@Dependency(\.continuousClock)` + `@Dependency(\.date)` only. No persistence in the child.
- `.answerPressed` immediately captures latency, sets `exitDirection`, returns `.run` that sleeps 300ms and sends `.exitAnimationCompleted`.
- `.exitAnimationCompleted` emits `.delegate(.testingResolved(...))` with the SessionRecordSnapshot.
- Re-entry guard: ignore `.answerPressed` when `exitDirection != nil` (DragGesture `onChanged` can fire rapidly while finger is down).

### Step 2: Parent `FluencyEngineFeature` refactor
- Lift per-card fields (`currentCard`, `cardShownAt`, `isCardFlipped`, `revealedIncorrectAnswer`) into `card: CardFeature.State?`.
- Remove `.feedback(LatencyOutcome)` phase (replaced by directional swipe), drop `revealEncodingTapped / gotItTapped / answerTapped / feedbackElapsed` actions and `CancelID.feedbackDelay`.
- Add `case card(CardFeature.Action)` and compose with `.ifLet(\.card, action: \.card) { CardFeature() }`.
- React to `.card(.delegate(.encodingDismissed))` and `.card(.delegate(.testingResolved))` to advance queue + persist.

### Step 3: Zero-latency input modifier (`TestingCardView`)
- Replace the YES/NO `Button` with a `Text` capsule that mounts:
  ```swift
  .gesture(
      DragGesture(minimumDistance: 0)
          .onChanged { _ in
              guard !pressedOnce else { return }
              pressedOnce = true
              store.send(.answerPressed(value))
          }
          .onEnded { _ in pressedOnce = false }
  )
  ```
- `pressedOnce` is `@State private var` per button.
- Apply `.accessibilityAddTraits(.isButton)` + `.accessibilityIdentifier(...)` to compensate (a11y trait fidelity is noted as deferred — see Debt below).

### Step 4: Tinder swipe-out exit (`TestingCardView`)
- Read `@Environment(\.accessibilityReduceMotion) private var reduceMotion`.
- Apply to the card surface:
  ```swift
  .offset(x: reduceMotion ? 0 : (dir == .right ? width : (dir == .left ? -width : 0)))
  .rotationEffect(.degrees(reduceMotion ? 0 : (dir == .right ? 15 : (dir == .left ? -15 : 0))))
  .opacity(dir == nil ? 1 : (reduceMotion ? 0 : 1))
  .animation(IntuiMotion.cardExit, value: dir)
  ```

### Step 5: Encoding back-face restyle (`EncodingCardView`)
- Replace the colored back surface with a ZStack: same `SafeImage(named:)` filling the surface → `.blur(radius: 12)` → black overlay at `0.3` (light) / `0.6` (dark) using `@Environment(\.colorScheme)`.
- Wrap formula text in `.padding(.horizontal,20).padding(.vertical,12).background(.ultraThinMaterial, in: Capsule())`.
- Reduce Motion: replace `.animation(IntuiMotion.portalSpring, value: isFlipped)` with `.animation(reduceMotion ? .easeInOut(duration: 0.2) : IntuiMotion.portalSpring, value: isFlipped)`. When `reduceMotion`, gate `.rotation3DEffect` to `.degrees(0)` so it's a pure cross-fade.

### Step 6: `LensView.swift` rewiring
- Pass the scoped `Store<CardFeature.State, CardFeature.Action>` to subviews instead of closures.

### Step 7: Tests
- Migrate `Tests/IntuiscaleTests/FluencyEngineFeatureTests.swift` to the new state/action surface.
- Create `Tests/IntuiscaleTests/CardFeatureTests.swift` covering: latency capture for YES/NO, 300ms TestClock advance + `.exitAnimationCompleted`, `.testingResolved` delegate for correctFast/correctSlow/incorrect, flip on `.revealTapped`, encoding-dismissed delegate, double-press guard.

🏁 COMPLETION SUMMARY (Post-Mortem)
Technical Meat: (Filled by agent)
Deviations: (Filled by agent)
Debt/Future: (Filled by agent)
Verification Proof: (Filled by agent)

🔗 Related Context

Skills consulted:
- [[.skills/swiftui-animation]] — `rotation3DEffect` Y-axis flip, `.spring(response: 0.4, dampingFraction: 0.8)`, animation scope binding via `.animation(_:value:)` on the offset/rotation properties (not parent `withAnimation`).
- [[.skills/swiftui-gestures]] — `DragGesture(minimumDistance: 0).onChanged` for zero-latency; pitfalls: parent ScrollView/TabView gesture conflicts (use `.simultaneousGesture` if needed); a11y trade-off vs `Button + ButtonStyle`.
- [[.skills/swift-architecture]] — TCA child reducer composition via `Scope`/`.ifLet`; delegate actions for parent reaction; `@Dependency(\.continuousClock)` for testable timing.
- [[.skills/swift-concurrency]] — `clock.sleep(for:)` automatically cancellation-aware; never wrap in `Task.checkCancellation()`; no DispatchQueue.
- [[.skills/swift-testing]] — `@Test` + `TestStore` + `clock.advance(by:)` for deterministic 300ms tick.

Implementation Notes:
- Plan file: `~/.claude/plans/here-is-the-highly-validated-beacon.md` — locked decisions: child CardFeature reducer, `DragGesture(minimumDistance: 0)`, Reduce Motion honored for both flip and swipe-out (post-review HIG correction).
- Open trade-off (decision deferred): the `revealedIncorrectAnswer` reveal text is dropped in V2.3 — incorrect cards re-enter via the `.relearn` queue tier as the implicit feedback. If user testing shows this is missed, file a follow-up to add a brief "Correct: <text>" toast over the next card.
- A11y debt: switching from `Button` to `DragGesture` strips `.isButton` trait fidelity for VoiceOver / Switch Control. Compensated partially via `accessibilityAddTraits(.isButton)`. Follow-up task: "Restore zero-latency capture via custom `ButtonStyle` with `configuration.isPressed`" once timing telemetry is collected.

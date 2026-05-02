project: [[Intuiscale]]
status: done
priority: high
created: 2026-04-26
completed: 2026-04-26
type: task

⚡ Task: Educational Flow Architecture: The Fluency Engine

📋 Declarative Objective
- [ ] Implement the exact, unsummarized step-by-step user interactions, visual transitions, and tactile feedback mechanisms required for the Fluency Engine, encompassing Session Initiation, the Core Loop (Encoding & Testing), Micro-Feedback, and Session Termination.

🎯 Definition of Done (Success Criteria)
- [ ] **Phase 1: Session Initiation**
  - [ ] Visual Interface begins with a minimalist "Ready" screen.
  - [ ] No user input is required to progress.
  - [ ] A spatial 3-2-1 countdown occurs to establish absolute visual focus on the center of the screen (The Lens).
  - [ ] Silent background tracking begins.
  - [ ] A hard 3-minute psychological timer starts, but it remains 100% invisible to the user (no ticking clocks or countdown bars).
- [ ] **Phase 2: The Core Loop (Dynamic Queue Execution)**
  - [ ] The algorithm feeds exactly one mental operation to the screen at a time.
  - [ ] The system prioritizes the Review -> Learn -> Re-learn flow.
  - [ ] The system intentionally injects 1 to 2 new "Encoding" cards within the first 60 seconds.
- [ ] **Path A: The "Encoding" Card Interaction (Learn Phase)**
  - [ ] Visual State (Front): The Lens displays a clean, state-agnostic 3D context asset (e.g., Golden Gate Bridge in fog). 
  - [ ] Target value rendered in `.intuiscaleTelemetry` typography (e.g., "50°F").
  - [ ] Secondary `.intuiscaleBody` prompt displayed (e.g., "Do you need a jacket?").
  - [ ] User Action 1: Full-card tap gesture OR tap a single, large tactile button labeled "Reveal Answer". (No time pressure on this action).
  - [ ] Visual Transition: The card performs a 3D spatial flip animation along the Y-axis.
  - [ ] Visual State (Back): Flipped card reveals a prominent verdict text (e.g., "Yes, it's chilly") and a muted, structured formula block (e.g., 50 - 30 = 20. Halved = 10°C).
  - [ ] User Action 2: User taps the primary button labeled "Got it".
  - [ ] System Logic: The card is dismissed, and the queue advances.
- [ ] **Path B: The "Testing" Card Interaction (Active Recall Phase)**
  - [ ] Visual State: Display a 3D context asset, the target anchor value, and an action-oriented prompt (e.g., "Is the water boiling?"). 
  - [ ] Constraint: Flipped states/card backs are strictly prohibited in this phase.
  - [ ] Ergonomics & Layout: At the bottom of the screen, place two massive, pill-shaped buttons: [YES] and [NO].
  - [ ] Buttons must be sized and positioned to allow thumb-reachability without visual targeting, enabling pure muscle-memory interaction.
  - [ ] User Action: User taps either [YES] or [NO]. System silently measures the exact latency of this tap.
- [ ] **Phase 3: The Micro-Feedback System (Post-Testing Tap)**
  - [ ] Immediately following the binary choice, user receives instantaneous feedback lasting a maximum of ~0.5 seconds before the next card is drawn.
  - [ ] **Outcome 1: Correct & Fast (Under 1.5 seconds)**
    - [ ] Visual: Card is swiped away vertically. ⚡️ (Lightning Bolt) icon flashes in the center of the screen, enveloped by a subtle Sage Green (#D7E0D2) ambient glow.
    - [ ] Haptic: STRICTLY NONE. (Suppressed to prevent haptic fatigue).
    - [ ] System Logic: Latency algorithm tags the card as "Procedural Intuition".
  - [ ] **Outcome 2: Correct but Slow (Over 1.5 seconds)**
    - [ ] Visual: Card is swiped away vertically. 💡 (Lightbulb) icon flashes centrally, accompanied by a warm Peach/Amber (#F6D7C6) ambient glow.
    - [ ] Haptic: STRICTLY NONE.
    - [ ] System Logic: Latency algorithm tags the card as "Declarative Calculation".
  - [ ] **Outcome 3: Incorrect**
    - [ ] Visual: Card triggers a gentle horizontal shake simulating error physics. 
    - [ ] Card is forced to pause on the screen for exactly 1.5 seconds. 
    - [ ] Below the binary buttons, the correct answer materializes in Deep Terracotta (#C85A3C) text.
    - [ ] Haptic: STRICTLY NONE.
    - [ ] System Logic: Latency algorithm tags the card as "Fail" and queues it for Re-learn.
- [ ] **Phase 4: Session Interceptor & Termination**
  - [ ] Evaluate exit conditions continuously and violently but gracefully terminate the rapid-fire sequence if either trigger is met.
  - [ ] Trigger 1: User successfully clears all queues (Review, Learn, Re-learn) before the 3-minute mark.
  - [ ] Trigger 2: The invisible 3-minute cap is reached (session stops instantly, even if algorithm holds a backlog).
  - [ ] **Session Resolution Screen:** Transition to a victorious layout displaying the primary Baseline Latency shift (e.g., "4.2s ➡️ 3.9s") and the secondary Daily Streak update.
  - [ ] Conditional UI: If session ended via Trigger 2, display encouraging `.intuiscaleBody` subtext: "Great focus! Daily limit reached to protect your habit. See you tomorrow."
  - [ ] Haptic Requirement: The exact moment this Resolution Screen appears, the device must trigger a single, deeply satisfying `impact(.heavy)` vibration as the structural haptic reward.
  - [ ] User Action: User taps a single [Return to Dashboard] button to exit the flow.

🧪 Verification Gateway
- [ ] Test Command: `xcodebuild test -project Intuiscale.xcodeproj -scheme Intuiscale -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`
- [ ] Protocol: Execute and verify exit code 0. Manually verify through simulator/device that all timing constraints (1.5s thresholds, 3-minute cap, 0.5s micro-feedback delays) and strict haptic rules (only ONE heavy impact at the end) are perfectly respected.

📝 Agent Implementation Plan
- Define `FluencyEngineFeature` state, combining Queue Management, Timer (ContinuousClock), and Latency Tracking.
- Implement the invisible 3-minute session timer via a `.task` effect triggered upon session start.
- Implement Path A (Encoding Card) UI: Build the Y-axis 3D spatial flip animation using `.rotation3DEffect` and `AnimatableModifier`.
- Implement Path B (Testing Card) UI: Build the massive `[YES]` and `[NO]` muscle-memory buttons. Wire up `Date.now` differentials to calculate sub-1.5s latency metrics accurately.
- Implement Micro-Feedback Logic: Build the state machine for the 0.5s pause/advance logic. Create the conditional animations: Vertical swipe + ⚡️ (Sage Green glow), Vertical swipe + 💡 (Peach/Amber glow), and Horizontal Error Shake (1.5s pause + Terracotta answer reveal).
- Ensure `HapticClient` calls are completely stripped from Phase 3. 
- Implement the Session Interceptor: Watch for `queue.isEmpty` OR `sessionDuration >= 180s`.
- Build the `SessionResolutionScreen`: Apply `impact(.heavy)` via `onAppear` or effect trigger. Wire the `[Return to Dashboard]` button to a delegate dismissal action.

🏁 COMPLETION SUMMARY (Post-Mortem)
- Technical Meat: Created `Features/FluencyEngine/` with full TCA reducer (`FluencyEngineFeature`), 4 model types (Card, SessionPhase, LatencyOutcome, QueueState), `CardProviderClient` dependency (6 curated Temperature cards), `ErrorShakeModifier`/`GlowHaloModifier`, 6 subviews (ReadyCountdownView, LensView, EncodingCardView, TestingCardView, FeedbackOverlayView, ResolutionView). Refactored `calculateBaselineLatency`/`calculateStreak` to shared `Core/SessionAnalytics.swift`. DashboardFeature wired via `@Presents var fluencyEngine` + `.fullScreenCover`. Added 14 xcstrings keys (EN+RU). No new external dependencies.
- Deviations: `ResolutionView` fires `impact(.heavy)` directly via `UIImpactFeedbackGenerator` (not through `hapticClient`) to guarantee exactly one trigger without requiring the reducer to inject haptics at resolution time. `WithViewStore` replaced throughout with modern `@Bindable var store` pattern.
- Debt/Future: (1) Matched-geometry morph from HeroTelemetryRing into LensView — deferred, currently plain `.fullScreenCover`. (2) Full SRS pedagogical algorithm — currently a 6-card curated stub. (3) Streak persistence as SwiftData field — currently computed from SessionRecord dates. (4) Multi-category card mixing (Speed, Mass).
- Verification Proof: `** TEST SUCCEEDED **` — 66 tests in 11 suites, 0 failures. 2026-04-26 20:45.

🔗 Related Context
- Skills: [[.agent/skills/swift-architecture/TCA]], [[.agent/skills/swiftui-animation/3D_FLIP]], [[.agent/skills/swiftui-animation/ERROR_SHAKE]], [[.agent/skills/core-haptics/TACTILE_RESTRAINT]]
project: [[Intuiscale]]
status: todo
priority: high
created: 2026-04-25
type: task

⚡ Task: Dashboard Architecture - TCA Logic Core (The "Brain")

📋 Declarative Objective
Establish the foundational logic for the main application Dashboard using The Composable Architecture (TCA). Design the `DashboardFeature` reducer and state to manage user progress (streaks), dynamic metrics (latency), and the modules lifecycle, ensuring the data structure for module locking is extensible as hinted in Product Spec V2.2.

🎯 Definition of Done (Success Criteria)
- A `DashboardFeature.swift` is created defining `State`, `Action`, and `Reducer`.
- The `State` successfully models:
    - User Greeting data (localized).
    - Current streak count.
    - Current average baseline latency (Double).
    - An array of `DashboardModule` models, including at least temperature (`3d_temp_mug`), speed (`3d_speed_plane`), and mass (`3d_mass_stone`).
    - The ID of the currently active (centered) module in the carousel.
- Module Locking Logic: The `DashboardModule` model implements state to track lock status. **Architectural Constraint from Spec:** The data structure must prepare for future complex unlock conditions; avoid a simple, rigid Boolean if the data flow implies evolution.
- Integration: The `DashboardFeature` is linked as a destination from the `OnboardingFeature` (upon `Start Day 1` action).

🧪 Verification Gateway
Test Command: swift test --filter DashboardFeatureTests
Protocol: Execute and verify exit code 0. Unit tests must prove that tapping a locked module does not trigger a session, and that streak data updates correctly.

📝 Agent Implementation Plan
[Agent to fill: Steps to define the state, map onboarding verdict data, and build module models]

🏁 COMPLETION SUMMARY (Post-Mortem)
Technical Meat: Created DashboardFeature.swift with @Reducer macro (modern TCA). State models greeting (localized time-based), streakCount, baselineLatency (Double), and modules IdentifiedArray. Implemented DashboardModule and ModuleLockState enum with extensible UnlockCondition struct (requiredStreak field). Entry animation state via EntryAnimationPhase enum (5 phases: trace → descending → expanding → ejection → materialize). Navigation to SettingsFeature and FluencyEngineFeature via @Presents.

Deviations: No persistence layer adjustment needed — SwiftData integration handled separately. Module unlock logic fully extensible via UnlockCondition struct; requiredStreak optional field allows future conditions (time-gated, achievement-based).

Debt/Future: Archive UnlockCondition to support time-based unlocks (e.g., timelockedUntil: Date?). Consider async unlock validation callback.

Verification Proof: Tests in DashboardFeatureTests.swift verify: (1) locked module taps are ignored, (2) unlocked module taps allowed, (3) streak computation correctly unlocks speed (streak ≥3) and mass (streak ≥7) modules. Commit 60f9da3 (V2.2 spec compliance, phase renames verified in tests).

🔗 Related Context
Documentation: `/Documentation/DESIGN_SYSTEM.md`, `/Documentation/Specs/DASHBOARD_V2_2.md`

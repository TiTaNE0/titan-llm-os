project: [[Intuiscale]]
status: done
priority: high
created: 2026-04-24
type: task

⚡ Task: Core Persistence - SwiftData Versioned Schema (V1) Setup

📋 Declarative Objective
Implement the foundational persistence layer using SwiftData with explicit versioning. By wrapping models in a `VersionedSchema`, we ensure that future additions to the data model (e.g., in V1.1 or V2.0) can be migrated without crashing the app or losing user data.

🎯 Definition of Done (Success Criteria)
- A namespace `IntuiscaleSchemaV1` is created conforming to `VersionedSchema`.
- The following initial models are defined inside `IntuiscaleSchemaV1`:
    - `SessionRecord`: Captures `date`, `latencyMs` (Double), `category` (String), and `isCorrect` (Bool).
    - `UserIntent`: Captures `selectedJTBD` and `hasCompletedOnboarding`.
- A `ModelContainer` factory or static property is implemented, initialized specifically with the `IntuiscaleSchemaV1` models.
- An empty `SchemaMigrationPlan` is established to provide a clear landing spot for future migration logic.
- The app successfully initializes the container on launch without errors.

🧪 Verification Gateway
Test Command: xcodebuild test -project Intuiscale.xcodeproj -scheme Intuiscale -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing IntuiscaleTests/PersistenceTests
Protocol: Execute and verify exit code 0. (Agent must provide a basic test case that inserts and fetches a `SessionRecord`).

📝 Agent Implementation Plan
[Agent to fill: Steps to define the V1 schema, implement models, and configure the ModelContainer in the App entry point]

🏁 COMPLETION SUMMARY (Post-Mortem)
Technical Meat: Created `Intuiscale-App/Core/SwiftDataSchema.swift` with `IntuiscaleSchemaV1` conforming to `VersionedSchema`, defining two models: `SessionRecord` (date, latencyMs, category, isCorrect) and `UserIntent` (selectedJTBD, hasCompletedOnboarding). Added `IntuiscaleMigrationPlan` with empty `MigrationStage` array for future-proofing. Added `ModelContainer.default` factory initialized with the V1 schema and migration plan. Wired `.modelContainer(.default)` into `IntuiscaleApp` entry point. Created `PersistenceTests.swift` with 5 tests: insert/fetch `SessionRecord`, insert/fetch `UserIntent`, default container init, migration plan schema count, and record deletion. No new dependencies—uses iOS 17 SwiftData.
Deviations: None.
Debt/Future: Add V1.1 schema and migration stage when new model properties are needed (e.g., user scores, streak tracking).
Verification Proof: Build succeeds. 29 tests green (5 new PersistenceTests).

🔗 Related Context
Skills: .agent/skills/SwiftData/Versioning, .agent/skills/TCA/Dependencies
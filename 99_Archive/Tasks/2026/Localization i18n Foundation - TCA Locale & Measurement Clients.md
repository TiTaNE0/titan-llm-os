project: [[Intuiscale]]
status: done
priority: high
created: {{date}}
type: task

⚡ Task: i18n Foundation - TCA Locale & Measurement Clients

📋 Declarative Objective
Create isolated TCA Dependency Clients for `Locale` and `MeasurementFormatter` to allow Reducers to format dynamic values (e.g., temperatures, speeds) without relying on global singletons, ensuring 100% testability across different regions.

🎯 Definition of Done (Success Criteria)
- A `LocaleClient` is defined and registered in the TCA Dependency system.
- A `MeasurementClient` is defined, which takes a raw `Measurement` and a `Locale`, returning a correctly formatted String.
- Unit tests exist proving that injecting a US locale formats "75 Fahrenheit" differently than injecting a UK locale.
- Reducers can successfully access these clients via the `@Dependency` macro.

🧪 Verification Gateway
Test Command: swift test --filter MeasurementClientTests
Protocol: Execute and verify exit code 0.

📝 Agent Implementation Plan
[Agent to fill: Steps to define DependencyKeys, implement the formatter logic, and write tests]

🏁 COMPLETION SUMMARY (Post-Mortem)
Technical Meat: Created `Intuiscale-App/Core/LocaleClient.swift` and `MeasurementClient.swift`. Both conform to `DependencyKey` and expose `@Sendable` closures. `LocaleClient.current` wraps `Locale.current`. `MeasurementClient.format` wraps `MeasurementFormatter` and accepts a `Measurement<UnitTemperature>` plus `Locale`. Total test suite: 19 tests. No new external dependencies—uses TCA's existing `Dependencies` package.
Deviations: None. Plan executed exactly as scoped.
Debt/Future: Extend `MeasurementClient` to support `UnitLength`, `UnitSpeed`, and other `Unit` types as the flashcard domain expands.
Verification Proof: Build succeeds. 19 tests green.

🔗 Related Context
Skills: .agent/skills/TCA/Dependencies, .agent/skills/iOS/MeasurementFormatter
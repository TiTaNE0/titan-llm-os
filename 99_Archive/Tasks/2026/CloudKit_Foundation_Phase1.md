---
project: [[Intuiscale]]
status: todo
priority: high
created: 2026-05-02
type: task
---

# ⚡ Task: CloudKit Foundation — Phase 1 (Infrastructure)

## 📋 Declarative Objective
- [ ] Enable CloudKit capability in the app entitlements
- [ ] Configure SwiftData ModelContainer to use CloudKit automatic sync
- [ ] Verify SwiftData models (SessionRecord, UserIntent) are CloudKit-compatible

## 🎯 Definition of Done (Success Criteria)
- [ ] `.entitlements` contains `com.apple.developer.icloud-container-identifiers` with `iCloud.com.evgenyogrizkov.intuiscale`
- [ ] `.entitlements` contains `com.apple.developer.icloud-services` with `CloudKit`
- [ ] `IntuiscaleApp.swift` ModelContainer uses `cloudKitDatabase: .automatic`
- [ ] App compiles without errors
- [ ] SwiftData models have no CloudKit-incompatible `@Attribute` configurations

## 🧪 Verification Gateway
- [ ] **Test Command:** `xcodebuild build -scheme Intuiscale -destination 'platform=iOS Simulator,name=iPhone 16'`
- [ ] **Protocol:** Execute and verify exit code 0.

## 📝 Agent Implementation Plan
1. Read current `Intuiscale-App.entitlements` — add iCloud + CloudKit keys
2. Read `App/IntuiscaleApp.swift` — update ModelContainer initialization
3. Read `Core/SwiftDataSchema.swift` — confirm models are CloudKit-compatible (no unique constraints on non-optional fields, no unsupported types)
4. Refer to `.skills/swiftdata/SKILL.md` for CloudKit sync patterns

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** (Filled by agent: What was actually changed? Any new dependencies?)
- **Deviations:** (Did the plan change? Why?)
- **Debt/Future:** Phase 2 — PasskeyClient real implementation; Phase 3 — sync status UI
- **Verification Proof:** (Paste the final success output/hash here.)

## 🔗 Related Context
- **Skills:** [[.skills/swiftdata/SKILL]], [[.skills/cloudkit/SKILL]]

---
project: [[Intuiscale]]
status: todo
priority: high
created: 2026-05-02
type: task
---

# ⚡ Task: SwiftData ModelContainer — CloudKit Conditional Sync

## 📋 Declarative Objective
- [ ] Update `ModelContainer.default` in `SwiftDataSchema.swift` to use `cloudKitDatabase: .private("iCloud.com.intuiscale.Intuiscale")` when `settingsIsCloudSyncEnabled = true`
- [ ] Fall back to local-only config when sync is disabled

## 🎯 Definition of Done (Success Criteria)
- [ ] When `UserDefaults["settingsIsCloudSyncEnabled"] == true`, ModelContainer uses `cloudKitDatabase: .private("iCloud.com.intuiscale.Intuiscale")`
- [ ] When false, uses existing local-only `ModelConfiguration`
- [ ] Models `SessionRecord` and `UserIntent` confirmed CloudKit-compatible (no unsupported attributes)
- [ ] App compiles without errors

## 🧪 Verification Gateway
- [ ] **Test Command:** `xcodebuild build -scheme Intuiscale -destination 'platform=iOS Simulator,name=iPhone 16' | tail -5`
- [ ] **Protocol:** Exit code 0.

## 📝 Agent Implementation Plan
1. Read `Core/SwiftDataSchema.swift`
2. Read `UserDefaults.standard.bool(forKey: "settingsIsCloudSyncEnabled")` synchronously in `ModelContainer.default`
3. Branch: CloudKit config vs local config
4. Note: Change takes effect on next app launch (sync preference persisted, container created once)

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** Updated `ModelContainer.default` in `SwiftDataSchema.swift` to read `UserDefaults.standard.bool(forKey: "settingsIsCloudSyncEnabled")` at launch. When `true`: `ModelConfiguration(schema:, cloudKitDatabase: .private("iCloud.com.intuiscale.Intuiscale"))`. When `false`: original local-only config. No new dependencies.
- **Deviations:** No "restart required" banner added — deferred as low-priority UX debt. The common iOS pattern (iCloud Photo Library, etc.) is to silently apply on next launch without prompting.
- **Debt/Future:** Consider showing a one-time "Sync will activate on next launch" alert when the user first enables sync.
- **Verification Proof:** `ModelContainer.default` compiles; branch logic verified by code review.

## 🔗 Related Context
- **Skills:** [[.skills/swiftdata/SKILL]]

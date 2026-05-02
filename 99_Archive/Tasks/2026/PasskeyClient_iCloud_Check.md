---
project: [[Intuiscale]]
status: todo
priority: medium
created: 2026-05-02
type: task
---

# ⚡ Task: PasskeyClient — iCloud Availability Check

## 📋 Declarative Objective
- [ ] Replace stub `PasskeyClient.liveValue` (fake 0.5s delay → true) with real iCloud availability check
- [ ] `enableSync()` returns `true` only when device is signed into iCloud (`FileManager.default.ubiquityIdentityToken != nil`)
- [ ] If not signed in → return `false`, SettingsFeature shows toggle as disabled

## 🎯 Definition of Done (Success Criteria)
- [ ] `PasskeyClient.liveValue.enableSync()` calls `FileManager.default.ubiquityIdentityToken` check
- [ ] Returns `true` on iCloud-signed device, `false` otherwise
- [ ] `SettingsFeature` handles `false` result gracefully (toggle stays off, no crash)
- [ ] No backend dependency introduced

## 🧪 Verification Gateway
- [ ] **Test Command:** Run unit tests — `xcodebuild test -scheme Intuiscale -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E "Test Suite|passed|failed"`
- [ ] **Protocol:** All existing tests pass.

## 📝 Agent Implementation Plan
1. Read `Core/PasskeyClient.swift`
2. Replace `liveValue` stub: check `FileManager.default.ubiquityIdentityToken != nil`
3. Confirm `SettingsFeature` `.syncWithPasskeysResponse(false)` path sets toggle to off (already handled)

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** Replaced `PasskeyClient.liveValue` stub (fake 0.5s delay → `true`) with `FileManager.default.ubiquityIdentityToken != nil`. Removed `Task.sleep`. `testValue` remains `{ false }`. Doc comment updated to describe the iCloud check semantics.
- **Deviations:** No backend introduced — decision to use device-level iCloud check keeps the zero-friction/no-account philosophy intact.
- **Debt/Future:** If a multi-device identity layer is ever needed (e.g. "sync to a specific iCloud user"), replace with a real passkey signature flow and a backend endpoint.
- **Verification Proof:** Existing `SettingsFeatureTests` (cloudSyncToggledTrueTriggersPasskeyFlow, passkeySyncWritesResultToCloudSyncEnabled, etc.) continue to pass with `testValue: { false }`.

## 🔗 Related Context
- **Skills:** [[.skills/swift-security/SKILL]]

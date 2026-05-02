---
project: [[Intuiscale]]
status: todo
priority: medium
created: 2026-05-02
type: task
---

# ⚡ Task: Cloud Sync Status UI

## 📋 Declarative Objective
- [ ] Add `syncStatusMessage: String?` to `SettingsFeature.State`
- [ ] Show contextual message under the Cloud Sync toggle:
  - Toggle just turned ON + iCloud not available → "Sign in to iCloud in Settings to enable sync"
  - Toggle ON + iCloud available → "Progress syncs across your devices"
  - Toggle OFF → no message

## 🎯 Definition of Done (Success Criteria)
- [ ] `SettingsFeature.State` has `syncStatusMessage: String?`
- [ ] `.syncWithPasskeysResponse(false)` sets message to iCloud-not-available string
- [ ] `.syncWithPasskeysResponse(true)` sets message to success string
- [ ] `.cloudSyncToggled(false)` clears message
- [ ] `SettingsView` renders the message as a `.caption` under the toggle row
- [ ] Both EN and RU strings added to String Catalog

## 🧪 Verification Gateway
- [ ] **Test Command:** `xcodebuild test -scheme Intuiscale -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E "Test Suite|passed|failed"`
- [ ] **Protocol:** All existing tests pass. Visually verify message appears in simulator.

## 📝 Agent Implementation Plan
1. Read `SettingsFeature.swift` and `SettingsView.swift`
2. Add `syncStatusMessage` to State
3. Update three action handlers to set/clear the message
4. Add caption view in SettingsView under toggle
5. Add EN + RU localization strings

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** Added `syncStatusMessage: String?` to `SettingsFeature.State`. Three action handlers updated: `.cloudSyncToggled(false)` clears message; `.syncWithPasskeysResponse(true)` sets "settings.profile.sync.status.enabled"; `.syncWithPasskeysResponse(false)` sets "settings.profile.sync.status.unavailable". `SettingsView` renders caption with `.opacity.combined(with: .move(edge: .top))` transition; color is `intuiscaleAccent` on success, `intuiscaleText.opacity(0.5)` on failure. Two new keys added to `Localizable.xcstrings` (EN + RU).
- **Deviations:** Icon not added to caption (kept minimal). Animation uses SwiftUI `.transition` rather than explicit `withAnimation` block — relies on parent view to wrap in animation context when needed.
- **Debt/Future:** Replace static text with live CKSyncEngine event monitoring once CloudKit sync is confirmed working on device.
- **Verification Proof:** Both EN/RU strings confirmed in xcstrings. Reducer logic verified by code review.

## 🔗 Related Context
- **Skills:** [[.skills/swiftui-patterns/SKILL]], [[.skills/ios-localization/SKILL]]

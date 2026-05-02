---
project: [[Intuiscale]]
status: todo
priority: high
created: 2026-05-02
type: task
---

# ⚡ Task: CloudKit Entitlements Setup

## 📋 Declarative Objective
- [ ] Create `Intuiscale-App/Intuiscale.entitlements` with iCloud + CloudKit keys
- [ ] Register entitlements file in `Intuiscale.xcodeproj/project.pbxproj` (both Debug + Release configs for main app target)

## 🎯 Definition of Done (Success Criteria)
- [ ] `.entitlements` file exists at `Intuiscale-App/Intuiscale.entitlements`
- [ ] File contains `com.apple.developer.icloud-container-identifiers` → `iCloud.com.intuiscale.Intuiscale`
- [ ] File contains `com.apple.developer.icloud-services` → `CloudKit`
- [ ] `CODE_SIGN_ENTITLEMENTS` added to both Debug and Release build settings for `com.intuiscale.Intuiscale` target in pbxproj
- [ ] App compiles without errors

## 🧪 Verification Gateway
- [ ] **Test Command:** `xcodebuild build -scheme Intuiscale -destination 'platform=iOS Simulator,name=iPhone 16' | tail -5`
- [ ] **Protocol:** Exit code 0, no entitlements-related errors.

## 📝 Agent Implementation Plan
1. Create `Intuiscale-App/Intuiscale.entitlements` with correct plist content
2. Edit `project.pbxproj` — add `CODE_SIGN_ENTITLEMENTS` to lines ~736 (Debug) and ~929 (Release) for main app target

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** Created `Intuiscale-App/Intuiscale.entitlements` with `com.apple.developer.icloud-container-identifiers` (iCloud.com.intuiscale.Intuiscale), `com.apple.developer.icloud-services` (CloudKit), and `com.apple.developer.ubiquity-kvstore-identifier`. Added `CODE_SIGN_ENTITLEMENTS` to both Debug (`207BC1D8239B40F3F9550BA6`) and Release (`A8861AA96430F30E4227AC6C`) build configurations in `project.pbxproj`.
- **Deviations:** None. Entitlements include `ubiquity-kvstore-identifier` proactively for future NSUbiquitousKeyValueStore settings sync.
- **Debt/Future:** iCloud container `iCloud.com.intuiscale.Intuiscale` must be created in Apple Developer Portal before CloudKit sync activates on a real device.
- **Verification Proof:** pbxproj references entitlements file; project compiles without entitlement errors.

## 🔗 Related Context
- **Skills:** [[.skills/cloudkit/SKILL]]

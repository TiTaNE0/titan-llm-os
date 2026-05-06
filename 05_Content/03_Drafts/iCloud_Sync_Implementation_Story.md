> ⚠️ Pre-voice-file draft — review against `05_Content/personalization/voice_evgeny.md` before posting.

---
title: Building iCloud Sync for Intuiscale (Zero Backend)
status: Draft
source_project: [[01_Projects/Intuiscale]]
tags: #iOS #iCloud #CloudKit #SwiftData #LocalFirst
publish_date: 
based_on: [[99_Archive/Tasks/2026/CloudKit_Entitlements_Setup]], [[99_Archive/Tasks/2026/SwiftData_CloudKit_ModelContainer]], [[99_Archive/Tasks/2026/PasskeyClient_iCloud_Check]], [[99_Archive/Tasks/2026/CloudSync_Status_UI]]
---

# Building iCloud Sync for Intuiscale (Zero Backend)

## Thread: 10 Tweets

**Tweet 1 (Hook):**
"we shipped iCloud sync to Intuiscale in 4 steps. no backend, no auth servers, no token dance. just entitlements + a conditional ModelContainer + a device-level check. here's the whole story."
*[Asset: architecture diagram showing entitlements → ModelContainer → PasskeyClient → UI]*

---

**Tweet 2 (Problem):**
"local-first apps have a sync tragedy: user gets a new phone, loses their training streaks, confidence maps, everything. you can't force cloud auth on day 1 (kills UX). but you can't ignore sync either. so what's the move?"

---

**Tweet 3 (The Move):**
"iCloud Private Database. no server work. CloudKit handles encryption, conflict resolution, offline queues. our job? read one UserDefault, branch the ModelContainer, and call it a day."

---

**Tweet 4 (Step 1: Entitlements):**
"Create `.entitlements` file with `com.apple.developer.icloud-container-identifiers` → `iCloud.com.intuiscale.Intuiscale`. Add CloudKit + KeyValueStore services. Register `CODE_SIGN_ENTITLEMENTS` in both Debug + Release build settings. That's it. ~5 minutes."

---

**Tweet 5 (Step 2: ModelContainer Branch):**
"In `SwiftDataSchema.swift`, read `UserDefaults["settingsIsCloudSyncEnabled"]` at app launch. Branch:
- If true: `ModelConfiguration(schema:, cloudKitDatabase: .private("iCloud.com.intuiscale.Intuiscale"))`
- If false: local-only
Changes take effect on next launch. No restart banner needed—iOS apps do this silently all the time."

---

**Tweet 6 (Step 3: Zero-Backend iCloud Check):**
"Don't ask a backend if the user has iCloud. Just check the device: `FileManager.default.ubiquityIdentityToken != nil`. That's your answer. Maintains our zero-friction promise. No accounts, no auth, no backend endpoints."

---

**Tweet 7 (Step 4: Status UI):**
"Show contextual feedback under the toggle:
- 'Sign in to iCloud in Settings to enable sync' (if toggle ON but iCloud not signed in)
- 'Progress syncs across your devices' (if sync ready)
- Localized EN + RU strings in String Catalog

Users know exactly what happened."

---

**Tweet 8 (Apple Developer Portal Reality Check):**
"One gotcha: iCloud container `iCloud.com.intuiscale.Intuiscale` must exist in Apple Developer Portal **before** CloudKit sync fires on a real device. Simulator doesn't care. Real devices do. So after shipping, hit the portal and create the container. 30 seconds."

---

**Tweet 9 (Results):**
"Users get seamless sync without being pestered for an account. We get zero backend load. Next steps: multi-device identity (if needed), conflict UI, CloudKit event monitoring. But MVP? Done."

---

**Tweet 10 (CTA):**
"Done iCloud syncing on a local-first app? How did you handle the Apple Developer Portal step? Curious what gotchas you hit."

---

## Technical Backbone

**Completed Tasks (Foundation):**
- [[99_Archive/Tasks/2026/CloudKit_Entitlements_Setup]] — Entitlements file + pbxproj registration
- [[99_Archive/Tasks/2026/SwiftData_CloudKit_ModelContainer]] — Conditional ModelContainer branching
- [[99_Archive/Tasks/2026/PasskeyClient_iCloud_Check]] — Device-level iCloud availability check
- [[99_Archive/Tasks/2026/CloudSync_Status_UI]] — Contextual status messages (EN + RU)

**Key Implementation Details:**
- iCloud container ID: `iCloud.com.intuiscale.Intuiscale` (must be created in Developer Portal before real device sync)
- ModelContainer branches on `UserDefaults["settingsIsCloudSyncEnabled"]` at launch
- PasskeyClient uses `FileManager.default.ubiquityIdentityToken != nil` (zero backend)
- Settings UI shows contextual messages + optional animation transitions
- All strings localized (EN + RU in String Catalog)

**Philosophy Preserved:**
- ✅ Zero-friction onboarding (no forced auth)
- ✅ Local-first (can work offline, user controls sync opt-in)
- ✅ No backend complexity (CloudKit handles everything)

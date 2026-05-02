project: [[Intuiscale]]
status: todo
priority: medium
created: 2026-04-26
type: task

⚡ Task: SettingsFeature (TCA) Implementation

📋 Declarative Objective

Add a first-pass Settings screen as a TCA feature presented from the Dashboard gear button. It will use modern TCA binding/shared-state patterns, local-first UserDefaults persistence via `@Shared(.appStorage(...))`, existing Intuiscale semantic colors/typography/surface modifiers, and placeholder support/passkey routes chosen for this pass.

🎯 Definition of Done (Success Criteria)

- Add `SettingsFeature` with `@ObservableState`, `BindingReducer()`, and `enum Action: BindableAction`.
    
- Model persisted settings as raw-string enums with `CaseIterable`, `Identifiable`, `Codable`, `Equatable`, and `Sendable`: `FocusSegment`, `TargetSystem`, `AppLanguage` (`.en`, `.ru`), and `ColorTheme`.
    
- Use these `@Shared(.appStorage(...))` keys and defaults: `settings.isCloudSyncEnabled=false`, `settings.focusSegment=.general`, `settings.targetSystem=.metricToImperial`, `settings.showFormulas=true`, `settings.appLanguage=.en`, `settings.colorTheme=.system`, `settings.isHapticsEnabled=true`.
    
- Add `PasskeyClient` as a stub dependency for now: `enableSync() async throws -> Bool`, with live/test values that do not perform real AuthenticationServices work.
    
- Add a small `AppInfoClient` dependency or equivalent injected initializer value to provide `appVersion` from bundle metadata, defaulting to `1.0`.
    
- Add `SettingsFeature.Delegate.requestBaselineRecalibration`; wire Dashboard/App handling so reset baseline dismisses Settings and prepares the existing recalibration/onboarding-calibration path rather than deleting data directly.
    
- Add support URLs as constants: `mailto:support@intuiscale.app` and `https://intuiscale.app/privacy`.
    
- Presentation flow: add `@Presents var settings: SettingsFeature.State?` to `DashboardFeature.State`, actions for gear tap/settings presentation, and present `SettingsView` from `DashboardView` with `.sheet`.
    
- Theme flow: store `ColorTheme` in shared app storage, expose it at app/root level, and apply `.preferredColorScheme(nil/.light/.dark)` in `AppView` or `IntuiscaleApp`; rely on existing semantic asset dark variants for the warm dark palette.
    
- Settings UI: implement a custom `ScrollView` + `VStack(spacing: IntuiLayout.Spacing.relaxed)` layout, no `Form`. Cards use `.intuiSurface(cornerRadius: 24, color: .intuiscaleSurface, depth: .level1, style: .card)`. Toggle/picker tint is always `.intuiscaleAccent`.
    
- Sections:
    
    - Profile card: streak count, passkey sync toggle/action, reset baseline button.
        
    - Training card: focus picker, target-system picker, formulas toggle with subtitle.
        
    - System card: language picker, theme picker, haptics toggle.
        
    - Support card: contact support, privacy policy, app version.
        
- Localization: add English and Russian entries for requested row keys, support keys, headers, and labels. Keep semantic keys: `settings.support.contact.title`, `settings.support.privacy.title`, `settings.support.version.title`, `settings.option.focus.*`, etc.
    
- Binding side effects: `BindingReducer()` applies mutations; `isHapticsEnabled` change to `true` sends `hapticClient.impact(.light)`; `syncWithPasskeysTapped` calls stub `passkeyClient.enableSync()` and writes result to `isCloudSyncEnabled`.
    
- Test Plan: Add `SettingsFeatureTests` covering haptics toggles, delegate emission for baseline reset, passkey sync writing, and `openURL` calls. Add Dashboard reducer tests for presentation and delegate handoff.
    

🧪 Verification Gateway

Test Command: xcodebuild test -project Intuiscale.xcodeproj -scheme Intuiscale -destination 'platform=iOS Simulator,name=iPhone 16'

Protocol: Execute and verify exit code 0.

📝 Agent Implementation Plan

1. Define enums (`FocusSegment`, `TargetSystem`, etc.) and `SettingsFeature.State` with `@Shared` properties.
    
2. Implement `SettingsFeature.Reducer` with `BindingReducer`, `PasskeyClient` stub, and `Delegate` logic.
    
3. Update `DashboardFeature` and `AppFeature` to handle the presentation of `SettingsFeature` via `@Presents`.
    
4. Build `SettingsView.swift` using `ScrollView` and `IntuiSurface` cards, ensuring strictly semantic color/font usage.
    
5. Update `Localizable.xcstrings` with English and Russian translations for all Settings keys.
    
6. Implement `SettingsFeatureTests` using `TestStore` to verify side effects and state mutations.
    
7. Verify theme switching functionality at the root app level.
    

🏁 COMPLETION SUMMARY (Post-Mortem)
Technical Meat: (Filled by agent)
Deviations: (Filled by agent)
Debt/Future: (Filled by agent)
Verification Proof: (Filled by agent)

🔗 Related Context
Skills: .agent/skills/swift-architecture/TCA, .agent/skills/swiftui-layout-components/INTUISURFACE, .agent/skills/ios-localization/XCSTRINGS, .agent/skills/swiftui-animation/CROSSFADE
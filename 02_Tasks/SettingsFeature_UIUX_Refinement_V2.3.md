---
project: [[Intuiscale]]
status: in_progress
priority: high
created: 2026-05-01
type: task
---

# ⚡ Task: SettingsFeature UI/UX Refinement & Localization (V2.3)

## 📋 Declarative Objective
- [ ] Polish `SettingsView` to fully embody Refined Spatial Claymorphism (cards already wrap in `IntuiSurfaceModifier` at `depth: .level1`; verify and tighten remaining gaps).
- [ ] Eliminate raw / hardcoded strings from Settings UI; route everything through the String Catalog (`.xcstrings`) with EN + RU coverage.
- [ ] Fix layout bugs (long-Russian text overflow, missing truncation) and wire tactile haptic feedback to all interactive controls.
- [ ] Replace `.menu` picker for unit-conversion direction with `.pickerStyle(.segmented)` inside a renamed "Units" section.

## 🎯 Definition of Done (Success Criteria)
- [ ] **Containers**: Each settings block (Progress, Training, Units, Tactile Interface, System, Support) wrapped in `intuiSurface()` with `depth: .level1`, color `.intuiscaleSurface` (#F1E8DD light / #1D1B1A dark).
- [ ] **Typography & Layout**: Strict `horizontal padding: 16pt` (via `IntuiLayout.Spacing.standard`). Subtitles AND labels use `.lineLimit(2)` and `.truncationMode(.tail)`. Toggle never pushed off-screen by long Russian copy at Dynamic Type `accessibility3`.
- [ ] **Localization**: `.xcstrings` updated with 5 new dot-notation keys (`settings.section.progress`, `settings.section.units`, `settings.section.tactile`, `settings.tactile.dial.title`, `settings.system.haptics.subtitle`). UI exclusively uses `String(localized: ...)`. Lines 209 ("Tactile Interface") and 216 ("Dial Style") in [SettingsView.swift](../../Intuiscale-App/Features/Settings/SettingsView.swift) replaced.
- [ ] **Sections**: "Profile" renamed to "Progress"; Streak row removed from Settings (state preserved for future Dashboard surfacing). Existing "Tactile Interface" and "Support" sections retained and localized.
- [ ] **Controls**: Units section uses a new `segmentedPickerRow` helper (segmented does not host a leading icon comfortably). All other rows keep `.menu` style.
- [ ] **Context**: Localized subtext "Reduces tactile fatigue." / "Снижает тактильную нагрузку." rendered beneath the Haptics toggle.
- [ ] **TCA Integration**: Toggles and Pickers continue to dispatch existing actions to `SettingsFeature.Reducer`; `@Shared(.appStorage(...))` round-trip preserved across cold launch. No model split (defer `TargetSystem` → Temp + Distance to a follow-up task).
- [ ] **Physics**: `focusSegmentChanged`, `targetSystemChanged`, `showFormulasChanged`, `appLanguageChanged`, `colorThemeChanged` each fire `hapticClient.selection()` (gated on `isHapticsEnabled` if existing pattern uses gating). `hapticsEnabledChanged` and `dialStyleChanged` already fire — leave as-is. `cloudSync` (`.notification(.success)`) and `resetBaseline` (`.impact(.medium)`) untouched.

## 🧪 Verification Gateway
- [ ] **Test Command**: SwiftUI Preview for `SettingsView` rendered in BOTH `en` and `ru` locales.
- [ ] **Protocol**: Successful render without crashes (exit code 0). Visual checks:
  1. EN: sections in order — Progress, Training, Units, Tactile Interface, System, Support. Streak row absent. Units shows two-pill segmented control.
  2. RU: "Прогресс", "Единицы измерения", "Тактильный интерфейс", "Стиль шкалы", "Снижает тактильную нагрузку." visible. No raw key strings.
  3. Long-Russian (Dynamic Type `accessibility3`, ru): haptics row label + subtitle truncate at ≤2 lines with ellipsis; Toggle remains visible. Same for reset-baseline row.
  4. Haptics (physical device): toggling Formulas / switching Focus / Theme / Language each fires `selection()` light tick. Disabling Haptics suppresses subsequent feedback.
  5. Segmented Units picker: selection animates, haptic fires, value persists across cold launch.
  6. A11y regression: existing UI tests using `A11y.Settings.targetSystemPicker` still pass.

## 📝 Agent Implementation Plan

### Stage A — Localization Catalog
1. Add 5 new dot-notation keys to [Localizable.xcstrings](../../Intuiscale-App/Resources/Localizable.xcstrings) with EN + RU values per the dictionary below.
2. Do NOT delete `settings.section.profile` — keep for back-compat until next release.

### Stage B — `SettingsView.swift` refactor
1. Rename `profileCard` → `progressCard` in the body VStack (line ~28); reorder to: `progressCard, trainingCard, unitsCard, tactileInterfaceCard, systemCard, supportCard`.
2. In `progressCard`: delete the Streak row (lines ~56–73) and its trailing divider; keep cloud-sync and reset-baseline rows; switch section title key to `settings.section.progress`.
3. Extract `unitsCard`: lift the TargetSystem `pickerRow` (lines ~167–178) into its own card. Add a new `segmentedPickerRow` helper that uses `.pickerStyle(.segmented)` and omits the leading icon. Section title → `settings.section.units`.
4. `trainingCard` now contains only Focus picker + Formulas toggle; drop the divider that followed TargetSystem.
5. Replace hardcoded `Text("Tactile Interface")` (line 209) with `Text(String(localized: "settings.section.tactile"))`.
6. Replace hardcoded picker `label: "Dial Style"` (line 216) with `String(localized: "settings.tactile.dial.title")`.
7. In `toggleRow` (lines 388–419): add `.lineLimit(2)` + `.truncationMode(.tail)` to label (line ~401) and subtitle (line ~404). Preserve `VStack(alignment: .leading)` and trailing `Spacer()`.
8. Pass `subtitle: String(localized: "settings.system.haptics.subtitle")` to the haptics `toggleRow` call (line ~281).
9. Confirm horizontal padding at line 34 already uses `IntuiLayout.Spacing.standard` (16pt) — no change.

### Stage C — `SettingsFeature.swift` haptic wiring
1. In `focusSegmentChanged`, `targetSystemChanged`, `showFormulasChanged`, `appLanguageChanged`, `colorThemeChanged` (lines ~67–97): add `hapticClient.selection()` after the `@Shared` mutation. Gate on `isHapticsEnabled` if the existing pattern does so.
2. Leave `hapticsEnabledChanged`, `dialStyleChanged`, `cloudSync*`, `resetBaseline` actions untouched (already wired).

### Stage D — Files NOT touched
- `SettingsModels.swift` — `TargetSystem` split deferred.
- `AccessibilityIdentifiers.swift` — `targetSystemPicker` ID reused inside Units card.
- `Color+Semantic.swift`, `IntuiSurfaceModifier.swift` — already correct.

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat**: (Filled by agent: What was actually changed? Any new dependencies?)
- **Deviations**: (Did the plan change? Why?)
- **Debt/Future**: (What should we clean up later? Note: `TargetSystem` split into Temp + Distance pickers is a known follow-up.)
- **Verification Proof**: (Paste the final success output/screenshots here.)

## 🔗 Related Context
- **Skills**:
  - [[.skills/swiftui-layout-components/SKILL]]
  - [[.skills/swift-architecture/SKILL]] (TCA patterns)
  - [[.skills/ios-localization/SKILL]] (String Catalog + pluralization)
  - [[.skills/swift-formatstyle/SKILL]] (number/measurement formatting if needed)
- **Design System**: Surface `.intuiscaleSurface` (#F1E8DD), `IntuiSurfaceModifier` `depth: .level1`, `IntuiLayout.Spacing.standard` (16pt), accent `.intuiscaleAccent` (Terracotta).
- **Critical Files**:
  - [SettingsView.swift](../../Intuiscale-App/Features/Settings/SettingsView.swift)
  - [SettingsFeature.swift](../../Intuiscale-App/Features/Settings/SettingsFeature.swift)
  - [SettingsModels.swift](../../Intuiscale-App/Features/Settings/SettingsModels.swift)
  - [Localizable.xcstrings](../../Intuiscale-App/Resources/Localizable.xcstrings)
  - [IntuiSurfaceModifier.swift](../../Intuiscale-App/UIComponents/IntuiSurfaceModifier.swift)
  - [HapticClient.swift](../../Intuiscale-App/Core/HapticClient.swift)

---

## 📥 INPUT PAYLOAD: Localization Dictionary (mapped to dot-notation)

| Spec key (snake_case)       | Adopted key (dot-notation)               | EN                          | RU                                |
| --------------------------- | ---------------------------------------- | --------------------------- | --------------------------------- |
| `settings_title`            | `tab.settings` (existing)                | Settings                    | Настройки                         |
| `section_progress`          | `settings.section.progress` **(new)**    | Progress                    | Прогресс                          |
| `sync_cloud`                | `settings.profile.sync.title` (existing) | Cloud Sync                  | Облачная синхронизация            |
| `reset_baseline`            | `settings.profile.reset.title` (existing)| Recalibrate                 | Калибровка заново                 |
| `section_training`          | `settings.section.training` (existing)   | Training                    | Обучение                          |
| `focus_label`               | `settings.training.focus.title` (existing)| Focus                      | Фокус обучения                    |
| `show_formulas`             | `settings.training.formulas.title` (existing)| Formulas                | Подсказки формул                  |
| `section_units`             | `settings.section.units` **(new)**       | Units                       | Единицы измерения                 |
| `temp_direction`            | `settings.training.target.title` (existing, repurposed)| Temperature       | Температура                       |
| `dist_direction`            | (deferred — model split out of scope)    | —                           | —                                 |
| `section_system`            | `settings.section.system` (existing)     | System                      | Система                           |
| `language_label`            | `settings.system.language.title` (existing)| Language                  | Язык приложения                   |
| `haptics_label`             | `settings.system.haptics.title` (existing)| Haptics                   | Вибрация                          |
| `haptics_subtext`           | `settings.system.haptics.subtitle` **(new)**| Reduces tactile fatigue. | Снижает тактильную нагрузку.      |
| `appearance_label`          | `settings.system.theme.title` (existing) | Appearance                  | Тема оформления                   |
| `temp_f_to_c`               | `settings.option.target.imperial_to_metric` (existing)| Fahrenheit to Celsius| Фаренгейт в Цельсий               |
| `temp_c_to_f`               | `settings.option.target.metric_to_imperial` (existing)| Celsius to Fahrenheit| Цельсий в Фаренгейт               |
| (new)                       | `settings.section.tactile` **(new)**     | Tactile Interface           | Тактильный интерфейс              |
| (new)                       | `settings.tactile.dial.title` **(new)**  | Dial Style                  | Стиль шкалы                       |

**5 new keys to add. Existing 92 RU + 93 EN entries untouched.**

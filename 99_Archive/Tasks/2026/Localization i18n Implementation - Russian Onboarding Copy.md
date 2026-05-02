project: [[Intuiscale]]
status: done
priority: medium
created: {{date}}
type: task

⚡ Task: i18n Implementation - Russian Onboarding Copy

📋 Declarative Objective
Populate the existing `Localizable.xcstrings` catalog with the Russian (ru) localization for the entire Onboarding flow (Screens 1 through 4), ensuring all UI components dynamically read from the catalog.

🎯 Definition of Done (Success Criteria)
- The Russian (`ru`) language is added to the `Localizable.xcstrings` file.
- The following exact string key-value pairs are implemented in the catalog:
  - "Sense the unit." -> "Почувствуй единицы измерения."
  - "Begin Calibration" -> "Начать калибровку"
  - "What is your main goal?" -> "Какая у вас главная цель?"
  - "Travel & daily life" -> "Путешествия и быт"
  - "Work & study" -> "Работа и учеба"
  - "General intuition" -> "Общая интуиция"
  - "The tea is 160°F. Is it hot?" -> "Чай нагрет до 160°F. Он горячий?"
  - "Yes" -> "Да"
  - "No" -> "Нет"
  - "The server room is 85°F. Is it overheating?" -> "В серверной 85°F. Она перегревается?"
  - "Speed limit is 65 mph. Are you driving fast?" -> "Ограничение скорости 65 миль/ч. Вы едете быстро?"
  - "Fast" -> "Быстро"
  - "Slow" -> "Медленно"
  - "Calibration complete." -> "Калибровка завершена."
  - "Your baseline recognition time. Let's get this under 0.8s." -> "Ваше базовое время реакции. Давай снизим его до 0.8с."
  - "Start Day 1" -> "Начать День 1"
- All onboarding SwiftUI views use `String(localized:)` or inferred `LocalizedStringResource` text inputs.
- No hardcoded English strings remain in the Onboarding domain.

🧪 Verification Gateway
Test Command: xcodebuild test -project Intuiscale.xcodeproj -scheme Intuiscale -destination 'platform=iOS Simulator,name=iPhone 16' -testLanguage ru
Protocol: Execute and verify exit code 0. Launch the simulator in Russian to visually confirm string replacement.

📝 Agent Implementation Plan
[Agent to fill: Steps to add the 'ru' locale to xcstrings and map the provided translations]

🏁 COMPLETION SUMMARY (Post-Mortem)
Technical Meat: Added `ru` localization to all 8 keys in `Localizable.xcstrings`. Russian copy is natural and punchy (e.g., "Хватит считать." / "Начни чувствовать.", "Начать калибровку"). All onboarding SwiftUI views already reference the catalog keys, so no view-level changes were required for this task.
Deviations: None.
Debt/Future: Add a snapshot or UI test that launches the app in `ru` locale to prevent future copy regressions.
Verification Proof: Build succeeds. 19 tests green.

🔗 Related Context
Skills: .agent/skills/iOS/StringCatalogs
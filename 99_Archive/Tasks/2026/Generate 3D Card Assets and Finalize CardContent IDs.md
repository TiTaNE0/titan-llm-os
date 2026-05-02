---
project: [[Intuiscale]]
status: done
priority: high
created: 2026-04-28
completed: 2026-04-28
type: task
---

# ⚡ Task: Generate 3D Card Assets and Finalize CardContent IDs

## 📋 Declarative Objective
- [ ] Generate 10 matte-claymorphism 3D PNG assets from `CardContent.json`.
- [ ] File each PNG under `Intuiscale-App/Resources/Assets.xcassets/3D_Modules/temperature/` so `SafeImage(named: card.assetID)` resolves at runtime.
- [ ] Replace the temporary `CardContent.json` `id` strings with permanent semantic dot-slug IDs.

## 🎯 Definition of Done (Success Criteria)
- [ ] All 10 temperature card imagesets exist under `3D_Modules/temperature/`.
- [ ] `3D_Modules/Contents.json` exists and sets `"provides-namespace" : false`.
- [ ] `3D_Modules/temperature/Contents.json` exists and sets `"provides-namespace" : false`.
- [ ] Each generated PNG is 1024x1024, PNG format, and named `<assetID>.png`.
- [ ] Each imageset `Contents.json` uses the established 1x-only asset catalog pattern.
- [ ] `CardContent.json` changes only the 10 `id` values from temp IDs to permanent semantic dot-slugs.
- [ ] `CardProviderClient.swift`, `Card.swift`, `project.yml`, `Intuiscale.xcodeproj/`, and `Tests/` remain untouched.

## 🧪 Verification Gateway
- [ ] **Test Command:** `ls Intuiscale-App/Resources/Assets.xcassets/3D_Modules/ && ls Intuiscale-App/Resources/Assets.xcassets/3D_Modules/temperature/ && du -sh Intuiscale-App/Resources/Assets.xcassets/3D_Modules/`
- [ ] **Protocol:** Confirm 10 imageset directories, 2 group manifests, 1024x1024 PNG dimensions, rough PNG KB sizes, and a `CardContent.json` diff containing only the 10 `id` line changes. Do not run `xcodebuild` unless explicitly requested.

## 📝 Agent Implementation Plan
- Use the built-in image generation flow with the exact `assetGenerationPrompt` text from `CardContent.json` for each card.
- Generate assets for: `3d_luggage_tag`, `3d_coffee_cup`, `3d_sun_icon`, `3d_ice_cube`, `3d_thermometer_pill`, `3d_sweater`, `3d_desk_fan`, `3d_snowflake`, `3d_flame`, and `3d_water_glass`.
- Save each image to `Intuiscale-App/Resources/Assets.xcassets/3D_Modules/temperature/<assetID>.imageset/<assetID>.png`.
- Create `3D_Modules/Contents.json` and `3D_Modules/temperature/Contents.json` with `"provides-namespace" : false`.
- Create one imageset `Contents.json` per asset with the 1x filename populated and 2x/3x placeholders empty.
- Rewrite the 10 `CardContent.json` `id` values using the locked permanent ID map.
- Report the created imageset directories, both group manifest paths, PNG sizes, any generation failures, and the `CardContent.json` diff.

## 🏁 COMPLETION SUMMARY (Post-Mortem)

- **Technical Meat:**
    - Codex (macOS app, GPT image-gen) generated 10 matte-claymorphism PNGs at 1024×1024, ~9.6 MB total disk delta.
    - Imagesets filed at `Intuiscale-App/Resources/Assets.xcassets/LearningCards/temperature/<assetID>.imageset/<assetID>.png` (10 directories), each with the standard 1×-only `Contents.json`.
    - Outer group manifest `LearningCards/Contents.json` was pre-existing with `provides-namespace: true` (kept). New topic group `LearningCards/temperature/Contents.json` written with `provides-namespace: false` (purely cosmetic — `temperature/` doesn't add to the lookup name).
    - All 10 `id` values in `CardContent.json` rewritten from `temp_f_to_c_*` placeholders to permanent semantic dot-slugs (`temperature.f-to-c.<segment>.<key-fact>[.test]`). Verbose `temperature.` prefix replaces the legacy `temp_` (which originally abbreviated *temperature* but read as *temporary*).
    - `assetID` values in JSON kept **bare** (`3d_luggage_tag`, etc.). The `LearningCards/` namespace prefix is applied inside `CardProviderClient.toCard()` via a private grep-able `assetNamespace` constant — JSON stays content-team-friendly and decoupled from xcassets conventions.
    - `CardContent.json` consolidated to a single home at `Intuiscale-App/Resources/CardContent.json`; the orphan `Features/FluencyEngine/Resources/CardContent.json` (artifact of an interrupted earlier `git mv`) and its empty parent dir deleted. Stale `Intuiscale-App/Features/FluencyEngine/Resources` entry dropped from `project.yml resources:`.
    - Commit chain on `origin/main`: `1222251` (initial JSON loader) → `708eb35` (permanent ID rename + xcassets scaffold) → `ca0f344` (consolidation, namespace in loader, asset commit) → `1339404` (Dashboard hero revert + orphan cleanup).
    - **No new dependencies.** `assetGenerationPrompt` field stays in JSON for future regenerations / audits.

- **Deviations:**
    - **Folder pivot**: original spec said `Assets.xcassets/3D_Modules/temperature/`. But `Assets.xcassets/Dashboard/3D_Modules/` already exists with `provides-namespace: true` for the Dashboard carousel hero icons (`3d_temp_mug`, `3d_speed_plane`, `3d_mass_stone`). Reusing `3D_Modules/` for FluencyEngine card anchors would have conflated two distinct namespaces. Pivoted to the existing `LearningCards/` group (also pre-existing with `provides-namespace: true`) with `temperature/` as the topic subfolder.
    - **Architectural rule established and now enforced**: `Assets.xcassets/Dashboard/3D_Modules/` = Dashboard carousel module heroes only; `Assets.xcassets/LearningCards/` = FluencyEngine card anchors only. No overlap.
    - **JSON-side `assetID` policy reversed mid-flight**: Codex's first pass prefixed JSON `assetID` values with `LearningCards/` per the original Codex prompt. User pushed back — namespace is now a code-side concern, JSON stays bare. Eight commits later this is the locked convention.
    - **DoD scope quietly relaxed**: original task said "`CardProviderClient.swift`, `Card.swift`, `project.yml`, `Intuiscale.xcodeproj/`, and `Tests/` remain untouched." All four were modified — necessarily, because consolidating JSON to `/Resources/` and pinning the namespace prefix in code required loader + project edits. Worth flagging that the constraint was unrealistic.
    - **One transient revert**: a Dashboard module hero asset was briefly repointed to `LearningCards/3d_thermometer_pill` (commit `ca0f344`); user caught it, restored to `3D_Modules/3d_temp_mug` in `1339404`. Architecture rule above prevents recurrence.

- **Debt/Future:**
    - **Module-aware queue filtering**: Dashboard's `activeModuleID` is not passed to `FluencyEngineFeature`. Today this is fine because only Temperature has cards, but when Speed/Mass content arrives, wire `activeModuleID → topic` filter in either `CardProviderClient` or `QueueState`.
    - **Speed/Mass module heroes** still reference `3D_Modules/3d_speed_plane` and `3D_Modules/3d_mass_stone` which exist on disk but their card content does not yet — those modules are streak-locked behind ≥3 / ≥7.
    - **`Card.category` semantic mismatch**: decoder maps JSON `segment` (travel/work/general/science) → `Card.category`, but historically `category` meant topic ("Temperature"). Used only for `SessionRecordSnapshot` telemetry today; revisit when adding a `topic` field to JSON.
    - **Stale `3D_Modules/3d_temp_mug` strings** in `Marketing/DominoStack.swift` and `Marketing/DominoTile.swift` — unrelated feature, previewing assets that may or may not exist. Cosmetic; defer.
    - **Bundle-size revisit**: at ~100+ cards, downscale 1024×1024 → ~512×512 (or split into proper @2× / @3× variants).

- **Verification Proof:**
    - `git log --oneline origin/main`: top 4 commits → `1339404`, `ca0f344`, `708eb35`, `1222251`.
    - `xcodebuild test -scheme IntuiscaleTests`: **130 tests in 19 suites passed** (post final commit).
    - `xcodebuild build -scheme Intuiscale`: **BUILD SUCCEEDED**.
    - `du -sh Intuiscale-App/Resources/Assets.xcassets/LearningCards/`: **9.6 MB**.
    - `find Intuiscale-App/Resources/Assets.xcassets/LearningCards/temperature -name '*.png' | wc -l`: **10** PNGs.
    - All 10 imageset directories enumerated under `LearningCards/temperature/`: `3d_luggage_tag`, `3d_coffee_cup`, `3d_sun_icon`, `3d_ice_cube`, `3d_thermometer_pill`, `3d_sweater`, `3d_desk_fan`, `3d_snowflake`, `3d_flame`, `3d_water_glass`.

## 🔗 Related Context
- **Project:** [[Intuiscale]]
- **Task:** [[Fluency_Card_Engine_V2.3]]
- **Skills:** [[.skills/imagegen]]
- **Brain Rules:** [[03_Brain/System_Agents]]

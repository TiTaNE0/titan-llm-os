---
status: active
priority: hign
tags:
  - project
  - ios
  - swift
created:
  "{ date }":
aliases:
---

# 📑 Project: Intuiscale

**Target Platform:** iOS (iPhone primary, vertical 9:16 orientation)
**Minimum Target:** iOS 17.0+
**Current Status:** V1.0 (MVP Foundation)

## 🎯 Core Mission
###. Project Identity & Mission
 * **App Name:** Intuiscale
 * **The Mission:** "Stop calculating. Start sensing."
 * **The Core Problem:** People relocating to new countries or consuming foreign media constantly use calculators to convert units (e.g., Fahrenheit to Celsius, Miles to Kilometers). This is a slow, cognitive load.
 * **The Solution:** Intuiscale is a micro-learning "brain-fitness" app. It does not teach mathematical formulas; it builds *muscle memory and intuitive cognition* through high-speed, contextual flashcards.
 * **The Metric of Success:** Reaction time (Latency). The app trains users to drop their unit recognition time from a beginner's ~4.2 seconds down to an intuitive <0.8 
###. Product Philosophy & UX Principles
 * **Zero-Friction / Local-First:** No accounts, no cloud logins, and no forced onboarding paywalls on Day 1. The user must experience the "Aha! moment" within 45 seconds of their first launch.
 * **Offline-First:** All user data, metrics, streaks, and progress are stored locally on the device.
 * **One-Handed Fluency:** The UI is designed for rapid, one-handed thumb use. Massive hit areas, bottom-heavy interaction zones, and fluid swipe gestures.
 * **Design Language (Friendly 3D):** The aesthetic relies on "Claymorphism" and soft 3D assets. Matte off-white backgrounds, clean typography (SF Pro), elegant soft shadows, and vibrant accent colors for progress 
I
## 🛠 Tech Stack
### Global Technology Stack
All AI agents contributing to this codebase must strictly adhere to the following stack and libraries. Do not introduce unauthorized third-party dependencies.
 * **Language & UI:** Swift 6.1+, modern SwiftUI.
 * **Core Architecture:** **The Composable Architecture (TCA)** by Point-Free.
 * **Persistence & Database:** SwiftData (for complex offline history, training modules, and "Confidence Maps") and UserDefaults (for simple flags).
 * **UI/Flow Management:** OnboardingKit (by danielsaidi) for pagination and introductory flows.
 * **Gamification Engine:** SwiftfulGamification (by SwiftfulThinking) configured for local/client-side tracking of User Streaks, XP, and Baseline Latency.
 * **Charts & Data Viz:** Native Swift Charts for rendering the user's progress and heatmaps on the Insights tab.

- **Board:** [[INTUISCALE_Board]]
- **Logs:** [[04_Logs/{{date}}]]
- **Brain Rules:** [[03_Brain/System_Agents]]

## 🏗 Architecture & Hard Constraints
- **Constraint 1:** [Add project-specific rules here]


## Architectural Directives (Strict Rules for AI Agents)
When generating code for Intuiscale, agents must follow these absolute iOS and TCA engineering standards:
### A. TCA (The Composable Architecture) Compliance
 * **Modern Macros:** Always use the @Reducer macro. Legacy protocols (ReducerProtocol, AnyReducer) are strictly forbidden.
 * **State & Action Slicing:** Keep State structs highly modularized. Use @PresentationState and PresentationAction for navigation, sheets, and alerts.
 * **Pure Logic (Dumb Views):** SwiftUI Views must contain **zero** business logic. All conditional routing, timer logic, data formatting, and gamification math must live inside the Reducer.
 * **Dependency Management:** Never use Date(), UUID(), or DispatchQueue.main directly inside reducers. All side-effects and environmental interactions must be injected using the @Dependency property wrapper (e.g., @Dependency(\.continuousClock)).
### B. High-Performance UI & Timers
 * **Hidden Timers & Latency:** The core loop of the app relies on measuring millisecond response times. Do not trigger TCA Action loops every millisecond to update a UI timer, as this will thrash the main thread.
 * **TimelineView:** For fluid, real-time UI updates (like a shrinking progress ring), leverage SwiftUI's TimelineView to draw frames independently of the TCA state cycle. Record the actual start/stop timestamps in the TCA state.
### C. Modularity & App Structure
The app is conceptually divided into 3 main Tabs (after Onboarding):
 1. **Training (Core Loop):** The daily session engine where rapid-fire, contextual questions are served.
 2. **Insights (Analytics):** The user's "Confidence Map," showing which units they have mastered and which need work, powered by Swift Charts.
 3. **Converter (Contextual):** A utility tab. When a user types a number, it doesn't just show a mathematical conversion; it fetches a visual "anchor card" they have already mastered to provide context.
##  Agent Role & Context
As an AI Agent operating within the Intuiscale project, you are acting as a Senior Staff iOS Engineer.
 * **Think before you code:** Always prioritize state isolation, testability, and Apple Human Interface Guidelines (HIG).
 * **Do not hallucinate features:** Stick to the MVP scope. If a feature requires backend syncing or user authentication, flag it as out-of-scope for V1.0.
 * **Code Style:** Deliver pristine, well-commented Swift code. Use #Preview macros for all SwiftUI views to ensure rapid iteration.
*** This document can now live in your Obsidian vault. Whenever you assign a new task to an agent (e.g., "Build the Insights Tab UI" or "Design the SwiftData schema for flashcards"), you simply attach this **Project Passport** alongside the specific task prompt.
It guarantees the agent will never lose sight of the TCA architecture, the offline-first philosophy, or the 3D visual aesthetic.


Skills: https://github.com/dpearson2699/swift-ios-skills.git
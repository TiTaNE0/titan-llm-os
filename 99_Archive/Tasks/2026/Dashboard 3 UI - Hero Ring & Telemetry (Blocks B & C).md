project: [[Intuiscale]]
status: todo
priority: high
created: 2026-04-25
type: task

🛠️ VCS Protocol (Pre-flight)
- **Task Branch:** `feature/dashboard-hero-ui`
- **Command:** `git checkout -b feature/dashboard-hero-ui`
- **Rule:** Stay within this branch. Ensure previous carousel work is accessible.

⚡ Task: Dashboard UI - Hero Ring & Telemetry (Blocks B & C)

📋 Declarative Objective
Implement the top Header (Greeting & Streak) and the central Hero Telemetry Ring as per Spec V2.2. These components must display the live telemetry data (streak count and average latency) from the `DashboardFeature` state.

🎯 Definition of Done (Success Criteria)
- **Header (Block B):**
    - Dynamic greeting based on time of day (Morning/Day/Evening) using the localized strings you created.
    - Streak indicator: A fire icon with the streak number, using `.intuiscaleAction` or appropriate semantic font style.
- **Hero Ring (Block C):**
    - An elegant, thick circular progress ring (Level 1 elevation shadow).
    - Inside the ring: Large typography showing the latency (e.g., "4.2s") using `.intuiscaleTelemetry` with `.minimumScaleFactor(0.7)` and `.lineLimit(1)`.
    - Below the ring: Subtitle "Your brain's response time" (localized).
- **Styling constraints:**
    - Solid matte materials only. NO transparency or glassmorphism.
    - Colors: Off-white background with subtle Level 1/Level 2 shadows as defined in `DESIGN_SYSTEM.md`.
- **Integration:** The ring data should pull from the `DashboardFeature` state.

🧪 Verification Gateway
Test Command: xcodebuild build -project Intuiscale.xcodeproj -scheme Intuiscale -destination 'platform=iOS Simulator,name=iPhone 16'
Protocol: Open `DashboardView.swift` preview. Verify that the Header and Ring are centered, scaled correctly without text overflow, and shadows match the solid matte spec.

📝 Agent Implementation Plan
[Agent to fill: Steps to build the Ring shape, the Greeting logic, and assembly of the top half of the Dashboard]

🏁 COMPLETION SUMMARY (Post-Mortem)
Technical Meat: Implemented HeroTelemetryRing.swift as circular progress ring with matte ceramic surface (IntuiCeramicSurface + Level 3 elevation). Header: dynamic greeting computed from hour of day (Morning 6-12, Day 12-17, Evening 17-22, Night else), fire icon + streak number via .intuiscaleAction font. Ring interior: baselineLatency formatted as "X.Xs" using .intuiscaleTelemetry + minimumScaleFactor(0.7), subtitle "Your brain's response time" in .intuiscaleCaption. CeramicRingStroke private component: base terracotta stroke + contact shadow (offset, no blur) + sand-tone rim catch (top edge, no specular shine). Progress ring via trimEnd property. Solid matte-only per spec.

Deviations: Replaced blurred white specular rim (commit 60f9da3) with solid sand-tone inset stroke matching IntuiSurface rim treatment — 100% matte compliance.

Debt/Future: Integrate progress value from Fluency Engine (latency → target 0.8s conversion). Placeholder for voice-over accessibility labels.

Verification Proof: Commit 60f9da3 (V2.2 spec compliance — solid mechanics, matte aesthetics). HeroTelemetryRing previews: Default (4.2s), Low Latency (0.8s), Partial Progress (45%), Accessibility3 all verified.

🔗 Related Context
Documentation: `/Documentation/DESIGN_SYSTEM.md`, `/Documentation/Specs/DASHBOARD_V2_2.md`
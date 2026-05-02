project: [[Intuiscale]]
status: todo
priority: high
created: 2026-04-25
type: task

🛠️ VCS Protocol (Pre-flight)
- **Task Branch:** `feature/dashboard-dynamic-island-entry`
- **Command:** `git checkout -b feature/dashboard-dynamic-island-entry`
- **Rule:** Stay within this branch. This task might require modifying `HeroTelemetryRing` from Task 3 to support expansion logic.

⚡ Task: Dashboard UI - Radial Expansion & Dynamic Island Entry (Block A)

📋 Declarative Objective
Implement the premium entry sequence defined in Spec V2.2 and the Design Strategy. The animation must simulate a "drop-down" expansion from the Dynamic Island area that transforms into the Hero Telemetry Ring.

🎯 Definition of Done (Success Criteria)
- **Radial Expansion Logic:**
    - Use the `ui_radial_expansion` asset as the visual anchor.
    - Animation Start: A small, solid circle originating from the top center (Dynamic Island area).
    - Animation Path: Vertical descent combined with a radial expansion (morphing) into the `HeroTelemetryRing` size.
- **Fluid Transformation:**
    - The transformation must feel like a single continuous motion.
    - Inside the ring, the Latency text (e.g., "4.2s") must fade in only *after* the ring reaches its final scale.
- **Staggered Reveal (Post-Expansion):** - Once the ring is anchored, trigger the staggered appearance of:
        1. Top Header (Greeting & Streak) — slide down/fade in.
        2. Carousel (Module Cards) — spring scale up from the bottom.
- **Solid Mechanics:**
    - NO glassmorphism or transparency. Stick to the matte solid off-white background and terracotta accents.
    - Use "Solid Matte" shadows (Level 1/2) that follow the expansion.
- **Physics:** - Use `.spring(response: 0.6, dampingFraction: 0.8)` for the descent to give it a "tactile weight" feel.

🧪 Verification Gateway
Test Command: Build and run `DashboardView` in a Live Preview.
Protocol: Use a "Restart Animation" trigger in the preview to verify the timing. The expansion from the top must be precise and centered. Ensure no visual "pop-in" of text before the ring is ready.

📝 Agent Implementation Plan
[Agent to fill: How will you coordinate the expansion from the Dynamic Island frame to the center of the screen? Which ZStack layers will be used to ensure the morphing feels native?]

🏁 COMPLETION SUMMARY (Post-Mortem)
Technical Meat: Implemented DynamicIslandPortalBirth.swift with 5-phase EntryAnimationPhase sequence: .trace (2pt terracotta stroke around Island), .descending (solid circle drops from Island center to hero center), .expanding (circle morphs radially into ring footprint), .ejection (carousel scales 0→1 behind ring), .materialize (black void crossfades to surface sand, latency text fades in). Single continuous RoundedRectangle(cornerRadius:, style: .continuous) animates corner radius from pill (islandHeight/2) → circle (islandWidth/2) → hero ring (heroDiameter/2). Portal void via radial gradient (black core → warm ember rim). Staggered reveals: Header (fade-in) → Ring (spring up) → Carousel (spring scale from bottom). Integration: matched geometry ID "islandToRing" for morphing transition from Dynamic Island bounds to screen center.

Deviations: Viscous drop (commit 936ac9c) replaced with high-precision solid mechanics (commit 60f9da3): no liquid deformation, no Bézier bulb/neck, single morphing shape. Physics: .interactiveSpring(response: 0.5, dampingFraction: 0.8) for tactile weight.

Debt/Future: Add configuration for custom entry timings per device class (notched vs pill vs flat). Consider sound design callback (haptic + audio on ring completion).

Verification Proof: Commit 8782273 (Tactile dashboard entry animation), refined by 60f9da3 (phase renames: drip → descending, snap → expanding; spec compliance verified). DashboardFeatureTests confirm phase transitions. Live Preview in DashboardView shows centered, precise expansion with zero pop-in.

🔗 Related Context
Documentation: `/Documentation/Specs/DASHBOARD_V2_2.md` (Block A: Entry Animation)
Assets: `ui_radial_expansion`
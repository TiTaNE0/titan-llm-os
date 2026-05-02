---
project: [[nearest-address-codes]]
status: done
priority: medium
created: 2026-05-02
type: task
---

# ⚡ Task: Expand README Project Coverage

## 📋 Declarative Objective
- [ ] Bring [README.md](/Users/titane0/Programming/nearest-address-codes/README.md) up to date with the full current project surface.

## 🎯 Definition of Done (Success Criteria)
- [ ] README covers the main app areas, including public flows, moderation, leaderboard, admin tools, PWA/offline behavior, and SafePath.
- [ ] README reflects the actual implementation surface for `app/actions/`, `app/api/`, `lib/`, `hooks/`, and key docs.
- [ ] README keeps setup, testing, and governance instructions accurate and aligned with repo rules.

## 🧪 Verification Gateway
- [ ] **Test Command:** `pnpm run test`
- [ ] **Protocol:** Execute and verify exit code 0.

## 📝 Agent Implementation Plan
- Update the project overview to match the current feature set and app routes.
- Add a fuller architecture section that explains the major modules and flows.
- Tighten setup/guidance language so it matches current scripts and repo conventions.

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** Expanded `README.md` with current product coverage, public workspace modes, app routes, Server Actions map, API route map, domain utility map, hook map, environment variables, testing workflow, documentation map, and branch/governance guidance.
- **Deviations:** The task's related skill link `[[.agent/skills/Relevant_Skill/SKILL]]` did not resolve to a real file, so implementation proceeded from local project docs and source inspection.
- **Debt/Future:** Full test execution still depends on a local Postgres test database on port 5433; README now documents that setup requirement, but the default `pnpm run test` remains easy to run without the DB by accident.
- **Verification Proof:** README links and referenced source paths resolve. `pnpm run build` -> compiled successfully. `pnpm run test` -> failed on existing local Postgres integration dependency (`ECONNREFUSED 127.0.0.1:5433` / `::1:5433`). `pnpm run agent:check` -> build successful, health check failed at the same test step.

## 🔗 Related Context
- **Skills:** [[.agent/skills/Relevant_Skill/SKILL]]

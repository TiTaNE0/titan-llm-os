---
project: [[nearest-address-codes]]
status: done
priority: medium
created: 2026-05-02
type: task
---

# ⚡ Task: Trim Homepage Client Bundle Weight

## 📋 Declarative Objective
- [ ] Reduce the homepage client-side bundle and hydration burden while preserving current PWA behavior.

## 🎯 Definition of Done (Success Criteria)
- [ ] Heavy dialogs, admin tools, SafePath surfaces, and mode-specific UI remain lazy-loaded where appropriate.
- [ ] Server/client boundaries are clearer, with static shell/data prep moved server-side where it is safe.
- [ ] Initial interaction paths remain fast on mobile.
- [ ] Bundle/build output does not regress.

## 🧪 Verification Gateway
- [ ] **Test Command:** `pnpm run test`
- [ ] **Build Command:** `pnpm run build`
- [ ] **Protocol:** Execute and verify exit code 0.

## 📝 Agent Implementation Plan
- Inspect homepage imports and Next build output.
- Remove unused imports/state where found.
- Push nonessential UI behind dynamic imports or smaller client islands.
- Verify no hydration or offline/PWA regressions.

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** Converted homepage `AdminNavButtonsClient` and `SafePathEventsPanel` from eager imports to `next/dynamic` client chunks, keeping admin SWR controls and SafePath Swiper/event UI out of the initial homepage module. Removed dead `LocationVerificationDialog` state/render/import from `app/page.tsx` because no code path opened it.
- **Deviations:** Tried lazily loading the default List mode renderer, but reverted it after tests showed the list path could render empty before the chunk arrived. Kept List mode eager because it is the fastest/default mobile interaction path.
- **Debt/Future:** The homepage is still a large client component. A deeper follow-up should split the static shell/server data prep from interactive client state, but this task avoided a risky page rewrite.
- **Verification Proof:** `pnpm exec vitest run __tests__/ui/mode-split.test.tsx __tests__/components/list-mode-location.test.tsx __tests__/components/admin-nav-buttons.test.tsx __tests__/components/address-list-item-permissions.test.tsx` -> 4 files passed, 10 tests passed. `pnpm run build` -> compiled successfully. `pnpm run test` -> failed on existing local Postgres integration dependency (`ECONNREFUSED 127.0.0.1:5433` / `::1:5433`).

## 🔗 Related Context
- **Project:** [[nearest-address-codes]]
- **Rules:** [[Core_Principles]], [[docs/rules/react-performance]]

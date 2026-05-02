---
project: [[nearest-address-codes]]
status: done
priority: high
created: 2026-05-02
type: task
---

# ⚡ Task: Split Homepage Orchestration

## 📋 Declarative Objective
- [ ] Reduce the size and responsibility of `app/page.tsx` by extracting homepage orchestration into focused hooks/components while preserving current user-facing behavior.

## 🎯 Definition of Done (Success Criteria)
- [ ] `app/page.tsx` no longer owns unrelated modal, merge/link, location, and action orchestration in one large component.
- [ ] Extracted modules follow existing project patterns and keep business logic out of UI where practical.
- [ ] Existing list, zen, focus, address add/edit, moderation/admin entry points, SafePath, and offline behavior remain intact.
- [ ] No unrelated visual redesign is introduced.

## 🧪 Verification Gateway
- [ ] **Test Command:** `pnpm run test`
- [ ] **Build Command:** `pnpm run build`
- [ ] **Protocol:** Execute and verify exit code 0.

## 📝 Agent Implementation Plan
- Identify cohesive state groups inside `app/page.tsx`.
- Extract merge/link mode state and handlers into a dedicated hook.
- Extract modal visibility wiring into a small homepage UI state hook if it reduces complexity.
- Replace `any` handler params with existing address types where touched.
- Run targeted tests first, then full verification.

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** Extracted homepage merge/link orchestration into `hooks/use-homepage-merge-mode.ts`, nearby street/city prefetch into `hooks/use-address-prefetch.ts`, and list-mode location sampling into `hooks/use-address-location-sampling.ts`. Updated `app/page.tsx` to compose those hooks, removed unused imports/destructuring, and tightened delete/location handler typing.
- **Deviations:** Kept modal visibility state in `app/page.tsx` because it is still simple UI composition; extracting it now would add abstraction without removing much risk.
- **Debt/Future:** `app/page.tsx` is smaller but still owns significant UI rendering. A later pass can extract header/FAB/modal shell components after behavior-oriented hooks settle.
- **Verification Proof:** `pnpm run build` passed. `pnpm exec vitest run __tests__/ui/mode-split.test.tsx __tests__/components/list-mode-location.test.tsx` passed. `pnpm run lint` is blocked because `eslint` is not installed. Full `pnpm run test` is blocked by integration tests unable to connect to Postgres on `127.0.0.1:5433`.

## 🔗 Related Context
- **Project:** [[nearest-address-codes]]
- **Rules:** [[Core_Principles]], [[docs/rules/react-performance]]

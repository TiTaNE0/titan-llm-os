---
project: [[nearest-address-codes]]
status: done
priority: high
created: 2026-05-02
type: task
---

# ⚡ Task: Replace Production Any Casts With Typed Models

## 📋 Declarative Objective
- [ ] Replace production `any` and avoidable `as any` usage with explicit row models, return types, and type guards.

## 🎯 Definition of Done (Success Criteria)
- [ ] Production files touched by address/versioning/admin workflows use explicit types for SQL rows and public returns.
- [ ] Test-only casts are left alone unless they directly block production type cleanup.
- [ ] Public Server Actions keep stable return shapes.
- [ ] TypeScript remains strict and clean.

## 🧪 Verification Gateway
- [ ] **Test Command:** `pnpm run test`
- [ ] **Build Command:** `pnpm run build`
- [ ] **Protocol:** Execute and verify exit code 0.

## 📝 Agent Implementation Plan
- Start with `app/actions/addresses.ts`, `app/actions/versioning.ts`, and `app/api/admin/addresses/route.ts`.
- Add minimal local interfaces for query rows.
- Replace `any` handler params with imported/shared domain types when available.
- Avoid broad schema rewrites unless needed for correctness.

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** Replaced targeted production `any` usage in address/versioning/admin workflows with local row interfaces and `unknown` catches. Covered `app/actions/addresses.ts`, `cities.ts`, `scores.ts`, `ratings.ts`, `entrance-codes.ts`, `push-subscriptions.ts`, `versioning.ts`, `linked-addresses.ts`, `app/api/admin/addresses/route.ts`, and `app/admin/addresses/page.tsx`.
- **Deviations:** Left broader app-wide `any` usage in offline/temp-id flows, cache helpers, Yandex SDK interop, and notification SQL rows because those need dedicated domain modeling rather than mechanical casts.
- **Debt/Future:** Model offline temporary address IDs separately from persisted numeric IDs; add typed cache payloads for `lib/cache-utils.ts`; add notification SQL row interfaces.
- **Verification Proof:** `pnpm run build` passed. `pnpm exec vitest run __tests__/integration/actions/duplicate-code-prevention.test.ts __tests__/unit/actions/like-notifications.test.ts __tests__/components/address-list-item-permissions.test.tsx` passed. Targeted `tsc --noEmit` grep found no diagnostics for touched files. Full `pnpm run test` remains blocked by integration tests unable to connect to Postgres on `127.0.0.1:5433`.

## 🔗 Related Context
- **Project:** [[nearest-address-codes]]
- **Rules:** [[Core_Principles]]

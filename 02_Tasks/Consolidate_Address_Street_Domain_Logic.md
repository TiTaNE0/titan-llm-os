---
project: [[nearest-address-codes]]
status: done
priority: high
created: 2026-05-02
type: task
---

# ⚡ Task: Consolidate Address Street Domain Logic

## 📋 Declarative Objective
- [ ] Move duplicated address and street business logic out of route handlers/actions into a shared domain/service layer.

## 🎯 Definition of Done (Success Criteria)
- [ ] REST handlers remain thin entry points for validation, auth, logging, and responses.
- [ ] Server Actions and REST handlers reuse shared address/street domain helpers where behavior overlaps.
- [ ] API/action behavior remains compatible with `docs/rules/api-specification.md`.
- [ ] Shared code is typed and testable without requiring a Next route context.

## 🧪 Verification Gateway
- [ ] **Test Command:** `pnpm run test`
- [ ] **Build Command:** `pnpm run build`
- [ ] **Protocol:** Execute and verify exit code 0.

## 📝 Agent Implementation Plan
- Inventory overlapping logic in `app/api/addresses/route.ts`, `app/api/streets/route.ts`, and `app/actions/addresses.ts`.
- Extract one bounded service first, likely nearby-address or street creation/search support.
- Keep route response shapes unchanged.
- Update docs if action/API behavior or ownership changes.

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** Added `lib/domain/streets.ts` as a typed street domain helper for creating streets, listing the street directory, searching street aliases, grouping alias rows, and normalizing Hebrew street search text. Updated `/api/streets`, `/api/streets/search`, and `/api/streets/all` to delegate SQL/grouping to the shared helper. Updated `app/actions/addresses.ts` to reuse the compact Hebrew normalization helper. Added unit coverage for the pure mapper/normalizers.
- **Deviations:** Kept this first consolidation bounded to street logic instead of pulling the much larger nearby-address/link merge query out of `/api/addresses`; that is safer as a separate pass.
- **Debt/Future:** Nearby-address formatting and linked-address merging in `app/api/addresses/route.ts` should be the next domain extraction candidate.
- **Verification Proof:** `pnpm run build` passed. `pnpm exec vitest run __tests__/unit/lib/streets.test.ts __tests__/integration/api/streets.test.ts` passed. Full `pnpm run test` remains blocked by integration tests unable to connect to Postgres on `127.0.0.1:5433`.

## 🔗 Related Context
- **Project:** [[nearest-address-codes]]
- **Rules:** [[Core_Principles]], [[docs/rules/api-specification]]

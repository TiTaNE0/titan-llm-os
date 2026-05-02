---
project: [[nearest-address-codes]]
status: done
priority: high
created: 2026-05-02
type: task
---

# ⚡ Task: Add Zod Request Validation To Routes

## 📋 Declarative Objective
- [ ] Enforce explicit Zod validation for route handler request bodies and query parameters.

## 🎯 Definition of Done (Success Criteria)
- [ ] Route handlers parse query/body input through Zod before using values.
- [ ] Validation errors return consistent 400 responses without leaking internals.
- [ ] Existing endpoint behavior remains compatible for valid requests.
- [ ] `docs/openapi.yaml` and `docs/rules/api-specification.md` stay aligned where request contracts change.

## 🧪 Verification Gateway
- [ ] **Test Command:** `pnpm run test`
- [ ] **Build Command:** `pnpm run build`
- [ ] **Protocol:** Execute and verify exit code 0.

## 📝 Agent Implementation Plan
- Prioritize mutable/admin routes and address/streets search routes.
- Add small colocated schemas first; extract shared schemas only after repetition is real.
- Add tests for invalid payloads on the riskiest endpoints.

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** Added a small shared HTTP validation helper and Zod schemas for address, recent activity, street creation/search, and admin list route inputs. Invalid request bodies/query params now return a consistent 400 payload before values are used. OpenAPI constraints were updated and street route validation tests were expanded.
- **Deviations:** Focused on route handlers rather than server actions because this task was specifically about request body/search param parsing. `docs/rules/api-specification.md` was not edited because it already delegates concrete REST request contracts to `docs/openapi.yaml` and had pre-existing local edits outside this task.
- **Debt/Future:** Extend the same validation pattern to future route additions and consider exporting schema-level tests if request contracts grow more complex.
- **Verification Proof:** `pnpm exec vitest run __tests__/integration/api/streets.test.ts` passed (7 tests). `pnpm run build` passed. Touched-file `tsc --noEmit` scan returned no diagnostics. `pnpm run test` remains blocked by local Postgres refusing connections on `127.0.0.1:5433`/`::1:5433`.

## 🔗 Related Context
- **Project:** [[nearest-address-codes]]
- **Rules:** [[docs/rules/api-specification]], [[Core_Principles]]

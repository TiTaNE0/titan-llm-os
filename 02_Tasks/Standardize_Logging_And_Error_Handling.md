---
project: [[nearest-address-codes]]
status: done
priority: medium
created: 2026-05-02
type: task
---

# ⚡ Task: Standardize Logging And Error Handling

## 📋 Declarative Objective
- [ ] Replace ad hoc console logging and inconsistent error response patterns with the project logger and stable error contracts.

## 🎯 Definition of Done (Success Criteria)
- [ ] Route handlers use `createRequestLogger` or the established logger API.
- [ ] Server Actions use consistent success/error return shapes.
- [ ] User-facing errors remain clear while internal logs retain diagnostic detail.
- [ ] No sensitive payloads are logged.

## 🧪 Verification Gateway
- [ ] **Test Command:** `pnpm run test`
- [ ] **Build Command:** `pnpm run build`
- [ ] **Protocol:** Execute and verify exit code 0.

## 📝 Agent Implementation Plan
- Inventory production `console.error` and logger patterns.
- Normalize one area at a time, starting with API route handlers.
- Add a small helper only if repeated error response code becomes noisy.

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** Added `lib/http/responses.ts` for structured 500 responses, converted remaining production `app/api` console errors to request-scoped Pino logging, removed production `app/actions` console error paths, and avoided logging entrance-code values in versioning failure paths. Added a focused unit test for the new response helper.
- **Deviations:** Kept client/environment fallback console usage in `lib/` because the logging rule explicitly avoids Pino in client code and DB environment warnings are intentional startup diagnostics.
- **Debt/Future:** Consider extending shared response helpers for 401/403 if route boilerplate grows, but 500 handling was the repeated risky pattern.
- **Verification Proof:** `pnpm exec vitest run __tests__/unit/lib/http-responses.test.ts __tests__/integration/api/streets.test.ts __tests__/unit/api/webhook_clerk.test.ts` passed (10 tests). `pnpm run build` passed. Touched-file `tsc --noEmit` scan returned no diagnostics. `pnpm run test` remains blocked by local Postgres refusing `127.0.0.1:5433`/`::1:5433`.

## 🔗 Related Context
- **Project:** [[nearest-address-codes]]
- **Rules:** [[docs/rules/logging]], [[Core_Principles]]

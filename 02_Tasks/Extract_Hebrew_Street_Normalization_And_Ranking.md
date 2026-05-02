---
project: [[nearest-address-codes]]
status: done
priority: medium
created: 2026-05-02
type: task
---

# ⚡ Task: Extract Hebrew Street Normalization And Ranking

## 📋 Declarative Objective
- [ ] Make Hebrew street normalization and search ranking reusable, testable, and easier to maintain.

## 🎯 Definition of Done (Success Criteria)
- [ ] Normalization behavior is centralized instead of duplicated inline in action SQL/post-processing.
- [ ] Ranking logic has focused unit coverage for prefix, token, alias, city, contains, and distance ordering.
- [ ] Street search results remain compatible with current UI expectations.
- [ ] The implementation respects Hebrew search behavior and existing aliases.

## 🧪 Verification Gateway
- [ ] **Test Command:** `pnpm run test`
- [ ] **Build Command:** `pnpm run build`
- [ ] **Protocol:** Execute and verify exit code 0.

## 📝 Agent Implementation Plan
- Review `lib/hebrew-utils.ts` and existing search tests before adding new helpers.
- Move normalization/ranking helpers into `lib` or a domain module.
- Keep SQL changes conservative unless a DB function is already present or clearly warranted.

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** Added `lib/domain/street-search.ts` with reusable Hebrew street search normalization, token-aware scoring, alias/city matching, de-duplication, and distance ordering. Refactored `searchStreets` to delegate ranking to the helper and simplified street directory SQL by computing normalized fields once in a CTE. Added focused ranking tests and tightened existing action test typings.
- **Deviations:** Fixed an existing dead path where city ranking was referenced in post-processing but `normalized_city` was never selected by SQL. The refactor now allows city matches to participate in street search candidate selection.
- **Debt/Future:** The SQL normalization expression is still expressed in SQL so database filtering stays efficient; if this grows further, consider a DB function or generated normalized columns.
- **Verification Proof:** `pnpm exec vitest run __tests__/unit/lib/street-search.test.ts __tests__/unit/lib/streets.test.ts __tests__/unit/actions/addresses.test.ts` passed (21 tests). `pnpm run build` passed. Touched-file `tsc --noEmit` scan returned no diagnostics. `pnpm run test` remains blocked by local Postgres refusing `127.0.0.1:5433`/`::1:5433`.

## 🔗 Related Context
- **Project:** [[nearest-address-codes]]
- **Rules:** [[Core_Principles]]

---
project: [[nearest-address-codes]]
status: done
priority: medium
created: 2026-05-02
type: task
---

# ⚡ Task: Add Focused Tests For Trust Linked And Nearby Workflows

## 📋 Declarative Objective
- [ ] Strengthen coverage around the highest-risk business rules: Trust Engine approvals, linked address merging, and nearby ranking.

## 🎯 Definition of Done (Success Criteria)
- [ ] Trust Engine tests cover approval thresholds, duplicate voting, role-based auto-approval, and location cooldown/proximity behavior.
- [ ] Linked address tests cover verified links, pending links visible to creator, and primary address selection.
- [ ] Nearby result tests cover distance ordering and cache/offline assumptions where practical.
- [ ] Tests run deterministically without requiring production services.

## 🧪 Verification Gateway
- [ ] **Test Command:** `pnpm run test`
- [ ] **Protocol:** Execute and verify exit code 0.

## 📝 Agent Implementation Plan
- Review existing Vitest helpers before adding mocks.
- Add narrowly scoped unit tests for pure or mockable behavior.
- Avoid broad E2E coverage unless needed for confidence.

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** Added deterministic Vitest coverage for Trust Engine entrance-code voting, duplicate vote prevention, admin auto-approval, and location sample collection. Extracted linked-address merge/grouping logic into `lib/domain/linked-address-merge.ts` and covered verified/caller-visible pending merge behavior, primary selection, and transitive groups. Added cache utility tests for same-cell nearby reuse, TTL expiry, and offline backup addresses.
- **Deviations:** Kept the location workflow test aligned with current implementation, which collects refinement samples instead of enforcing the older proximity/cooldown helper path. Extracted route merge logic to make linked-address behavior testable without a database.
- **Debt/Future:** Full `pnpm run test` still requires local Postgres for existing integration tests on port 5433; those integration tests should either be gated behind setup or moved out of the default unit command.
- **Verification Proof:** `pnpm exec vitest run __tests__/unit/actions/versioning-workflows.test.ts __tests__/unit/lib/linked-address-merge.test.ts __tests__/unit/lib/cache-utils.test.ts` -> 3 files passed, 11 tests passed. `pnpm run build` -> compiled successfully. `pnpm run test` -> failed on pre-existing Postgres connection errors in integration tests (`ECONNREFUSED 127.0.0.1:5433` / `::1:5433`).

## 🔗 Related Context
- **Project:** [[nearest-address-codes]]
- **Rules:** [[Core_Principles]]

---
project: [[nearest-address-codes]]
status: done
priority: medium
created: 2026-05-02
type: bug
---

# ⚡ Task: Fix Redundant Double Fetch on Location Version Change

## 📋 Declarative Objective
- [ ] Remove the `mutate(undefined, { revalidate: true })` call from the `locationVersion` `useEffect` in `hooks/use-address-data.ts`.
- [ ] Keep the `localStorage.removeItem("sticky-address-info")` line (still needed to purge sticky state on location refresh).
- [ ] Remove `mutate` from the `useEffect` dependency array since it is no longer used inside.

## 🎯 Definition of Done (Success Criteria)
- [ ] On every location refresh (manual or GPS-triggered), exactly **one** request to `/api/addresses` fires — confirmed in the Network tab.
- [ ] Sticky address state is still cleared on location version change.
- [ ] `pnpm run build` exits with code 0 and no TypeScript errors.

## 🧪 Verification Gateway
- [ ] **Test Command:** `pnpm run build`
- [ ] **Protocol:** Execute and verify exit code 0.
- [ ] **Manual check:** Open Network tab, trigger a manual location refresh — confirm only 1 `/api/addresses` call fires (not 2).

## 📝 Agent Implementation Plan

### File: `hooks/use-address-data.ts` — lines 66–76

**Before:**
```ts
useEffect(() => {
    if (locationVersion > 0) {
        // Clear the SWR cache for any previous location keys and force revalidation
        mutate(undefined, { revalidate: true })
        // CRITICAL: Do NOT remove offline-backup-addresses here.
        // ...
        localStorage.removeItem("sticky-address-info") // Purge sticky state
    }
}, [locationVersion, mutate])
```

**After:**
```ts
useEffect(() => {
    if (locationVersion > 0) {
        localStorage.removeItem("sticky-address-info")
    }
}, [locationVersion])
```

**Why this is safe:** When `locationVersion` increments, the SWR key changes (it includes `&v=${locationVersion}`). SWR automatically fires a fresh fetch on key change — the explicit `mutate` is fully redundant. The `mutate(undefined, …)` also clears the in-progress fetch's pending state, effectively cancelling the first fetch and starting a second one for the same URL.

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** Removed `mutate(undefined, { revalidate: true })` from the `locationVersion` useEffect in `use-address-data.ts:66-76`. Also removed the now-unused `mutate` from the dependency array. `localStorage.removeItem("sticky-address-info")` kept intact.
- **Deviations:** None — plan executed exactly as specified.
- **Debt/Future:** None.
- **Verification Proof:** `pnpm run build` — ✓ Compiled successfully in 2.8s, 14/14 static pages generated, exit 0.

## 🔗 Related Context
- **Root Cause Analysis:** `.claude/plans/check-the-initial-nearest-linked-seahorse.md`
- **Affected Files:** `hooks/use-address-data.ts`

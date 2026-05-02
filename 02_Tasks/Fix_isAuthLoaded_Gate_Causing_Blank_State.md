---
project: [[nearest-address-codes]]
status: done
priority: high
created: 2026-05-02
type: bug
---

# ⚡ Task: Fix isAuthLoaded Gate Causing Blank State on Initial Load

## 📋 Declarative Objective
- [ ] Remove the `isAuthLoaded` guard from the SWR key condition in `hooks/use-address-data.ts` so the address fetch starts as soon as `userLocation` is available — regardless of Clerk's initialization state.
- [ ] Remove `userId` from the SWR key URL to keep the key stable (prevents a second fetch when auth loads for signed-in users).
- [ ] Update `app/api/addresses/route.ts` to use server-side `authUserId` instead of the client-provided `userId` query param in the `address_links` filter, so the data remains correct after removing `userId` from the URL.

## 🎯 Definition of Done (Success Criteria)
- [ ] On a return visit with a valid location cache, the skeleton shows **immediately** (no blank/empty-content flash before the API responds).
- [ ] Only **one** request to `/api/addresses` fires per page load for both authenticated and unauthenticated users — confirmed in the Network tab.
- [ ] Linked addresses (verified + the current user's own unverified ones) continue to display correctly for signed-in users.
- [ ] `pnpm run build` exits with code 0 and no TypeScript errors.

## 🧪 Verification Gateway
- [ ] **Test Command:** `pnpm run build`
- [ ] **Protocol:** Execute and verify exit code 0.
- [ ] **Manual check:** Open app in browser, reload with DevTools Network tab open — confirm single `/api/addresses` request, no blank-content flash.

## 📝 Agent Implementation Plan

### File 1: `hooks/use-address-data.ts` — line 44–45

**Before:**
```ts
(userLocation && isAuthLoaded) ? `/api/addresses?lat=${userLocation.lat}&lng=${userLocation.lng}${userId ? `&userId=${userId}` : ""}&v=${locationVersion}` : null,
```

**After:**
```ts
userLocation ? `/api/addresses?lat=${userLocation.lat}&lng=${userLocation.lng}&v=${locationVersion}` : null,
```

Keep `isAuthLoaded` and `userId` in the function signature for backward compatibility with callers — just stop wiring them into the SWR key.

### File 2: `app/api/addresses/route.ts` — line 183

**Before:**
```sql
OR (al.verified = FALSE AND al.created_by = ${userId ?? null})
```

**After:**
```sql
OR (al.verified = FALSE AND al.created_by = ${authUserId ?? null})
```

`authUserId` already exists in scope (line 29: `const { userId: authUserId } = await auth()`). This is a safe swap — for authenticated users the value is identical; for unauthenticated users both were `null`.

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** Removed `isAuthLoaded` from SWR key guard in `use-address-data.ts:44` — gate is now `userLocation ?` only. Removed `&userId=${userId}` from the SWR URL (key is now `?lat=X&lng=Y&v=N`). In `app/api/addresses/route.ts:183` changed `al.created_by = ${userId ?? null}` → `${authUserId ?? null}` to keep user-owned unverified link visibility correct via server-side auth.
- **Deviations:** None — plan executed exactly as specified.
- **Debt/Future:** The `isAuthLoaded` and `userId` params remain in the `useAddressData` function signature; can be removed in a follow-up cleanup once callers are audited.
- **Verification Proof:** `pnpm run build` — ✓ Compiled successfully in 2.8s, 14/14 static pages generated, exit 0.

## 🔗 Related Context
- **Root Cause Analysis:** `.claude/plans/check-the-initial-nearest-linked-seahorse.md`
- **Affected Files:** `hooks/use-address-data.ts`, `app/api/addresses/route.ts`

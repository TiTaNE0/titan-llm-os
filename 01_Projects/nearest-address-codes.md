
**Type:** Progressive Web App (PWA) for Israeli Couriers
**Status:** Active Development

---

## Product Surface

- Public courier workspace at `/` with List, Focus, and Zen modes.
- Leaderboard at `/leaderboard` for contributor score visibility.
- Moderation queue at `/moderation` for pending entrance codes, location updates, and linked-address requests.
- Admin user tooling at `/admin/users`.
- Admin address audit tooling at `/admin/addresses`.
- SafePath road-event reporting and nearby event panel.
- PWA/offline runtime for cached nearby data, queued submissions, push notifications, and background sync.

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| Framework | Next.js 16 (App Router) |
| Language | TypeScript (strict mode) |
| Styling | Tailwind CSS 4, tailwind-merge, clsx |
| UI | Radix UI primitives, shadcn/ui patterns |
| Database | PostgreSQL (Neon) via @neondatabase/serverless |
| Auth | Clerk roles, metadata, and webhooks |
| State/Fetching | SWR, React Hook Form, Zod |
| Real-time | STOMP over WebSockets |
| Testing | Vitest, Playwright |

---

## Core Mission

A crowdsourced mapping and delivery intelligence platform for Israeli couriers. The app enables:
- Submitting and verifying building entrance codes
- Updating delivery metadata, elevator details, and building comments
- Linking related addresses and shared entrances
- GPS coordinate refinement via background sampling (Zen Mode)
- Real-time road hazard reporting (SafePath)
- Offline-first data persistence with background sync

---

## Current Architecture

```
app/
├── actions/        # Server Actions, preferred mutation layer
├── api/            # REST route handlers, webhooks, cron, admin reads
└── (page routes)   # Next.js App Router pages

docs/rules/         # Domain specifications
components/         # UI components
hooks/              # Client behavior and location workflows
lib/                # DB, domain helpers, offline, push, SafePath, logging
.vault_link/        # Project management (Obsidian)
```

Key patterns:
- **Server Actions First:** Mutations prefer `app/actions/` over API routes.
- **Versioning System:** Staging tables such as `address_suggestions` and `entrance_codes` feed live data after Trust Engine approval.
- **Linked Address Merging:** `address_links` can collapse related entrances/buildings into a caller-visible response group.
- **Location Refinement:** `delivery_location_history` collects weighted samples for scheduled coordinate refinement.
- **Offline-First:** IndexedDB, local cache, and background sync protect courier workflows under weak connectivity.
- **Observability:** Route handlers use structured request logging through `lib/logger.ts`.

---

## Current Implementation Map

| Area | Primary Files |
|------|---------------|
| Address search and creation | `app/actions/addresses.ts`, `app/api/addresses/route.ts` |
| Trust Engine and moderation | `app/actions/versioning.ts`, `app/api/moderation/` |
| Linked addresses | `app/actions/linked-addresses.ts`, `lib/domain/linked-address-merge.ts` |
| Street search and Hebrew normalization | `lib/domain/street-search.ts`, `lib/domain/streets.ts`, `lib/hebrew-utils.ts` |
| Building metadata | `app/actions/building-metadata.ts` |
| SafePath | `components/safepath/`, `hooks/use-safepath-events.ts`, `lib/safepath-api.ts` |
| Offline and cache | `components/offline-provider.tsx`, `lib/indexed-db.ts`, `lib/offline-queue.ts`, `lib/cache-utils.ts` |
| Push notifications | `app/actions/push-subscriptions.ts`, `lib/push-client.ts`, `lib/notifications.ts` |
| Admin tooling | `app/admin/`, `app/api/admin/`, `components/admin-*` |
| Documentation | `README.md`, `app/actions/README.md`, `app/api/README.md`, `docs/rules/api-specification.md` |

---

## Active Milestone

**Staging hardening and documentation refresh** — The recent sprint completed homepage orchestration cleanup, street-domain consolidation, targeted type cleanup, Zod request validation, street-search helper extraction, route logging standardization, focused workflow tests, homepage bundle trimming, and README coverage expansion.

Current known verification caveat: the default `pnpm run test` command includes integration tests that expect a local PostgreSQL test database on port `5433`. `pnpm run build` passes; full tests require `pnpm run test:setup` before execution.

See: [[nearest-address-codes_Board]] for task tracking.

---

## Connections

- [[nearest-address-codes_Board]] — Kanban task board
- [[Core_Principles]] — Architectural mandates
- `README.md` — human-facing project overview
- `docs/rules/api-specification.md` — API and action contract index

## Knowledge Base

- [[Core_Principles]]

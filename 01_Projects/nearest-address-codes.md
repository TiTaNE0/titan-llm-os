
**Type:** Progressive Web App (PWA) for Israeli Couriers
**Status:** Active Development

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| Framework | Next.js 16 (App Router) |
| Language | TypeScript (strict mode) |
| Styling | Tailwind CSS 4, tailwind-merge, clsx |
| UI | Radix UI primitives, shadcn/ui patterns |
| Database | PostgreSQL (Neon) via @neondatabase/serverless |
| Auth | Clerk (currently in migration) |
| State/Fetching | SWR, React Hook Form, Zod |
| Real-time | STOMP over WebSockets |
| Testing | Vitest, Playwright |

---

## Core Mission

A crowdsourced mapping and delivery intelligence platform for Israeli couriers. The app enables:
- Submitting and verifying building entrance codes
- GPS coordinate refinement via background sampling (Zen Mode)
- Real-time road hazard reporting (SafePath)
- Offline-first data persistence with background sync

---

## Current Architecture

```
app/
├── actions/        # Server Actions (preferred for mutations)
├── api/            # REST API routes
└── (page routes)   # Next.js App Router pages

docs/rules/         # Domain specifications
components/         # UI components
.vault_link/        # Project management (Obsidian)
```

Key patterns:
- **Versioning System:** Staging tables (`address_suggestions`, `entrance_codes`) feed live tables after Trust Engine approval
- **Offline-First:** IndexedDB + background sync via SWR
- **Server Actions First:** All mutations prefer `app/actions/` over API routes

---

## Active Milestone

**Clerk → Argon2id Migration** — Currently transitioning from Clerk-managed auth to self-hosted Argon2id password hashing with JWT tokens. This includes migration of existing users and removal of Clerk dependencies.

See: [[nearest-address-codes_Board]] for task tracking.

---

## Connections

- [[nearest-address-codes_Board]] — Kanban task board
- [[Core_Principles]] — Architectural mandates

## Knowledge Base

- [[Core_Principles]]
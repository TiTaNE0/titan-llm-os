# Core Principles

> Architectural mandates for the PWA Courier platform.

## TypeScript-First

- Strict typing everywhere. No `any`.
- Enable `strict: true` in tsconfig.json.
- Use explicit return types for public functions.
- Avoid `as` casts; prefer type guards.

## Modular Design

- Logic must be separated from UI components.
- Business logic lives in `/lib`, `/services`, or `/domain`.
- UI components should be dumb—receive props, render UI, emit events.
- No inline business logic in components.

## Clean Code

- Use meaningful naming (`getPendingEntranceCodes` vs `getData`).
- Follow SOLID principles:
  - **S**ingle Responsibility: One function does one thing.
  - **O**pen/Closed: Open for extension, closed for modification.
  - **L**iskov Substitution: Subtypes must be substitutable.
  - **I**nterface Segregation: Small, focused interfaces.
  - **D**ependency Inversion: Depend on abstractions, not concretions.

## GPS-Ready

All location logic must account for:

1. **Signal Jitter:** GPS coordinates drift. Implement debounce and outlier filtering.
2. **Offline-First State:** Location submissions persist to IndexedDB when offline, sync when online.
3. **Weighted Centroid:** Aggregate multiple samples before committing coordinates.
4. **Graceful Degradation:** Map works without precise GPS; fall back to city/region.
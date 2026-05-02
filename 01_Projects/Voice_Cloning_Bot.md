# Voice Cloning Bot

**Type:** Telegram Bot with Hybrid TTS Architecture
**Status:** Active Development

---

## Tech Stack

| Layer                 | Technology                           |
| --------------------- | ------------------------------------ |
| Framework             | Python 3.11+, python-telegram-bot    |
| TTS Engine            | Qwen3-TTS-12Hz-1.7B-Base (local MPS) |
| Cloud                 | RunPod Serverless, Cloudflare R2     |
| Database              | SQLite (WAL mode)                    |
| Dependency Management | uv (workspace)                       |
| Containerization      | Docker, docker-compose               |
| Testing               | pytest, pytest-asyncio               |

---

## Core Mission

A professional-grade hybrid voice cloning and text-to-speech Telegram bot with:
- Multi-tenant support with per-user state machine and voice isolation
- Weighted credit economy (Lightning/Qwen: 1×, ElevenLabs: 25×)
- Triple-tier strategy: Developer Mode (local MPS), Premium (RunPod), ElevenLabs fallback
- Zero-friction onboarding with role selection
- Zero-binary data transfer via Cloudflare R2
- Instant voice cloning from 10-15s voice messages
- Persistent voice library with FK-enforced user isolation

---

## Current Architecture

```
bot/                  # Lightweight Telegram handler (Strategy Pattern)
worker/               # Heavyweight GPU worker (RunPod Serverless)
shared/               # Pydantic schemas and constants
docs/                 # Domain specifications
.vault_link/          # Project management (Obsidian)
```

Key patterns:
- **Multi-Tenant Access Control:** Comma-separated allow-lists via environment variables
- **State Machine:** Role-based onboarding (Video/Podcasts/Pranks)
- **Credit System:** Character-based with engine multipliers

---

## Active Milestone

**Voice Cloning Bot Initialization** — Setting up project management and documentation structure.

See: [[Voice_Cloning_Bot_Board]] for task tracking.

---

## Connections

- [[Voice_Cloning_Bot_Board]] — Kanban task board
- [[nearest-address-codes_Board]] — Master project board
- [[Core_Principles]] — Architectural mandates

## Knowledge Base

- [[Core_Principles]]

---

## Phase 1 Implementation Audit

**Date:** 2026-04-27
**Scope:** Onboarding & User Management

### Multi-Tenant State Machine & Onboarding
- **State Persistence:** Persisted in `users.state` column (`TEXT DEFAULT 'NEW'`). Transitions are atomic via `set_user_state()`.
- **Magic Moment:** `SmallestProvider.clone_voice()` is triggered during onboarding using `SMALLEST_LIGHTNING`. A demo synthesis is generated immediately and sent to the user before transitioning to `READY`.
- **0:00 Audio Header Bug:** Fixed upstream in the Smallest AI provider by explicitly setting the `Accept: audio/wav` request header. Audio is then converted to OGG (Opus) via FFmpeg before Telegram delivery.

### Database & Credit Economics
- **Schema:** `users` table contains `telegram_id`, `state`, `role_tag`, `lang`, `credits`, `created_at`. `lang` added via `ALTER TABLE` migration.
- **Credit Initialization:** New users receive **1000 credits**.
- **Infinite Money Glitch Prevention:** On data deletion, credits are reset to **50** (not 1000). This mitigates farming but lacks a `lifetime_resets` counter or progressive penalty.

### Zero-Latency Localization
- **`user_langs` Cache:** In-memory `dict[int, str]` on the `VoiceBot` instance for O(1) lookups.
- **English Fallback:** `get_texts()` merges dictionaries as `{**TEXTS_EN, **TEXTS_RU}`, ensuring Russian overrides English while missing keys safely fall back to English.

### The Privacy Loop & Deletion Queue
- **Retry Queue:** Implemented via `deletion_queue` table. A background worker (`_deletion_worker_loop`) polls every 24 hours with a max of 5 retry attempts per item.
- **Optimistic UI:** User receives an immediate `query.answer("Deleting...")` toast and a "done" message via `_safe_edit_message()` **before** external API/R2 cleanup completes. Cleanup happens asynchronously.

### UI Architecture
- **Settings Menu:** Hierarchical split confirmed — `🎛️ Audio Tuning` (Speed, Presets, Engine) and `👤 Account` (Language, Delete My Data).
- **Input Validation Wall:** During `WAITING_FOR_AUDIO`, text messages are explicitly rejected. Video notes (circles) are implicitly rejected because the handler only processes `voice` or `audio` attachments.

### Escape Hatch (`/start`)
- **`/start` acts as a hard reset.** If the user is `READY` with voices, normal menu is shown. For any other state, the user is forcefully reset to `NEW` and role selection is presented. This guarantees no user can be trapped in a broken intermediate state.

### Key Files
- `bot/src/bot/onboarding.py` — State machine & onboarding flow
- `bot/src/bot/database.py` — Schema, migrations, credit logic, deletion queue
- `bot/src/bot/app.py` — Bot instance, settings UI, deletion worker, `user_langs` cache
- `bot/src/bot/providers/smallest.py` — Smallest AI provider with WAV header fix
- `bot/src/bot/messages.py` — Localization dictionaries & `get_texts()` utility

---

## Phase 2 Implementation Audit

**Date:** 2026-04-27
**Scope:** Monetization via Telegram Stars

### Transaction Ledger
- **`transactions` table:** Stores every successful Stars payment with `provider_payment_charge_id` as PK (idempotency), `telegram_id` (FK), `stars_amount`, `credits_awarded`, `created_at`.
- **`award_credits_for_payment()`:** Atomic SQLite transaction — `BEGIN IMMEDIATE` → `INSERT transactions` → `UPDATE users SET credits` → `COMMIT`. Duplicate charge IDs trigger `IntegrityError`, rollback, and return `(False, balance)`.

### Product Tiers
- **Tier 1:** 50 Stars → 2,500 Credits
- **Tier 2:** 150 Stars → 10,000 Credits (Best value)
- **Tier 3:** 500 Stars → 50,000 Credits
- **UI Flow:** `[💎 Balance/Buy]` → tier selection Inline Keyboard → `send_invoice(currency="XTR", provider_token="")`

### Payment Handlers
- **`pre_checkout_handler`:** Answers `ok=True` within 10s; catches errors with `ok=False`.
- **`successful_payment_handler`:** Extracts `telegram_payment_charge_id`, resolves tier from payload, calls `award_credits_for_payment()`. User receives confirmation with credit amount. User `state` is never modified.

### Localization
- All payment keys added to `TEXTS_EN` and `TEXTS_RU`: `menu_buy_credits_title`, `tier_btn_tier1/2/3`, `invoice_title_tier1/2/3`, `invoice_desc_tier1/2/3`, `payment_success`, `payment_failed`, `payment_already_processed`.

### Tests
- `tests/test_database_new.py` — 6 transaction tests (table schema, record, idempotency, atomic award, state preservation)
- `tests/test_payments.py` — 6 handler tests (registration, pre-checkout ok/error, successful payment, idempotency, tier constants)

### Key Files
- `bot/src/bot/database.py` — `transactions` table, `record_transaction()`, `award_credits_for_payment()`
- `bot/src/bot/app.py` — `TIERS`, `onboard_buy_credits()`, `handle_tier_selection()`, `pre_checkout_handler`, `successful_payment_handler`
- `bot/src/bot/messages.py` — Payment localization strings
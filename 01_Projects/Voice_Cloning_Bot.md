# Voice Cloning Bot

**Type:** Telegram Bot with Hybrid TTS Architecture
**Status:** Active Development

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| Framework | Python 3.11+, python-telegram-bot |
| TTS Engine | Qwen3-TTS-12Hz-1.7B-Base (local MPS) |
| Cloud | RunPod Serverless, Cloudflare R2 |
| Database | SQLite (WAL mode) |
| Dependency Management | uv (workspace) |
| Containerization | Docker, docker-compose |
| Testing | pytest, pytest-asyncio |

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

See: [[Voice_Bot_Board]] for task tracking.

---

## Connections

- [[Voice_Bot_Board]] — Kanban task board
- [[nearest-address-codes_Board]] — Master project board
- [[Core_Principles]] — Architectural mandates

## Knowledge Base

- [[Core_Principles]]
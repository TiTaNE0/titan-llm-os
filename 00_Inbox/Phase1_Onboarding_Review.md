---
project: [[Voice_Cloning_Bot]]
source: Phase 1 Onboarding Implementation Review
created: 2026-04-27
type: Inbox draft
---

# Phase 1 Implementation Review: Voice Twin Bot

**Date:** 2026-04-27
**Reviewer:** Senior Developer / System Architect
**Scope:** Onboarding & User Management (Phase 1)

---

## 1. Multi-Tenant State Machine & Onboarding

### State Persistence
State is persisted in the **`users.state`** column (`TEXT DEFAULT 'NEW'`).

**File:** `bot/src/bot/database.py`
```python
async def set_user_state(self, user_id: int, state: str):
    db = self._db
    await db.execute(
        "INSERT OR IGNORE INTO users (telegram_id) VALUES (?)", (user_id,)
    )
    await db.execute(
        "UPDATE users SET state = ? WHERE telegram_id = ?",
        (state, user_id),
    )
    await db.commit()
```

**Transition Audit:**
- `NEW` → `WAITING_FOR_ROLE`: Triggered by `/start` (`onboarding.py`).
- `WAITING_FOR_ROLE` → `WAITING_FOR_AUDIO`: Triggered by role selection callback.
- `WAITING_FOR_AUDIO` → `READY`: Triggered after the Magic Moment demo is successfully sent.

### "Magic Moment" — SmallestProvider.clone_voice()
**Confirmed active.** During onboarding, the bot calls the router to clone the uploaded voice using `SMALLEST_LIGHTNING` and immediately synthesizes a demo.

**File:** `bot/src/bot/onboarding.py`
```python
provider_metadata = await self.router.clone_voice_for(
    EngineNames.SMALLEST_LIGHTNING, user_id, audio_bytes, display_name
)
demo_text = self.get_demo_text(TEXTS)
settings = {"temperature": 0.7, "speed": 1.0}
audio_path = await self.router.generate(
    user_id, demo_text, active_voice, settings
)
with open(audio_path, "rb") as audio_file:
    await update.message.reply_voice(voice=audio_file, caption=demo_text)
await self.db.set_user_state(user_id, UserState.READY)
```

### Audio Header Repair (0:00 Duration Bug)
**Fix is implemented upstream in the provider.** The 0:00 duration bug was caused by missing `Accept: audio/wav` headers on the Smallest AI synthesis endpoint. The provider now explicitly requests WAV.

**File:** `bot/src/bot/providers/smallest.py`
```python
headers = {
    "Authorization": f"Bearer {self.api_key}",
    "Content-Type": "application/json",
    "Accept": "audio/wav",  # Prevents raw PCM / 0:00 duration
}
```

---

## 2. Database & Credit Economics

### `users` Table Schema
**Confirmed.** The `users` table includes all required fields.

**File:** `bot/src/bot/database.py`
```sql
CREATE TABLE IF NOT EXISTS users (
    telegram_id INTEGER PRIMARY KEY,
    state TEXT DEFAULT 'NEW',
    role_tag TEXT,
    lang TEXT DEFAULT NULL,
    credits INTEGER DEFAULT 1000,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

- `lang` was added via migration: `ALTER TABLE users ADD COLUMN lang TEXT DEFAULT NULL`.
- `credits` default is **1000** for brand-new users.

### "Infinite Money Glitch" Prevention
**Addressed, but with a simple mechanism rather than a counter.**

There is **NO** `lifetime_resets` column and **NO** explicit "returnee bonus" tier system. However, the deletion logic prevents credit farming by resetting to **50 credits** instead of 1000.

**File:** `bot/src/bot/database.py`
```python
# 4. Reset user to NEW state with 50 credits (anti-abuse)
await db.execute(
    "UPDATE users SET state = 'NEW', role_tag = NULL, credits = 50 WHERE telegram_id = ?",
    (user_id,)
)
```

**Status:** The "glitch" is mitigated, but a dedicated `lifetime_resets` counter or progressive penalty (e.g., 50 → 25 → 10) is **not yet implemented**.

---

## 3. Zero-Latency Localization

### In-Memory `user_langs` Cache
**Confirmed.** Implemented as a simple `dict` on the `VoiceBot` class.

**File:** `bot/src/bot/app.py`
```python
self.user_langs: dict[int, str] = {}
```

### `get_texts()` English Fallback
**Confirmed.** The Russian dictionary is merged *over* the English dictionary, ensuring English is the fallback for any missing keys.

**File:** `bot/src/bot/messages.py`
```python
def get_texts(lang: str = None):
    if lang is None:
        lang = os.getenv("BOT_LANG", "EN")
    lang = lang.upper()
    if lang.startswith("RU"):
        return {**TEXTS_EN, **TEXTS_RU}  # RU overrides EN; missing keys fall back to EN
    return TEXTS_EN
```

---

## 4. The Privacy Loop & Deletion Queue

### Retry Queue (Background Task)
**Implemented.** External deletions are **NOT** best-effort single attempts. A background worker polls a `deletion_queue` table every 24 hours with a max retry of 5 attempts.

**File:** `bot/src/bot/database.py`
```sql
CREATE TABLE IF NOT EXISTS deletion_queue (
    id TEXT PRIMARY KEY,
    user_id INTEGER,
    provider_voice_id TEXT,
    engine_id TEXT,
    r2_storage_path TEXT,
    attempts INTEGER DEFAULT 0,
    status TEXT DEFAULT 'PENDING',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**File:** `bot/src/bot/app.py`
```python
async def _deletion_worker_loop(self):
    """Background worker that polls deletion_queue every 24 hours."""
    while True:
        try:
            await self._process_deletion_queue()
        except Exception as e:
            logger.error(f"Deletion worker error: {e}")
        await asyncio.sleep(86400)
```

### Optimistic UI
**Confirmed.** The user receives immediate confirmation.

**File:** `bot/src/bot/app.py`
```python
# Show "deleting..." toast immediately (optimistic UI)
await query.answer(TEXTS["privacy_deleting"])

# Wipe internal DB and queue external cleanup
await self.db.delete_all_user_data(user_id)

# Show "done" message immediately
await self._safe_edit_message(query, TEXTS["privacy_done_md"], parse_mode="MarkdownV2")
```

---

## 5. UI Architecture

### Hierarchical Settings Menu
**Confirmed.** The Settings Hub is split into `🎛️ Audio Tuning` and `👤 Account`.

**File:** `bot/src/bot/app.py`
```python
keyboard = [
    [
        InlineKeyboardButton(
            TEXTS["settings_btn_audio"], callback_data="settings_audio"
        )
    ],
    [
        InlineKeyboardButton(
            TEXTS["settings_btn_account"], callback_data="settings_account"
        )
    ],
]
```

### Input Validation Wall
**Confirmed active.** During `WAITING_FOR_AUDIO`:
- **Text messages** are explicitly rejected.
- **Video notes (circles)** and other non-audio types are implicitly rejected because the handler only looks for `voice` or `audio` attachments.

**File:** `bot/src/bot/onboarding.py`
```python
if state == UserState.WAITING_FOR_AUDIO:
    await update.message.reply_text(TEXTS["onboarding_send_voice"])
    return True
```

---

## 🧪 Verification: Schema & Escape Hatch

### Database Schema (Current)

```sql
CREATE TABLE IF NOT EXISTS users (
    telegram_id INTEGER PRIMARY KEY,
    state TEXT DEFAULT 'NEW',
    role_tag TEXT,
    lang TEXT DEFAULT NULL,
    credits INTEGER DEFAULT 1000,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS user_settings (
    user_id INTEGER PRIMARY KEY,
    active_engine TEXT DEFAULT 'LOCAL_QWEN'
);

CREATE TABLE IF NOT EXISTS voice_profiles (
    id TEXT PRIMARY KEY,
    user_id INTEGER,
    engine_id TEXT,
    display_name TEXT,
    provider_voice_id TEXT,
    r2_storage_path TEXT,
    is_active BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(telegram_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS user_gen_settings (
    user_id INTEGER PRIMARY KEY,
    temperature REAL DEFAULT 0.7,
    speed REAL DEFAULT 1.0,
    preset_name TEXT DEFAULT 'Custom',
    last_text TEXT
);

CREATE TABLE IF NOT EXISTS inline_queries (
    result_id TEXT PRIMARY KEY,
    user_id INTEGER,
    query_text TEXT,
    chat_id INTEGER,
    message_id INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS deletion_queue (
    id TEXT PRIMARY KEY,
    user_id INTEGER,
    provider_voice_id TEXT,
    engine_id TEXT,
    r2_storage_path TEXT,
    attempts INTEGER DEFAULT 0,
    status TEXT DEFAULT 'PENDING',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### State Router & Escape Hatch Logic

**File:** `bot/src/bot/onboarding.py`
```python
async def start_onboarding(self, update: Update, context: ContextTypes.DEFAULT_TYPE, TEXTS: dict) -> bool:
    """Escape Hatch: /start always brings the user to a safe, deterministic state."""
    user_id = update.effective_user.id
    state = await self.db.get_user_state(user_id)

    voices = await self.db.get_user_voices(user_id)
    if state == UserState.READY and voices:
        return False  # App handles normal menu

    # Otherwise: HARD RESET to NEW and restart onboarding fresh.
    await self.db.set_user_state(user_id, UserState.NEW)
    await self._show_role_selection(update, context, TEXTS)
    return True
```

---

## Summary & Recommendations

| Concern | Status | Notes |
|---|---|---|
| State persistence | ✅ | Stored in `users.state`, transitions are atomic. |
| Magic Moment (Smallest AI) | ✅ | `clone_voice()` + immediate demo synthesis. |
| 0:00 Audio Header Bug | ✅ | Fixed via `Accept: audio/wav` header. |
| `users` table fields | ✅ | `state`, `lang`, `role_tag`, `credits` all present. |
| Infinite Money Glitch | 🟡 **Mitigated** | Resets to 50 credits. Recommend adding `lifetime_resets` counter. |
| `user_langs` cache | ✅ | In-memory `dict` on bot instance. |
| English fallback | ✅ | `{**EN, **RU}` merge pattern. |
| Deletion Retry Queue | ✅ | `deletion_queue` + 24h background worker, max 5 retries. |
| Optimistic UI | ✅ | Immediate toast + "done" message before background cleanup. |
| Settings Hierarchy | ✅ | Split into Audio Tuning and Account. |
| Input Validation Wall | ✅ | Text rejected explicitly; video notes rejected implicitly. |
| Escape Hatch (`/start`) | ✅ | Hard-resets to `NEW` unless user is `READY` with voices. |

**Recommended Enhancement:** Consider adding a `lifetime_resets INTEGER DEFAULT 0` column to the `users` table and decrementing the returnee bonus (e.g., 1000 → 50 → 25 → 10 → 0) to fully close the credit farming vector.

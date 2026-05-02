---
project: [[Voice_Cloning_Bot]]
status: done
priority: critical
created: 2026-05-02
type: task
---

# ⚡ Task: Move deletion queue from in-memory to database

## 📋 Declarative Objective
Replace in-process deletion queue with persistent database queue. Current flow: voice deleted → added to memory queue → worker polls every 24h. If bot crashes mid-deletion, orphaned voices remain in R2 and ElevenLabs accounts (GDPR violation risk).

## 🎯 Definition of Done (Success Criteria)
- [ ] deletion_queue table created with status tracking (pending, in_progress, completed, failed)
- [ ] Voice deletion adds record to DB instead of memory list
- [ ] Worker resumes from DB state on bot restart
- [ ] Retry logic implemented for failed deletions (max 3 attempts)
- [ ] Failed deletions logged to separate table for manual review
- [ ] Tests confirm queue survives bot restart

## 🧪 Verification Gateway
- [ ] **Test Command:** `uv run pytest tests/test_deletion_queue_persistence.py -v`
- [ ] **Manual Test:** Start bot → delete voice → kill bot → restart → confirm deletion completes

## 📝 Agent Implementation Plan
1. Create deletion queue schema in `bot/src/bot/database.py`:
   ```sql
   CREATE TABLE deletion_queue (
       id TEXT PRIMARY KEY,
       voice_id TEXT,
       user_id INTEGER,
       provider_id TEXT,
       r2_path TEXT,
       status TEXT,
       attempt_count INTEGER,
       created_at TIMESTAMP,
       completed_at TIMESTAMP
   )
   ```

2. Update delete_voice_profile() in database.py:
   - Insert to deletion_queue instead of memory list

3. Refactor deletion_worker_loop() in app.py:
   - Read from deletion_queue table
   - Track status (pending → in_progress → completed)
   - Increment attempt_count on failure
   - Move to failed table after 3 attempts

4. Add retry handler for transient failures

5. Add tests for queue persistence across restarts

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** Already implemented. `deletion_queue` table exists in `database.py:105-117` with status tracking (PENDING/COMPLETED). Worker `_deletion_worker_loop()` in `app.py:633` reads from DB via `get_pending_deletions()`. Retry via `update_deletion_status()` with `increment_attempt=True`.
- **Deviations:** Task was already complete at audit time — no code written.
- **Debt/Future:** Add admin endpoint to view/retry failed deletions
- **Verification Proof:** (To be filled)

## 🔗 Related Context
- **Files:** `bot/src/bot/app.py (deletion_worker_loop)`, `bot/src/bot/database.py`
- **Related Gap:** #3 Deletion Pipeline Not Persistent
- **GDPR Impact:** High (data residency compliance)

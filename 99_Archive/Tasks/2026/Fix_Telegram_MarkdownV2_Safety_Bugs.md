---
project: [[Voice_Cloning_Bot]]
status: done
priority: medium
created: 2026-05-02
type: task
---

# ⚡ Task: Fix Telegram MarkdownV2 Safety Bugs

## 📋 Declarative Objective
- [ ] Audit Telegram bot messages, captions, and inline responses that use `parse_mode="MarkdownV2"` for malformed markup and unsafe fallback text.
- [ ] Patch any broken templates or plain-text fallbacks that can trigger Telegram entity parse failures.
- [ ] Add a reusable agent-facing skill so future edits follow the same safety rules.

## 🎯 Definition of Done (Success Criteria)
- [ ] The delete-data confirmation message renders without MarkdownV2 parse errors.
- [ ] The inline generating message and credit-screen message are MarkdownV2-safe.
- [ ] A new skill exists for agent use when editing Telegram MarkdownV2 content.

## 🧪 Verification Gateway
- [ ] **Test Command:** `.venv/bin/python - <<'PY' ...` MarkdownV2 structural scan over `bot/src/bot/messages.py`
- [ ] **Protocol:** Execute and verify exit code 0.

## 📝 Agent Implementation Plan
- Inspect all `_md` strings for balanced markup and escaped punctuation.
- Review `parse_mode="MarkdownV2"` callsites for unsafe `TEXTS.get(..., fallback)` usage.
- Patch the message templates and create a narrow skill for future agent runs.

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** Closed the delete-data confirmation bold marker, fixed the inline generating template, escaped the credits development text, and removed a risky MarkdownV2 fallback in the buy-credits screen. Added `telegram-markdownv2-safety` skill under the Codex skills store.
- **Deviations:** The task expanded from a single broken delete flow into a small safety sweep because the same MarkdownV2 failure mode was present in multiple templates.
- **Debt/Future:** Add a CI or test guard that scans `_md` templates and plain-text fallbacks rendered with MarkdownV2 so new regressions fail fast.
- **Verification Proof:** `EN issues 0` / `RU issues 0` from the MarkdownV2 structural scan.

## 🔗 Related Context
- **Skills:** [[telegram-markdownv2-safety]]

# Twitter Module — Failure Log

> Append-only record of drafts where AI output drifted from `voice_evgeny.md`. Used as evidence for future voice file iteration. User appends manually; no agent should auto-edit this file.

## Format

```
## YYYY-MM-DD: <short_id>
- **Draft:** [[draft_filename]]
- **Drift type:** (e.g., "inserted 'ofc' against anti-mannerism rule")
- **AI source:** Grok / Claude / Codex / etc.
- **Original (user's draft):** > snippet
- **Drifted (AI output):** > snippet
- **Voice rule violated:** cite section from voice_evgeny.md (e.g., `<phrase_bank>` anti-mannerism)
- **Resolution:** kept / fixed / shipped anyway
```

---

## Entries

(none yet)

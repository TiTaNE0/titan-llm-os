# Observability & Metrics

> **Principle:** Daily logs are for humans. Telemetry is for machines. Both exist; don't conflate them.

---

## Two Streams

### Human Logs — `04_Logs/<YYYY-MM-DD>.md`
Markdown, narrative, decision-oriented. Read by you to remember "why did we do X?".

### Machine Telemetry — `04_Logs/Telemetry/<YYYY-MM>.jsonl`
JSONL, append-only, one event per line. Read by `/metrics` to compute aggregates.

Every macro execution produces both. The human log gets a 1-line entry; telemetry gets a structured record (schema in [[Tool_Registry]] § "Telemetry Schema").

---

## What Gets Logged

| Event | Human Log | Telemetry |
|-------|:---------:|:---------:|
| Task created | ✅ | ✅ |
| Task closed | ✅ | ✅ |
| Macro start/end | ❌ | ✅ |
| Tool invocation | ❌ | ✅ (write tools only) |
| Error fired | ✅ (link to report) | ✅ |
| Delegation handoff | ✅ | ✅ |
| Synthesis run | ✅ (summary) | ✅ |
| User chat noise | ❌ | ❌ |

Telemetry never includes raw user content. Only macro/tool metadata + hashed args.

---

## `/metrics` Macro

```
/metrics [period]
```

`period` ∈ {`day`, `week`, `month`}; defaults to `week`.

**Outputs:**
1. Console table:
   ```
   MACRO              COUNT  SUCCESS%  AVG_MS  ERRORS
   /new_task          12     100%      87      0
   /close_task        9      89%       2_340   1 (E2)
   /synthesize        1      100%      18_500  0
   ```
2. CSV dump to `04_Logs/Telemetry/reports/<period>_<date>.csv`
3. Top error classes for the period
4. Outliers (macros taking > 3σ longer than median)

---

## Privacy Boundaries

- Telemetry records hash arg payloads (`sha1`)
- No file contents, only paths
- No user prompts, only macro names
- Errors include the error class (E1–E5) but not the raw stack/output (that lives in the Error Report)

This way, telemetry can be shipped (e.g., synced via iCloud) without exposing the work itself.

---

## Retention

- `04_Logs/Telemetry/<YYYY-MM>.jsonl` — kept indefinitely (cheap)
- `04_Logs/Telemetry/reports/` — generated on demand; safe to delete
- Telemetry never auto-prunes. If you want to compact, archive whole months under `Telemetry/archive/`.

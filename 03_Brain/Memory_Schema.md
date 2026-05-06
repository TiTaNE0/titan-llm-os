# Memory Schema (Synthesis-Based Memory)

> **Karpathy's Rule:** *"Memory shouldn't be retrieval; memory should be synthesis."*

Raw logs in `04_Logs/` are the journal. This schema defines how those logs get compiled into structured, queryable, decay-aware facts in `03_Brain/Weekly_Synthesis/`.

---

## 1. Fact Record Schema

Every extracted fact is a JSON object with this shape:

```json
{
  "id": "fact_2026-05-04_001",
  "claim": "Wiki-Link mandate prevents broken cross-references in Obsidian graph view",
  "source_logs": ["04_Logs/2026-04-22.md", "04_Logs/2026-05-01.md"],
  "first_observed": "2026-04-22",
  "last_cited": "2026-05-01",
  "citations": 3,
  "confidence": 0.85,
  "tags": ["architecture", "obsidian", "wiki-links"],
  "status": "active",
  "promoted_to": null
}
```

### Field Definitions

- **id** — `fact_YYYY-MM-DD_NNN` (date of first synthesis run, sequential)
- **claim** — One declarative sentence. Must be falsifiable.
- **source_logs** — All log files that support this fact (maintained on each citation)
- **first_observed / last_cited** — ISO dates
- **citations** — Count of times this fact was reinforced in subsequent logs
- **confidence** — 0.0–1.0; starts at 0.5, +0.1 per citation, −0.2 per contradiction
- **tags** — Free-form taxonomy
- **status** — `active` | `archived` | `promoted` | `contradicted`
- **promoted_to** — If status=promoted, path to the Brain rule it became (e.g., `03_Brain/Architecture_Notes/Core_Principles.md#wiki-links`)

---

## 2. Lifecycle: Ingest → Query → Lint

### Ingest (weekly, via `/synthesize`)
1. Read all logs in current ISO week
2. Extract candidate claims (LLM analysis)
3. Match against existing facts in `Weekly_Synthesis/facts.jsonl`:
   - **Match found** → increment citations, update last_cited, add to source_logs
   - **No match** → create new fact at confidence 0.5
   - **Direct contradiction** → both facts get status=contradicted, flag for Architect review

### Query (any time, via context injection)
- Latest synthesis JSON loaded into context at handshake (Step 8 of Context Injection Protocol)
- Agents query by tag, status, or confidence threshold

### Lint (weekly, end of `/synthesize`)
- Apply decay rules (Section 3)
- Detect duplicate claims (similarity > 0.9) → propose merge
- Output report: facts added / promoted / archived / contradicted

---

## 3. Decay Rules

| Condition | Action |
|-----------|--------|
| `last_cited` > 90 days ago AND citations < 2 | status = `archived` |
| citations ≥ 5 AND confidence ≥ 0.8 | propose status = `promoted` (halt for Architect) |
| Two facts with status=`contradicted` | halt; surface to user for resolution |
| confidence < 0.2 | status = `archived` |

Archived facts move to `03_Brain/Weekly_Synthesis/archive/<year>.jsonl`. They remain queryable via `/trace` but are excluded from default context injection.

---

## 4. Storage Layout

```
03_Brain/Weekly_Synthesis/
├── facts.jsonl              # Active facts (append-mostly, line-delimited JSON)
├── 2026-W18.synthesis.md    # Human-readable weekly report
├── 2026-W18.synthesis.json  # Structured: facts_added, contradictions, proposals
├── ...
└── archive/
    └── 2026.jsonl           # Archived facts by year
```

The weekly `.md` is for humans. The `.jsonl` is the canonical fact store.

---

## 5. Promotion Path (Fact → Core Principle)

When a fact reaches the promotion threshold:
1. `/synthesize` adds it to that week's `proposals[]` array
2. **HALT** — Synthesizer outputs proposal and waits
3. Architect reviews, runs `/graduate` to formalize
4. Fact's `promoted_to` field is set to the destination rule path
5. Fact remains in `facts.jsonl` with status=`promoted` for traceability

---

## 6. What NOT to Synthesize

- Trivial state changes ("task X moved to Done")
- Pure timestamps without claims
- User chitchat / off-topic exchanges
- Tool error messages (those go to error reports, not memory)

The signal-to-noise filter is: **"Would this fact change a future decision?"** If no, don't synthesize it.

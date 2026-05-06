---
project: [[TiTan_LLM_OS]]
status: in_progress
priority: medium
created: 2026-05-04
started: 2026-05-05
type: task
tier: 3
---

# ⚡ Task: Add Observability & Metrics

## 📋 Declarative Objective
- [ ] Add structured machine-readable telemetry alongside human-readable daily logs. Enable `/metrics [period]` reports for success rate, macro duration, error breakdown.

## 🎯 Definition of Done (Success Criteria)
- [ ] `04_Logs/Telemetry/` directory exists with JSONL append-only files
- [ ] Every macro execution writes a telemetry record
- [ ] `/metrics [day|week|month]` macro registered
- [ ] First `/metrics week` report runs successfully

## 🧪 Verification Gateway
- [ ] **Test Command:** `/metrics week`
- [ ] **Protocol:** Output table: macro / count / success_rate / avg_ms / errors. Exit code 0.

## 📝 Agent Implementation Plan
1. ✅ Define telemetry record schema (timestamp, macro, status, duration_ms, error_class, persona) — see [[Observability]] § Telemetry Schema
2. ✅ Create `04_Logs/Telemetry/` with month-rotated JSONL files
3. ✅ Create `.scripts/emit_telemetry.sh` helper (best-effort, never blocks)
4. ✅ Add **Macro Execution Contract** to [[System_Agents]] § 1.2 (universal rule: every macro emits)
5. ✅ Instrument exemplar macros (`/close_task`, `/new_task`, `/metrics`) with explicit `Telemetry:` step
6. ✅ Implement `.scripts/metrics_aggregate.sh` (jq-based aggregation, day/week/month windows)
7. ✅ Wire `/metrics` kernel macro to call the canonical script
8. ⏳ Backfill explicit `Telemetry:` line into remaining macros (currently inherit via Macro Execution Contract; explicit lines optional)
9. ⏳ Verify retention plan (currently: keep all jsonl indefinitely, archive on demand)

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** Two scripts in `.scripts/` (`emit_telemetry.sh`, `metrics_aggregate.sh`); kernel section 1.2 Macro Execution Contract; 3 macros instrumented explicitly; canonical `/metrics` runs in <100ms with jq pipeline.
- **Deviations:** Skipped per-macro explicit `Telemetry:` line for all 17 macros — Macro Execution Contract covers it universally; only added explicit lines as exemplars on the 3 most-used macros.
- **Debt/Future:** macOS-specific (`date`, `python3`, `jq`); script is best-effort only; report retention not yet automated; no anomaly detection (planned outliers section just shows top counts).
- **Verification Proof:** `/metrics week` produced clean table with 2 macros / 3 records / 100% success rate. CSV at `04_Logs/Telemetry/reports/week_2026-05-05.csv`.

## 🔗 Related Context
- **Best Practice:** Microsoft Agent Framework middleware; Google ADK observability
- **Plan File:** Section 3.8

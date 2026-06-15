#!/usr/bin/env bash
# smoke_orchestrator_tick.sh
#
# Verification brick for Orchestrator_C1 — the deterministic tick infrastructure:
# run_digest.sh (REPORT) and the config schema. The dispatch step itself is agent
# orchestration (driven by /loop at runtime) and is exercised live, not here; this
# smoke covers the scriptable parts the tick depends on. Temp-isolated.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
RD="$REPO_ROOT/.scripts/run_digest.sh"
CFG="$REPO_ROOT/00_Templates/Orchestrator_Config_Template.yaml"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
DD="$TMP/digest"
fail() { echo "FAIL: $1" >&2; exit 1; }

# --- run_digest: create + header + append, id sanitized ---------------------
F="$("$RD" --run-id "run/2026-06-15.1" --line "tick_start scope=TiTan_LLM_OS" --digest-dir "$DD")" \
  || fail "run_digest first call errored"
[[ -f "$F" ]] || fail "digest file not created"
[[ "$(basename "$F")" == "run_2026-06-15.1.md" ]] || fail "run id not sanitized in filename: $(basename "$F")"
grep -q '^# Orchestrator Run run/2026-06-15.1' "$F" || fail "digest header missing/wrong"

"$RD" --run-id "run/2026-06-15.1" --line "dispatch [[T]] execute_task -> queued spec_gate" --digest-dir "$DD" >/dev/null \
  || fail "run_digest second call errored"
n="$(grep -c '^- ' "$F")"
[[ "$n" -eq 2 ]] || fail "expected 2 digest lines, got $n"
grep -qF 'queued spec_gate' "$F" || fail "second digest line content missing"
# ISO-8601 stamp on each line
grep -qE '^- [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z \| ' "$F" || fail "digest line missing ISO timestamp"

# --- run_digest: missing args -> E2 ----------------------------------------
rc=0; "$RD" --run-id only 2>/dev/null || rc=$?
[[ "$rc" -eq 2 ]] || fail "missing --line should exit 2, got $rc"

# --- config schema: required keys present ----------------------------------
[[ -f "$CFG" ]] || fail "config template missing"
for k in 'scope:' 'max_tasks_per_run:' 'host:' 'dispatch:' 'degraded_spec_gate:'; do
  grep -qE "^$k" "$CFG" || fail "config template missing key: $k"
done
# host is the subscription loop, not an API-credit path
grep -qE '^host: loop$' "$CFG" || fail "config host must be 'loop'"
# at least one scope entry
grep -qE '^  - .+' "$CFG" || fail "config scope must list >=1 project"

echo "SMOKE: OK"

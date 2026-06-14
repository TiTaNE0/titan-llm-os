#!/usr/bin/env bash
# smoke_queue_attention.sh
#
# Verification Gateway for Orchestrator_A3_Needs_Attention_Queue.
# Appends 2 distinct entries and verifies both appear with the documented format
# (wiki-link, ISO-8601 timestamp, state + reason fields); proves the idempotent
# no-op on a duplicate; and confirms a malformed-args invocation exits non-zero.
#
# Runs against TEMP COPIES in an isolated temp vault — never touches the live
# Needs_Attention.md.
#
# Exit 0 = all assertions pass.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRIPTS="$REPO_ROOT/.scripts"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/.scripts" "$TMP/00_Templates" "$TMP/04_Logs/Telemetry"
cp "$SCRIPTS/queue_attention.sh" "$SCRIPTS/persona_check.sh" "$SCRIPTS/emit_telemetry.sh" "$TMP/.scripts/"
cp "$REPO_ROOT/00_Templates/Needs_Attention_Template.md" "$TMP/00_Templates/" 2>/dev/null || true
# Executioner session so persona_check passes (singleton fallback, no env var).
printf '{\n  "persona": "Executioner",\n  "session_id": "smoke",\n  "started_at": "2026-06-14T00:00:00Z",\n  "agent_surface": "test"\n}\n' > "$TMP/.session_state.json"

S="$TMP/.scripts"
Q="$TMP/Needs_Attention.md"
fail() { echo "FAIL: $1" >&2; exit 1; }

# --- 1. Append two distinct entries ----------------------------------------
"$S/queue_attention.sh" --task "Alpha_Task" --state spec_gate --source orchestrator \
  --run-id run-001 --reason "spec needs human review" --source-persona Executioner --queue-file "$Q" >/dev/null \
  || fail "first append failed"
"$S/queue_attention.sh" --task "[[Beta_Task]]" --state retries_exhausted --source failure_panel \
  --run-id run-002 --reason "3 build loops, no convergence" --source-persona Executioner --queue-file "$Q" >/dev/null \
  || fail "second append failed"

# --- 2. Both entries present with documented format ------------------------
grep -qF "[[Alpha_Task]]" "$Q" || fail "Alpha wiki-link missing"
grep -qF "[[Beta_Task]]"  "$Q" || fail "Beta wiki-link missing (bracket-stripping broke)"
grep -qF "state: spec_gate "        "$Q" || fail "Alpha state field missing"
grep -qF "state: retries_exhausted " "$Q" || fail "Beta state field missing"
grep -qF "reason: spec needs human review"      "$Q" || fail "Alpha reason missing"
grep -qF "reason: 3 build loops, no convergence" "$Q" || fail "Beta reason missing (comma in reason broke parsing)"
# ISO-8601 UTC timestamp present on entry lines (PRD field name: queued).
grep -qE '\| queued: [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z \|' "$Q" || fail "ISO-8601 queued timestamp missing/malformed"
# PRD field name run_id present.
grep -qF "run_id: run-001 " "$Q" || fail "run_id field missing (PRD §5 vocabulary)"
# Exactly two open entries so far.
OPEN=$(awk '/^## Open/{f=1;next} f' "$Q" | grep -c '^- \[ \]')
[[ "$OPEN" -eq 2 ]] || fail "expected 2 open entries, got $OPEN"

# --- 3. Idempotent no-op on duplicate (same task+state+run_id) -------------
"$S/queue_attention.sh" --task "Alpha_Task" --state spec_gate --source orchestrator \
  --run-id run-001 --reason "different wording, same event" --source-persona Executioner --queue-file "$Q" >/dev/null \
  || fail "duplicate append errored (should no-op)"
OPEN=$(awk '/^## Open/{f=1;next} f' "$Q" | grep -c '^- \[ \]')
[[ "$OPEN" -eq 2 ]] || fail "duplicate was appended; expected 2 open entries, got $OPEN"

# A resolved (checked) entry must NOT block re-escalation of the same event.
sed -i.bak 's/^- \[ \] \[\[Alpha_Task\]\]/- [x] [[Alpha_Task]]/' "$Q" && rm -f "$Q.bak"
"$S/queue_attention.sh" --task "Alpha_Task" --state spec_gate --source orchestrator \
  --run-id run-001 --reason "re-raised after resolve" --source-persona Executioner --queue-file "$Q" >/dev/null \
  || fail "re-escalation after resolve failed"
OPEN=$(awk '/^## Open/{f=1;next} f' "$Q" | grep -c '^- \[ \]')
[[ "$OPEN" -eq 2 ]] || fail "re-escalation after resolve should re-open Alpha; expected 2 open, got $OPEN"

# --- 4. Malformed-args refusal exits non-zero ------------------------------
rc=0; "$S/queue_attention.sh" --task "X" --state bogus_state --source orchestrator \
  --run-id r --reason z --source-persona Executioner --queue-file "$Q" 2>/dev/null || rc=$?
[[ "$rc" -ne 0 ]] || fail "invalid --state should exit non-zero"
rc=0; "$S/queue_attention.sh" --task "X" --state spec_gate --source orchestrator \
  --run-id r --source-persona Executioner --queue-file "$Q" 2>/dev/null || rc=$?
[[ "$rc" -ne 0 ]] || fail "missing --reason should exit non-zero"

echo "SMOKE: OK"

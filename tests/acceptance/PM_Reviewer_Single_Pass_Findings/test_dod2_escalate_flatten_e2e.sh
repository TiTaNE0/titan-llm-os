#!/usr/bin/env bash
# DoD 2 (failure path): after the revision bound, the reviewer's multi-finding verdict reaches the
# human queue through the real queue_attention.sh, flattened exactly as Step 8's Escalate block says.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

V="$TMP/v"; mkdir -p "$V/.scripts" "$V/04_Logs/Telemetry"
for s in queue_attention persona_check emit_telemetry; do cp "$VAULT/.scripts/$s.sh" "$V/.scripts/"; done
chmod +x "$V/.scripts/"*.sh; ln -s . "$V/.vault_link"
printf '{\n  "persona": "Executioner",\n  "session_id": "acc",\n  "started_at": "2026-11-09T00:00:00Z",\n  "agent_surface": "test"\n}\n' > "$V/.session_state.json"
Q="$V/Needs_Attention.md"

# A verdict in the new contract shape, taken from pm-reviewer.md's own example.
VERDICT="$(md_section "$PMR" 'Verdict' | awk '/^```/{c++; next} c==1')"
N="$(printf '%s\n' "$VERDICT" | sed -n 1p | sed -E 's/^FLAG: ([0-9]+) findings$/\1/')"
[ "$N" -ge 2 ] 2>/dev/null && pass "verdict has $N findings" || { fail "could not read a multi-finding verdict"; finish; }
ITEMS="$(printf '%s\n' "$VERDICT" | sed 1d)"

qa() { "$V/.scripts/queue_attention.sh" --task "[[T]]" --state spec_gate --source pm_reviewer \
  --run-id run-acc --reason "$1" --source-persona Executioner --queue-file "$Q" >"$TMP/qa_out" 2>"$TMP/qa_err"; echo $?; }

# Unflattened list is refused (why the Escalate block must flatten).
expect "multi-line reviewer list refused by queue_attention" 3 "$(qa "reviewer flag after 2 revisions: $ITEMS")"
[ ! -f "$Q" ] || ! grep -qF '[[T]]' "$Q" && pass "refused escalation wrote nothing" || fail "refused escalation still wrote an entry"

# Flatten per Step 8: newlines to " / ".
SEP="$(step_body 8 | grep -F 'flatten the findings list to one line' | sed -E 's/.*newlines to `([^`]+)`.*/\1/')"
expect "Step 8 names the flatten separator" " / " "$SEP"
FLAT="$(printf '%s\n' "$ITEMS" | awk -v s="$SEP" 'NR>1{printf "%s", s} {printf "%s", $0}')"
REASON="reviewer flag after 2 revisions: $FLAT"
expect "flattened reason accepted" 0 "$(qa "$REASON")"
expect "exactly one queue entry for the task" 1 "$(grep -cF '[[T]] | state: spec_gate | source: pm_reviewer' "$Q")"
ENTRY="$(grep -F '[[T]] | state: spec_gate' "$Q")"
has "entry carries the bound-exhausted reason" "$ENTRY" "reason: reviewer flag after 2 revisions: 1. ["
i=0
while IFS= read -r line; do
  i=$((i + 1)); has "entry keeps finding $i verbatim" "$ENTRY" "$line"
done <<< "$ITEMS"
expect "all $N findings survived flattening" "$N" "$i"
finish

#!/usr/bin/env bash
# DoD 1: an executable runbook exists and follows the kernel /synthesize contract step for step;
# it names where it lives and why.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
KERNEL="$VAULT/03_Brain/System_Agents.md"

[ -s "$RUNBOOK" ] && pass "runbook exists and is non-empty" || { fail "runbook missing"; finish; }
[ "$(sed -n 1p "$RUNBOOK")" = "---" ] && grep -q '^description: .\+' "$RUNBOOK" && pass "frontmatter has a description" || fail "frontmatter description"
has "$RUNBOOK" "allowed-tools: Bash, Read, Write" "allowed-tools frontmatter"

# Kernel step names, in order, taken live from the kernel text, must be the runbook step names.
kernel_names="$(section "$KERNEL" '### `/synthesize' | sed -n 's/^\([1-9]\)\. \*\*\([A-Za-z]*\).*/\1 \2/p')"
eq "kernel lists 9 steps" "$(echo "$kernel_names" | wc -l | tr -d ' ')" "9"
run_names="$(grep -E '^### Step [1-9] - ' "$RUNBOOK" | sed -E 's/^### Step ([1-9]) - ([A-Za-z]+).*/\1 \2/')"
eq "runbook step headings match the kernel step names in order" "$run_names" "$kernel_names"

# Per-step: key action literal lives in the matching block, not elsewhere.
step() { awk -v n="$1" '/^### Step [1-9] - /{on=($0 ~ "^### Step " n " - ")} /^## /{on=0} on' "$RUNBOOK"; }
step 1 | grep -qF 'persona_check.sh Synthesizer' && pass "step1 persona gate" || fail "step1 persona gate"
step 1 | grep -q 'E4' && pass "step1 E4" || fail "step1 E4"
step 2 | grep -qF 'synthesize_run.sh plan --week' && pass "step2 plan" || fail "step2 plan"
step 3 | grep -qF 'log=' && pass "step3 reads plan log= files" || fail "step3 log="
step 5 | grep -q 'facts.jsonl' && step 5 | grep -q 'contradicted' && pass "step5 reconcile" || fail "step5"
for lit in 'archive/' '0.2' '90' 'rule_proposals' 'contradicted'; do
  step 6 | grep -qF -- "$lit" && pass "step6 decay literal $lit" || fail "step6 literal $lit"
done
step 7 | grep -qF 'mv facts.jsonl.next facts.jsonl' && pass "step7 promotes staged store" || fail "step7 mv"
step 8 | grep -q 'pending' && step 8 | grep -q 'contradiction' && pass "step8 HALT surfaces pending and contradictions" || fail "step8"
step 9 | grep -qF 'emit_telemetry.sh synthesize' && step 9 | grep -qF 'append_log.sh' && pass "step9 telemetry and log" || fail "step9"
grep -qF 'telemetry_start.sh synthesize' "$RUNBOOK" && pass "start timestamp captured (kernel 1.2)" || fail "start timestamp"

# Location and rationale.
header="$(sed -n '/^# \/synthesize/,/^## STEPS/p' "$RUNBOOK")"
echo "$header" | grep -q 'vault-local' && echo "$header" | grep -q 'not a kit command' && pass "header names vault-local location" || fail "header location"
echo "$header" | grep -q 'for three reasons' && pass "header gives the reason" || fail "header reason"

# Symlink entry resolves to the runbook (per-machine, gitignored).
if [ -d "$VAULT/.claude/commands" ]; then
  [ "$(cd "$VAULT/.claude/commands" && cd "$(dirname "$(readlink synthesize.md)")" && pwd -P)/synthesize.md" = "$RUNBOOK" ] \
    && pass "slash-command symlink resolves to runbook" || fail "symlink target"
fi
[ -x "$HELPER" ] && pass "helper executable" || fail "helper not executable"
finish

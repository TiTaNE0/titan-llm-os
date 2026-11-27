#!/usr/bin/env bash
# DoD 5: the new assertions fail on the pre-fix script (checked on a sandbox copy of HEAD's script); the
# gateway test ships the new section. The gateway itself runs once in the verification step (ACC_SKIP_GATEWAY).
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
GW="$VAULT/tests/test_synthesize_scheduled_run.sh"
has "$GW" 'not finished' "gateway test asserts the refusal text"
has "$GW" 'unfinished week' "gateway test has the unfinished-week section"
SB="$TMP/old"; mk_sandbox "$SB"
git -C "$VAULT" show HEAD:.scripts/synthesize_run.sh > "$SB/.scripts/synthesize_run.sh" 2>/dev/null
if grep -q 'not finished' "$SB/.scripts/synthesize_run.sh"; then
  pass "HEAD already contains the fix; pre-fix RED comparison skipped"
else
  plan "$SB" --week 2026-W48 --today 2026-11-27
  case "$ERR" in *"is not finished"*) fail "pre-fix script unexpectedly refuses";; *) pass "pre-fix script lacks the refusal (acceptance assertions would be RED)";; esac
  plan "$SB" --week 2099-W01
  [ "$RC" = 0 ] && pass "pre-fix script accepts a future week (RED reproduced)" || fail "pre-fix rc=$RC"
fi
# Gateway test: only run when the aggregator allows nested runs and no skip env is set.
if [ "${ACC_SKIP_GATEWAY:-0}" = 1 ]; then pass "gateway run skipped (ACC_SKIP_GATEWAY=1)"
else
  out="$(bash "$GW" 2>&1)"; rc=$?
  [ $rc -eq 0 ] && echo "$out" | grep -q 'ALL GREEN' && pass "gateway ALL GREEN" || fail "gateway not green"
fi
finish

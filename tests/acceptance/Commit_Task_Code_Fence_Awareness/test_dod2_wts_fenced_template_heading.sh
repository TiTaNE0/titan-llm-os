#!/usr/bin/env bash
# DoD 2: a template header (`## ✅ Validator Report`) quoted inside a ~~~ fence does not end the
# Spec section, so --overwrite replaces the whole section; pre-fix kept the tail (RED first).
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

cat > "$TMP/c1.md" <<'C'
## Spec: T
~~~
## ✅ Validator Report
~~~
OLD_MARKER
C
printf '## Spec: T\nNEW_MARKER\n' > "$TMP/c2.md"

for mode in fixed prefix; do
  V="$TMP/v_$mode"; T="$V/02_Tasks/P/T.md"
  if [ "$mode" = prefix ]; then mk_vault "$V" 1; else mk_vault "$V"; fi
  mk_section_task "$T"
  wts "$V" "$T" "$TMP/c1.md"
  wts "$V" "$T" "$TMP/c2.md" --overwrite
  old="$(count OLD_MARKER "$T")"; vr="$(count '## ✅ Validator Report' "$T")"
  if [ "$mode" = fixed ]; then
    [ "$W_RC" = 0 ] && pass "fixed: exit 0" || fail "fixed: exit $W_RC: $(cat "$TMP/wts.err")"
    [ "$old" = 0 ] && pass "fixed: OLD_MARKER gone" || fail "fixed: OLD_MARKER count $old"
    [ "$vr" = 1 ] && pass "fixed: one Validator Report header" || fail "fixed: Validator Report count $vr"
    grep -q 'section=validator_report' "$T" && pass "fixed: validator anchor kept" || fail "fixed: anchor lost"
  else
    if [ "$old" = 0 ] && [ "$vr" = 1 ]; then fail "pre-fix unexpectedly handled the case"
    else pass "pre-fix reproduces (OLD_MARKER=$old, VR=$vr)"; fi
  fi
done
finish

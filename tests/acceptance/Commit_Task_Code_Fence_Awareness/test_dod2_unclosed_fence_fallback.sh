#!/usr/bin/env bash
# DoD 2 fail-safe: an unclosed fence in section content never lets an overwrite swallow later
# template sections (section_end_line falls back to the fence-blind boundary).
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

printf '## Spec: T\nOLD_MARKER\n```bash\nnever closed\n' > "$TMP/c1.md"
printf '## Spec: T\nNEW_MARKER\n' > "$TMP/c2.md"
V="$TMP/v"; T="$V/02_Tasks/P/T.md"; mk_vault "$V"; mk_section_task "$T"
wts "$V" "$T" "$TMP/c1.md"
wts "$V" "$T" "$TMP/c2.md" --overwrite
[ "$W_RC" = 0 ] && pass "exit 0" || fail "exit $W_RC: $(cat "$TMP/wts.err")"
for h in '## ✅ Validator Report' '## 📊 Verification Output' '## 🔗 Related Context'; do
  [ "$(count "$h" "$T")" = 1 ] && pass "kept $h" || fail "$h count $(count "$h" "$T")"
done
[ "$(count OLD_MARKER "$T")" = 0 ] && pass "old content replaced" || fail "OLD_MARKER survived"
[ "$(count NEW_MARKER "$T")" = 1 ] && pass "new content once" || fail "NEW_MARKER count"
finish

#!/usr/bin/env bash
# DoD 1 fail-closed path: an unclosed fence in the Spec refuses with E3 and changes nothing,
# so the commit list never grows into later sections.
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

cat > "$TMP/spec.md" <<'S'
## Spec: T

```bash
echo never closed
### Files touched
- [EDIT] `a.txt`
S

V="$TMP/v"; R="$TMP/r"
mk_vault "$V"; mk_repo "$R"; write_task "$V/02_Tasks/P/T.md" "$TMP/spec.md"
echo a1 > "$R/a.txt"
head_before="$(git -C "$R" rev-parse HEAD)"; br_before="$(git -C "$R" branch --list | tr -d ' *\n')"
run_commit "$V" "$R" "$V/02_Tasks/P/T.md"
[ "$CT_RC" = 3 ] && pass "exit 3" || fail "exit $CT_RC"
grep -q 'E3: unclosed code fence in the Spec section' "$CT_ERR" && pass "E3 message" || fail "stderr: $(cat "$CT_ERR")"
[ "$(git -C "$R" rev-parse HEAD)" = "$head_before" ] && pass "HEAD unchanged" || fail "HEAD moved"
[ "$(git -C "$R" branch --list | tr -d ' *\n')" = "$br_before" ] && pass "no branch created" || fail "branch list changed"
[ -z "$(git -C "$R" diff --cached --name-only)" ] && pass "nothing staged" || fail "index changed"
finish

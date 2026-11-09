#!/usr/bin/env bash
# DoD 1/3: a fence-free Spec behaves exactly as before: block found, Risks/Validator entries ignored,
# and a real `## ` heading still ends the Spec section.
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

cat > "$TMP/spec.md" <<'S'
## Spec: T

### Files touched
- [EDIT] `a.txt`

### Risks
- [EDIT] `decoy.txt` mentioned, not listed
S
V="$TMP/v"; R="$TMP/r"
mk_vault "$V"; mk_repo "$R"; write_task "$V/02_Tasks/P/T.md" "$TMP/spec.md"
echo a1 > "$R/a.txt"; echo d1 > "$R/decoy.txt"; echo l > "$R/late.txt"
run_commit "$V" "$R" "$V/02_Tasks/P/T.md"
[ "$CT_RC" = 0 ] && pass "exit 0" || fail "exit $CT_RC: $(cat "$CT_ERR")"
[ "$(committed_files "$R")" = "a.txt " ] && pass "commit is exactly a.txt" || fail "committed '$(committed_files "$R")'"

# Block placed after a real (unfenced) `## Other` heading is outside the Spec: E3 as before.
printf '## Spec: T\n\n## Other\n\n### Files touched\n- [EDIT] `a.txt`\n' > "$TMP/spec2.md"
V2="$TMP/v2"; R2="$TMP/r2"
mk_vault "$V2"; mk_repo "$R2"; write_task "$V2/02_Tasks/P/T.md" "$TMP/spec2.md"
echo a1 > "$R2/a.txt"
run_commit "$V2" "$R2" "$V2/02_Tasks/P/T.md"
[ "$CT_RC" = 3 ] && grep -q 'no Files touched block' "$CT_ERR" && pass "unfenced ## still ends Spec" || fail "rc=$CT_RC $(cat "$CT_ERR")"
finish

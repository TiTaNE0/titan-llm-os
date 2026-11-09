#!/usr/bin/env bash
# DoD 1: a ~~~ fence holding `## X`, then a 4-backtick fence holding a 3-backtick line and a
# decoy `### Files touched` block. Only the real block's a.txt is committed; decoy.txt
# (dirty) is not. Pre-fix scripts fail the same input.
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

cat > "$TMP/spec.md" <<'S'
## Spec: T

### Summary
~~~
## X
~~~

````markdown
```
### Files touched
- [EDIT] `decoy.txt`
```
## Not a section end
````

### Files touched
- [EDIT] `a.txt`

### Risks
- none
S

for mode in fixed prefix; do
  V="$TMP/v_$mode"; R="$TMP/r_$mode"
  if [ "$mode" = prefix ]; then mk_vault "$V" 1; else mk_vault "$V"; fi
  mk_repo "$R"; write_task "$V/02_Tasks/P/T.md" "$TMP/spec.md"
  echo a1 > "$R/a.txt"; echo d1 > "$R/decoy.txt"
  run_commit "$V" "$R" "$V/02_Tasks/P/T.md"
  files="$(committed_files "$R")"
  if [ "$mode" = fixed ]; then
    [ "$CT_RC" = 0 ] && pass "fixed: exit 0" || fail "fixed: exit $CT_RC, stderr: $(cat "$CT_ERR")"
    grep -qx 'COMMIT_STAGED=1' "$CT_OUT" && pass "fixed: COMMIT_STAGED=1" || fail "fixed: stdout $(cat "$CT_OUT")"
    [ "$files" = "a.txt " ] && pass "fixed: commit is exactly a.txt" || fail "fixed: committed '$files'"
    [ -n "$(git -C "$R" status --porcelain -- decoy.txt)" ] && pass "fixed: decoy.txt left dirty" || fail "fixed: decoy.txt not dirty"
  else
    if [ "$CT_RC" = 0 ] && [ "$files" = "a.txt " ]; then fail "pre-fix unexpectedly handled the case"
    else pass "pre-fix fails the case (rc=$CT_RC, committed '$files')"; fi
  fi
done
finish

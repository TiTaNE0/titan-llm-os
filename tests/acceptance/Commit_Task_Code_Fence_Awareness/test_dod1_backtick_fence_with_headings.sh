#!/usr/bin/env bash
# DoD 1: a Spec quoting a ```markdown fence holding `## Usage` / `### Example` still yields
# its Files touched block (the 2026-11-08 OpenCode_Runbook_Port E3), and the pre-fix script
# reproduces that E3 on the same input (RED first).
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

cat > "$TMP/spec.md" <<'S'
## Spec: T

### Summary
The runbook quotes markdown:

```markdown
## Usage
Run it.
### Example
More.
```

### Files touched
- [EDIT] `a.txt`

### Risks
- none
S

for mode in fixed prefix; do
  V="$TMP/v_$mode"; R="$TMP/r_$mode"
  if [ "$mode" = prefix ]; then mk_vault "$V" 1; else mk_vault "$V"; fi
  mk_repo "$R"; write_task "$V/02_Tasks/P/T.md" "$TMP/spec.md"
  echo a1 > "$R/a.txt"
  run_commit "$V" "$R" "$V/02_Tasks/P/T.md"
  if [ "$mode" = fixed ]; then
    [ "$CT_RC" = 0 ] && pass "fixed: exit 0" || fail "fixed: exit $CT_RC, stderr: $(cat "$CT_ERR")"
    grep -qx 'COMMIT_STAGED=1' "$CT_OUT" && pass "fixed: COMMIT_STAGED=1" || fail "fixed: stdout $(cat "$CT_OUT")"
    [ "$(committed_files "$R")" = "a.txt " ] && pass "fixed: a.txt committed" || fail "fixed: committed '$(committed_files "$R")'"
  else
    [ "$CT_RC" = 3 ] && grep -q 'no Files touched block' "$CT_ERR" \
      && pass "pre-fix reproduces E3 no Files touched block" \
      || fail "pre-fix did not reproduce E3 (rc=$CT_RC, $(cat "$CT_ERR"))"
  fi
done
finish

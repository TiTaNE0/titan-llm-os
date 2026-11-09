#!/usr/bin/env bash
# DoD 2: write_task_section's foreign-heading guard does not fire on a `## Strategy` inside a
# fence (overwrite succeeds and replaces), still fires on an unfenced one, and the pre-fix
# guard fired on the fenced case (RED first).
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

cat > "$TMP/c1.md" <<'C'
## Spec: T
OLD_MARKER
```markdown
## Strategy
quoted
```
C
printf '## Spec: T\nNEW_MARKER\n' > "$TMP/c2.md"

for mode in fixed prefix; do
  V="$TMP/v_$mode"; T="$V/02_Tasks/P/T.md"
  if [ "$mode" = prefix ]; then mk_vault "$V" 1; else mk_vault "$V"; fi
  mk_section_task "$T"
  wts "$V" "$T" "$TMP/c1.md"
  [ "$W_RC" = 0 ] || fail "$mode: first write exit $W_RC: $(cat "$TMP/wts.err")"
  wts "$V" "$T" "$TMP/c2.md" --overwrite
  if [ "$mode" = fixed ]; then
    [ "$W_RC" = 0 ] && pass "fixed: overwrite exit 0" || fail "fixed: overwrite exit $W_RC: $(cat "$TMP/wts.err")"
    [ "$(count OLD_MARKER "$T")" = 0 ] && pass "fixed: old content gone" || fail "fixed: OLD_MARKER survived"
    [ "$(count NEW_MARKER "$T")" = 1 ] && pass "fixed: new content once" || fail "fixed: NEW_MARKER count $(count NEW_MARKER "$T")"
    [ "$(count '## Strategy' "$T")" = 0 ] && pass "fixed: fenced heading replaced" || fail "fixed: ## Strategy survived"
  else
    [ "$W_RC" = 3 ] && grep -q 'hand-authored heading' "$TMP/wts.err" \
      && pass "pre-fix guard fired on fenced heading" || fail "pre-fix did not reproduce (rc=$W_RC)"
  fi
done

# Guard still protects an unfenced hand-authored heading.
V="$TMP/v_guard"; T="$V/02_Tasks/P/T.md"; mk_vault "$V"; mk_section_task "$T"
printf '## Spec: T\nbody\n```\ncode\n```\n## Strategy\nhuman text\n' > "$TMP/c3.md"
wts "$V" "$T" "$TMP/c3.md"
wts "$V" "$T" "$TMP/c2.md" --overwrite
[ "$W_RC" = 3 ] && grep -q "hand-authored heading '## Strategy'" "$TMP/wts.err" \
  && pass "unfenced foreign heading after a closed fence still refused" || fail "guard rc=$W_RC: $(cat "$TMP/wts.err")"
[ "$(count 'human text' "$T")" = 1 ] && pass "refused write left file intact" || fail "file changed on refusal"
finish

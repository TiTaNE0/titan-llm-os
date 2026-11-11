#!/usr/bin/env bash
# DoD6: the kit's inline-mutation CI check stays green with the new text, the OpenCode agent bindings
# check passes, and the OpenCode commands were regenerated from the edited runbooks (the new sections
# arrive byte-identical, so an OpenCode-run coordinator gets the same firewall, menu and guard).
. "$(dirname "$0")/_lib.sh"
( cd "$KIT" && bash tests/test_no_inline_mutations.sh >"$TMP/nim" 2>&1 ) && pass "kit test_no_inline_mutations green" || { fail "kit test_no_inline_mutations"; cat "$TMP/nim" >&2; }
bash "$KIT/install.sh" check-opencode --path "$(dirname "$OC_CMD")/agent" >"$TMP/coc" 2>&1 && pass "install.sh check-opencode exit 0" || { fail "check-opencode"; cat "$TMP/coc" >&2; }

same_section() { # label runbook oc-file heading-regex
  section "$2" "$4" > "$TMP/a"; section "$3" "$4" > "$TMP/b" 2>/dev/null
  [ -s "$TMP/a" ] && cmp -s "$TMP/a" "$TMP/b" && pass "OpenCode $1 identical to runbook" || fail "OpenCode $1 differs from runbook (run install.sh setup-opencode)"
}
same_section "§ Builder failure" "$ET" "$OC_CMD/execute_task.md" '^## Builder failure$'
same_section "§ Error handling protocol" "$ET" "$OC_CMD/execute_task.md" '^## Error handling protocol'
same_section "§ Step 10" "$ET" "$OC_CMD/execute_task.md" '^## Step 10 '
same_section "close_task § Step 4.4" "$CT" "$OC_CMD/close_task.md" '^## Step 4\.4 '
same_section "close_task § Step 8" "$CT" "$OC_CMD/close_task.md" '^## Step 8 '
done_

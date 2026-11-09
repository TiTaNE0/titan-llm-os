#!/usr/bin/env bash
# DoD 3 (wording): the test-verifier, both via its Step 11 brief and its own agent file, is
# forbidden from adding a nested full-gateway run to an acceptance folder unless gated by the
# shared ACC_SKIP_GATEWAY=1 env that the aggregator sets.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
has "Step 11 brief carries the nested-gateway rule" "$(step "$EXEC" 11 12)" "$S_NESTED"
DONT="$(awk '/^## What you do NOT do$/{on=1;next} /^## /{on=0} on' "$AG/test-verifier.md" | awk 'NF')"
fw="$(printf '%s\n' "$DONT" | grep -nF -- '**Vault firewall:**' | cut -d: -f1)"
nb="$(printf '%s\n' "$DONT" | grep -nxF -- "$A_TVNEST" | cut -d: -f1)"
[ -n "$nb" ] && pass "test-verifier 'do NOT' bullet present verbatim" || fail "test-verifier nested bullet missing"
[ -n "$fw" ] && [ -n "$nb" ] && [ "$nb" -eq $((fw + 1)) ] && pass "bullet directly after the vault firewall bullet" || fail "bullet not right after firewall (fw=$fw nb=$nb)"
# The OpenCode copy the other runtime reads must carry the same rule.
grep -qxF -- "$A_TVNEST" "$OC_AGENT/test-verifier.md" 2>/dev/null && pass "OpenCode test-verifier carries the rule" || fail "OpenCode test-verifier lacks the rule"
finish

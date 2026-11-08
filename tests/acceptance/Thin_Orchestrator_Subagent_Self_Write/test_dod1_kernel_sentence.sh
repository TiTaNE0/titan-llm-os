#!/usr/bin/env bash
# DoD 1: the amended kernel § 7 vault-write sentence is present (read-only check).
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
grep -qF 'persist their own task section by calling `write_task_section`' "$VAULT/03_Brain/System_Agents.md" \
  && pass "kernel sentence present" || fail "kernel § 7 sentence missing"
finish

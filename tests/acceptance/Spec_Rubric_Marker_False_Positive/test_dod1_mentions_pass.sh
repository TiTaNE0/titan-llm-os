#!/usr/bin/env bash
# DoD 1: a spec line that only MENTIONS the marker phrase (backticks, double quotes, fence)
# passes check (c). Each case also fails on the pre-fix script, proving it was a false positive.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
build_vaults
expect_pass_fixed "backticked questions heading in prose" \
  'Every spec carries the `### Open questions` heading at the end.'
expect_pass_fixed "quoted rubric failure message" \
  'When a marker remains the gate prints "RUBRIC FAIL: open questions remain in spec" and stops.'
expect_pass_fixed "backticked mention in a Risks bullet" \
  $'### Risks\n- Renaming the `### Open questions` heading would break check (c2).'
expect_pass_fixed "backticked TBD/TODO/FIXME/??? tokens" \
  'The scan matches `TBD`, `TODO`, `FIXME` and `???` as unresolved markers.'
expect_pass_fixed "quoted TBD token" \
  'A line such as "- TBD: pick a timeout" would be an unresolved item.'
expect_pass_fixed "backtick fence holding an item" \
  $'Example fixture:\n```\n- TBD: which retry policy applies?\n### Open questions\n1. Who owns it?\n```\nEnd of example.'
expect_pass_fixed "tilde fence holding an item" \
  $'Example fixture:\n~~~text\nAn open question about FIXME handling\n~~~\nEnd of example.'
expect_pass_fixed "two mentions on one line" \
  'Both `open question` and "open question" are mentions here.'
finish

#!/usr/bin/env bash
# Runs every acceptance test of this folder under bash and /bin/bash (3.2).
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
rc=0
for sh in bash /bin/bash; do
  for t in "$HERE"/test_*.sh; do
    if ACC_SKIP_GATEWAY="${ACC_SKIP_GATEWAY:-0}" "$sh" "$t" >/dev/null 2>"${TMPDIR:-/tmp}/synunf_err.$$"; then echo "PASS [$sh] $(basename "$t")"
    else echo "FAIL [$sh] $(basename "$t")"; cat "${TMPDIR:-/tmp}/synunf_err.$$"; rc=1; fi
  done
done
rm -f "${TMPDIR:-/tmp}/synunf_err.$$"
exit $rc

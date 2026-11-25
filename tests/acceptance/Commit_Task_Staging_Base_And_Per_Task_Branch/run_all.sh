#!/usr/bin/env bash
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
rc=0; for t in test_*.sh; do echo "== $t"; /bin/bash "$t" || rc=1; done; exit $rc

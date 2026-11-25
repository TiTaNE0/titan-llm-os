#!/usr/bin/env bash
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
rc=0; for t in test_*.sh; do echo "== $t"; ACC_SKIP_GATEWAY=1 /bin/bash "$t" || rc=1; done; exit $rc

#!/usr/bin/env bash
# DoD 2: every emit/timer call made by a kit suite carries a TELEMETRY_DIR override that
# points at a temp dir, never the vault (mirror or live). Observed per call by shims in a
# private vault mirror.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
build_mirror
mirror_valid && pass "kit copy resolves to private mirror" || { fail "mirror invalid"; finish; }
tmp_root() {
  case "$1" in
    "${TMPDIR:-/tmp}"/*|/tmp/*|/private/tmp/*|/var/folders/*|/private/var/folders/*) return 0 ;;
  esac; return 1
}
# Only the emitting suites call the atoms; the gateway run (DoD3/4 test) leak-checks every suite.
for name in $EMITTING; do
  : > "$CALLS"
  run_mirror_suite "$name"
  total="$(wc -l < "$CALLS" | tr -d ' ')"
  case " $EMITTING " in *" $name "*) [ "$total" -ge 1 ] || fail "$name: no telemetry calls observed" ;; esac
  [ "$total" = 0 ] && continue
  bad=0
  while read -r script dir; do
    if [ "$dir" = "<unset>" ]; then fail "$name: $script called without TELEMETRY_DIR"; bad=1
    else
      case "$dir" in "$VAULT"*|"$M"*|"$K"*|"$KIT"*) fail "$name: $script override inside vault/kit: $dir"; bad=1 ;; esac
      tmp_root "$dir" || { fail "$name: $script override not a temp dir: $dir"; bad=1; }
    fi
  done < "$CALLS"
  [ "$bad" = 0 ] && pass "$name: all $total telemetry calls used a temp TELEMETRY_DIR"
done
finish

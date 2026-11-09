#!/usr/bin/env bash
# DoD 5: install.sh setup-opencode reports a specific error for "key = value" (and one-sided
# spaces), exits 2 and writes no agent file. RED: with the new check removed, the same input
# still exits 2 but without the specific message. Runs against a temp HOME.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
PHRASE="spaces around '=' are not allowed"
mkdir -p "$TMP/kitred"
sed "/spaces around '='/d" "$KIT/install.sh" > "$TMP/kitred/install.sh"
grep -q "$PHRASE" "$KIT/install.sh" || fail "install.sh has no specific spaces message"
run() { # <install.sh> <bindings-line>
  rm -rf "$TMP/oc" "$TMP/home" "$TMP/xdg"; mkdir -p "$TMP/home" "$TMP/xdg"
  printf '%s\n' "$2" > "$TMP/bind.txt"
  env HOME="$TMP/home" XDG_CONFIG_HOME="$TMP/xdg" bash "$1" setup-opencode \
    --path "$TMP/oc/agent" --bindings "$TMP/bind.txt" >/dev/null 2>"$TMP/err"; RC=$?
}
for b in 'gate = a/b' 'gate =a/b' 'gate= a/b' 'role.validator = a/b' $'\tgate\t=\ta/b'; do
  run "$KIT/install.sh" "$b"
  expect "[$b] exit" 2 "$RC"
  grep -qF "$PHRASE" "$TMP/err" && pass "[$b] specific message" || fail "[$b] stderr: $(cat "$TMP/err")"
  grep -qF "bind.txt:1:" "$TMP/err" && pass "[$b] names file:line" || fail "[$b] no file:line in stderr"
  [ -z "$(find "$TMP/oc" -name '*.md' 2>/dev/null)" ] && pass "[$b] no agent file written" || fail "[$b] wrote agent files"
done
for b in 'gate = a/b' 'gate =a/b' 'gate= a/b'; do
  run "$TMP/kitred/install.sh" "$b"
  expect "RED [$b] exit" 2 "$RC"
  grep -qF "$PHRASE" "$TMP/err" && fail "RED [$b] still has the phrase" || pass "RED [$b] lacks specific message"
done
# Positive control: valid binding gets past the bindings parser.
run "$KIT/install.sh" 'gate=kitfixture/m'
grep -q 'bind.txt' "$TMP/err" && fail "valid binding rejected: $(cat "$TMP/err")" || pass "gate=kitfixture/m parses"
finish

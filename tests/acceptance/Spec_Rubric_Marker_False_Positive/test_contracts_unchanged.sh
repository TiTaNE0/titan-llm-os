#!/usr/bin/env bash
# Spec contracts: the (c) regex line, the (c) message, the aggregator sed anchors and the
# CLI exit codes are byte-identical to the pre-fix script; lib_section.sh is untouched.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
build_vaults
same_line() { # <label> <fixed-string>
  local gl rl
  gl="$(grep -cF -- "$2" "$G/.scripts/spec_rubric.sh")"; rl="$(grep -cF -- "$2" "$R/.scripts/spec_rubric.sh")"
  [ "$gl" -ge 1 ] && [ "$gl" = "$rl" ] && pass "$1 unchanged" || fail "$1: GREEN=$gl RED=$rl occurrences"
}
same_line "(c) regex" "if grep -qiE 'open question|[[:space:]]TBD\b|\?\?\?|[[:space:]]TODO\b|FIXME' \"\$WORK/text\"; then"
same_line "(c) message" 'echo "RUBRIC FAIL: open questions remain in spec" >&2; exit 3'
same_line "(d) anchor comment" '# (d) Responsibility map'
same_line "PASS anchor" 'echo "RUBRIC: PASS"'
cmp -s "$G/.scripts/lib_section.sh" "$R/.scripts/lib_section.sh" && pass "lib_section.sh untouched" || fail "lib_section.sh changed"
bash "$G/.scripts/spec_rubric.sh" >/dev/null 2>&1; expect "no args -> exit 2" 2 "$?"
bash "$G/.scripts/spec_rubric.sh" --task-path "$TMP/missing.md" >/dev/null 2>&1; expect "missing file -> exit 2" 2 "$?"
bash "$G/.scripts/spec_rubric.sh" --bogus >/dev/null 2>&1; expect "unknown arg -> exit 2" 2 "$?"
# Other checks still fire in their order: an empty map still reports the map, not (c).
f="$TMP/nomap.md"
cat > "$f" <<'EOT'
---
status: in_progress
---
# T

## 📐 Spec
Edit `.scripts/foo.sh` per the `### Open questions` note.
### Context pack
- Read: `x.sh:1` - y
### Files touched
- [EDIT] `x.sh`

## ✅ Validator Report
> x
EOT
rubric "$G" "$f"; expect "missing map: exit" 3 "$RC"; expect "missing map: message" "RUBRIC FAIL: no Responsibility map in spec" "$ERR"
finish

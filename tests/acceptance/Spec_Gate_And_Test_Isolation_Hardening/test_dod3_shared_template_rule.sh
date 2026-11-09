#!/usr/bin/env bash
# DoD 3: grep_section uses the lib_section.sh template rule. For every probe heading, the
# lib's sec_heading_name result decides grep_section's match, and sec_is_template output is
# unchanged versus the pre-fix library (the refactor moved the rule, it did not alter it).
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
build_vaults
probes="$TMP/probes.txt"
cat > "$probes" <<'P'
## ✅ Validator Report
## Validator Report
## Spec: Validator Report
## ⚡ Task: Validator Report
## 1. Validator Report
## 📐 Spec
## Spec
## Spec: T
## 🏁 COMPLETION SUMMARY (Post-Mortem)
## COMPLETION SUMMARY
## 🎯 Definition of Done (Success Criteria)
## [x] Validator Report
## -> Validator Report
### Validator Report
## Random Header
P
lib_eval() { # <vault> <awk-body>
  ( . "$1/.scripts/lib_section.sh"; awk "$SECTION_AWK""$2" "$probes" )
}
grep -q 'sec_heading_name' "$G/.scripts/grep_section.sh" && pass "grep_section calls sec_heading_name" \
  || fail "grep_section does not use sec_heading_name"
expect "sec_is_template GREEN == RED" "$(lib_eval "$R" '{ print sec_is_template($0) }')" "$(lib_eval "$G" '{ print sec_is_template($0) }')"
while IFS= read -r line; do
  name="$(printf '%s\n' "$line" | ( . "$G/.scripts/lib_section.sh"; awk "$SECTION_AWK"'{ print sec_heading_name($0) }' ))"
  case "$line" in "## "*) ;; *) continue ;; esac
  g="$TMP/p.md"; printf '# T\n\n%s\nbody\n' "$line" > "$g"
  expect "[$line] matches its sec_heading_name [$name]" 0 "$(gsec "$G" "$g" "$name" present)"
  case "$name" in
    "Validator Report") ;;
    *) expect "[$line] not taken as Validator Report" 3 "$(gsec "$G" "$g" "Validator Report" present)" ;;
  esac
done < "$probes"
finish

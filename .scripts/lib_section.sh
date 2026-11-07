# lib_section.sh - sourced helper (not an atom, no Tool_Registry entry).
# Single owner of the "what ends a task section" rule: a section runs until the next
# TEMPLATE `## ` header, so agent content that itself contains `## Spec: <Task>` or
# other `## ` lines does not end the section early.
# The name list below mirrors 00_Templates/Task_Template.md - change both together.
# bash 3.2 / BSD awk safe; no shebang, no `set` options; safe to source twice.

# BSD-awk function definitions; callers prepend: awk "$SECTION_AWK"'<prog>'
SECTION_AWK='
function sec_is_template(line,   h, n, names, i, N, c) {
  if (line !~ /^##[[:space:]]/) return 0
  h = line
  sub(/^##[[:space:]]+/, "", h)
  sub(/[[:space:]]+$/, "", h)
  sub(/^[^A-Za-z0-9[:space:]]+[[:space:]]+/, "", h)
  n = split("Declarative Objective|Definition of Done|Verification Gateway|Agent Implementation Plan|Research Notes|Spec|Validator Report|Verification Output|COMPLETION SUMMARY|Related Context", names, "|")
  for (i = 1; i <= n; i++) {
    N = names[i]
    if (h == N) return 1
    if (substr(h, 1, length(N)) == N) {
      c = substr(h, length(N) + 1, 1)
      if (c == " " || c == "\t" || c == "(") return 1
    }
  }
  return 0
}
# Agent-emitted sub-heading: `## <Name>[ (note)]: <anything>` where Name is an allowlisted
# agent output name; other human `## X: Y` headings are foreign.
function sec_is_agent_subheading(line,   h, p, nm, n, names, i) {
  if (line !~ /^##[[:space:]]/) return 0
  h = line
  sub(/^##[[:space:]]+/, "", h)
  sub(/^[^A-Za-z0-9[:space:]]+[[:space:]]+/, "", h)
  p = index(h, ": ")
  if (p <= 1) return 0
  nm = substr(h, 1, p - 1)
  sub(/ \([^()]*\)$/, "", nm)
  n = split("Spec|Validator Report|Research report|Research Report|Criteria|Summary|Gateway", names, "|")
  for (i = 1; i <= n; i++) if (nm == names[i]) return 1
  return 0
}
'

# section_end_line <file> <start>: prints the line before the next template header
# after <start>, or the file line count. `if` (not &&) so set -e callers survive.
section_end_line() {
  local _sel_end
  _sel_end="$(awk "$SECTION_AWK"'NR > start && sec_is_template($0) { print NR-1; exit }' start="$2" "$1")"
  if [[ -z "$_sel_end" ]]; then
    _sel_end="$(wc -l < "$1" | tr -d ' ')"
  fi
  printf '%s\n' "$_sel_end"
}

# section_foreign_heading <file> <start> <end>: prints the first `## ` line in
# (start, end] that is neither a template header nor an allowlisted agent `Name: T` sub-heading.
# Returns 0 if found, 1 if none. Safe in `if` under set -e.
section_foreign_heading() {
  local _sfh
  _sfh="$(awk "$SECTION_AWK"'NR > start && NR <= end && /^##[[:space:]]/ && !sec_is_template($0) && !sec_is_agent_subheading($0) { print; exit }' start="$2" end="$3" "$1")"
  if [[ -n "$_sfh" ]]; then
    printf '%s\n' "$_sfh"
    return 0
  fi
  return 1
}

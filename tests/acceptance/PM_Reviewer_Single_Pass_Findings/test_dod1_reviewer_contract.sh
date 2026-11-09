#!/usr/bin/env bash
# DoD 1: pm-reviewer requires every finding in one pass as a numbered list, each tagged with
# exactly one of six allowed defect classes; style and hypothetical-misuse findings are excluded.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

# The contract that ships is the one Claude Code loads: global copy, its docs twin, and the live link.
cmp -s "$PMR" "$PMR_DOC" && pass "docs/cld twin byte-identical to global pm-reviewer.md" || fail "docs/cld/pm-reviewer.md differs from global"
case "$(readlink "$HOME/.claude/agents/pm-reviewer.md" 2>/dev/null)" in
  "$KIT"/*) pass "~/.claude/agents/pm-reviewer.md links into the kit (change is live)" ;;
  *) fail "~/.claude/agents/pm-reviewer.md is not a symlink into the kit; the new contract is not live" ;;
esac

FM="$(awk '/^---$/{c++; next} c==1' "$PMR")"
expect "frontmatter name" "name: pm-reviewer" "$(printf '%s\n' "$FM" | grep '^name:')"
expect "frontmatter tools stay read-only" "tools: Read, Grep, Glob" "$(printf '%s\n' "$FM" | grep '^tools:')"
expect "frontmatter model" "model: opus" "$(printf '%s\n' "$FM" | grep '^model:')"
DESC="$(printf '%s\n' "$FM" | grep '^description:')"
has "description advertises one-pass numbered list" "$DESC" "every defect as a numbered list in one pass"
lacks "description drops FLAG(reason)" "$DESC" "FLAG(reason)"

# Closed class set: exactly the six labels, each defined on its own bullet, nothing else.
CS="$(md_section "$PMR" 'Allowed defect classes')"
[ -n "$CS" ] && pass "Allowed defect classes section present" || fail "Allowed defect classes section missing"
GOT="$(printf '%s\n' "$CS" | grep -E '^- `\[' | sed -E 's/^- `\[([^]]+)\]`.*/\1/')"
expect "class bullets are exactly the six allowed labels, in order" "$CLASSES" "$GOT"
n="$(printf '%s\n' "$CS" | grep -E '^- `\[[^]]+\]` — .{10,}' | wc -l | tr -d ' ')"
expect "every class has a one-line definition" 6 "$n"
has "class set stated as exclusive" "$CS" "Nothing outside them is a finding"
has "one label per finding" "$CS" "exactly one of these labels"

# Single pass, numbered list, nothing held back.
SP="$(md_section "$PMR" 'Single pass')"
has "single-pass rule" "$SP" "List every finding in one pass."
has "numbered-list rule" "$SP" "Report them as a numbered list."
has "no withholding for a later round" "$SP" "Never hold a visible defect back for a later round"

# Exclusions: style and hypothetical misuse are never findings.
EX="$(md_section "$PMR" 'Excluded')"
has "exclusion sentence" "$EX" "Style and hypothetical-misuse findings are excluded."
for w in wording formatting naming "a future caller could misuse X" "extra hardening the DoD does not require"; do
  has "exclusion covers: $w" "$EX" "$w"
done
CO="$(md_section "$PMR" 'The cost asymmetry')"
has "torn-case rule stays inside the allowed classes" "$CO" "never flag outside the allowed classes"
lacks "old one-line verdict wording gone (cost)" "$CO" "one-line"

# Verdict format.
V="$(md_section "$PMR" 'Verdict')"
has "verdict line 1 format" "$V" 'Line 1 is exactly `APPROVE` or `FLAG: <N> findings`.'
has "verdict item format" "$V" '`<i>. [<class>] <spec section or file>: <defect> (evidence: <short quote or path:line>)`'
has "exactly N items" "$V" "exactly N following lines"
has "no preamble" "$V" "no preamble and no other text"
for old in 'FLAG: <one-line reason>' 'Return EXACTLY one line'; do
  lacks "old single-finding contract gone: $old" "$(cat "$PMR")" "$old"
done

# The worked example must itself obey the contract (a reviewer copies the example's shape).
EXM="$(printf '%s\n' "$V" | awk '/^```/{c++; next} c==1')"
L1="$(printf '%s\n' "$EXM" | sed -n 1p)"
if printf '%s\n' "$L1" | grep -qE '^FLAG: [0-9]+ findings$'; then
  pass "example line 1 is 'FLAG: <N> findings'"
  N="$(printf '%s\n' "$L1" | sed -E 's/^FLAG: ([0-9]+) findings$/\1/')"
  expect "example item count equals N" "$N" "$(printf '%s\n' "$EXM" | sed 1d | grep -c .)"
  [ "$N" -ge 2 ] && pass "example lists more than one finding (single pass)" || fail "example has N=$N; must show a multi-finding pass"
  i=0
  while IFS= read -r line; do
    i=$((i + 1))
    printf '%s\n' "$line" | grep -qE "^$i\. \[[^]]+\] [^:]+: .+ \(evidence: .+\)$" \
      && pass "example item $i matches item format" || fail "example item $i malformed: $line"
    cls="$(printf '%s\n' "$line" | sed -E 's/^[0-9]+\. \[([^]]+)\].*/\1/')"
    printf '%s\n' "$CLASSES" | grep -qxF -- "$cls" && pass "example item $i class '$cls' is allowed" || fail "example item $i class '$cls' not in closed set"
  done < <(printf '%s\n' "$EXM" | sed 1d)
else
  fail "example line 1 not 'FLAG: <N> findings': [$L1]"
fi

# Re-review mode: only prior findings plus regressions the revision introduced.
RR="$(md_section "$PMR" 'Re-review mode')"
has "re-review triggered by a prior numbered list" "$RR" "prior numbered findings list"
has "re-review scope" "$RR" "check only those findings plus regressions"
has "re-review raises nothing else" "$RR" "Raise nothing else"
has "regression items are marked" "$V" "(regression)"
has "re-review APPROVE condition" "$V" "APPROVE when every prior finding is resolved and no regression exists"

# Authority unchanged: binary, cannot rescue a rubric fail.
AU="$(md_section "$PMR" 'Authority')"
has "authority: may flag a rubric pass" "$AU" "You MAY flag a spec the rubric passed."
has "authority: never rescue a rubric fail" "$AU" "You may NEVER rescue a spec the rubric failed"
has "authority: binary verdict" "$AU" "Your verdict is **binary**"
finish

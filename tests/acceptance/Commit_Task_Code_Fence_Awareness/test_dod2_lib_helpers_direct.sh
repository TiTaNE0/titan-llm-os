#!/usr/bin/env bash
# DoD 2: lib_section boundary helpers called directly. Fenced headings neither end a section
# nor count as foreign; fence-free results are unchanged; nested/indented/mixed fences follow
# CommonMark.
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
source "$VAULT/.scripts/lib_section.sh"

f="$TMP/t.md"
cat > "$f" <<'F'
<!-- anchor -->
intro
```md
## ✅ Validator Report
## Strategy
```
````
```
## 📊 Verification Output
````
~~~
## Strategy
```
## Related Context
~~~
    ```
## Tail note
## ✅ Validator Report
F
# Line 17 is "## Tail note" (the indented ``` on 16 is not a fence); line 18 is the real template header.
end="$(section_end_line "$f" 1)"
[ "$end" = 17 ] && pass "section_end_line skips fenced template headers (end=17)" || fail "section_end_line=$end, want 17"
h="$(section_foreign_heading "$f" 1 "$end")"
[ "$h" = "## Tail note" ] && pass "foreign heading is the first unfenced one" || fail "foreign='$h', want '## Tail note'"
if section_foreign_heading "$f" 1 16 >/dev/null; then fail "fenced-only range reported foreign"; else pass "fenced-only range: no foreign heading"; fi

g="$TMP/plain.md"
printf '<!-- a -->\nbody\n## Strategy\n## ✅ Validator Report\nx\n' > "$g"
[ "$(section_end_line "$g" 1)" = 3 ] && pass "fence-free end unchanged" || fail "fence-free end $(section_end_line "$g" 1)"
[ "$(section_foreign_heading "$g" 1 3)" = "## Strategy" ] && pass "fence-free foreign unchanged" || fail "fence-free foreign"

u="$TMP/unclosed.md"
printf '<!-- a -->\n```\n## ✅ Validator Report\nx\n## 📊 Verification Output\n' > "$u"
[ "$(section_end_line "$u" 1)" = 2 ] && pass "unclosed fence falls back to fence-blind end" || fail "unclosed end $(section_end_line "$u" 1)"

n="$TMP/none.md"
printf '<!-- a -->\nx\ny\n' > "$n"
[ "$(section_end_line "$n" 1)" = 3 ] && pass "no header: file line count" || fail "none end $(section_end_line "$n" 1)"

# Backtick opener whose info string contains a backtick is not a fence (CommonMark).
b="$TMP/bt.md"
printf '<!-- a -->\n``` a`b\n## ✅ Validator Report\n' > "$b"
[ "$(section_end_line "$b" 1)" = 2 ] && pass "backtick-in-info-string is not a fence" || fail "bt end $(section_end_line "$b" 1)"
finish

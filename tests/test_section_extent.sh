#!/usr/bin/env bash
# test_section_extent.sh - cross-script section-extent regression (nested `## ` lines
# inside agent content must not end a template section). Runs every R case against a
# GREEN vault (working-tree scripts) and a RED vault (scripts from the pinned pre-fix
# ref); R cases must pass on GREEN and FAIL on RED. Temp-isolated; never touches the
# real vault state.
set -euo pipefail
unset TITAN_SESSION_ID GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
RED_REF="${SECTION_EXTENT_RED_REF:-a7e6603349692b9c71fdef4fb18732e3263e576f}"
FENCE_RED_REF="${SECTION_EXTENT_FENCE_RED_REF:-91c1dddecf803d46e1cf1c9ddd5d89ab23a721d3}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
TARGETS="write_task_section spec_rubric grep_section populate_summary author_contract run_gateway"

die() { echo "FAIL: $1" >&2; exit 1; }

git -C "$REPO_ROOT" rev-parse --verify --quiet "$RED_REF^{commit}" >/dev/null \
  || die "RED_REF does not resolve: $RED_REF"
git -C "$REPO_ROOT" rev-parse --verify --quiet "$FENCE_RED_REF^{commit}" >/dev/null \
  || die "FENCE_RED_REF does not resolve: $FENCE_RED_REF"

setup_vault() { # <dir> green|red
  local d="$1" mode="$2" s
  mkdir -p "$d/.scripts" "$d/04_Logs/Telemetry"
  printf '{\n  "persona": "Executioner",\n  "session_id": "smoke",\n  "started_at": "2026-06-17T00:00:00Z",\n  "agent_surface": "test"\n}\n' > "$d/.session_state.json"
  if [[ "$mode" == green ]]; then
    for s in $TARGETS commit_task lib_section persona_check emit_telemetry; do
      cp "$REPO_ROOT/.scripts/$s.sh" "$d/.scripts/"
    done
  elif [[ "$mode" == fred ]]; then
    for s in write_task_section commit_task lib_section persona_check emit_telemetry; do
      git -C "$REPO_ROOT" show "$FENCE_RED_REF:.scripts/$s.sh" > "$d/.scripts/$s.sh"
    done
    ! grep -q sec_fence "$d"/.scripts/*.sh || die "fred copies contain sec_fence (ref $FENCE_RED_REF is not pre-fix)"
  else
    for s in $TARGETS persona_check emit_telemetry; do
      git -C "$REPO_ROOT" show "$RED_REF:.scripts/$s.sh" > "$d/.scripts/$s.sh"
    done
    ! grep -q lib_section "$d"/.scripts/*.sh || die "RED copies contain lib_section (ref $RED_REF is not pre-fix)"
  fi
  chmod +x "$d/.scripts/"*.sh
}

mk_task() { # <path>
  cat > "$1" <<'T_EOF'
---
project: [[P]]
status: todo
type: task
---
# ⚡ Task: T

## 📋 Declarative Objective
- [ ] (What we want to achieve)

## 🎯 Definition of Done (Success Criteria)
- [ ] (Success criteria)

## 🧪 Verification Gateway
- [ ] **Test Command:** (Command to run)

## 📝 Agent Implementation Plan
> placeholder

## 🔬 Research Notes
> placeholder
<!-- write_task_section section=research_notes -->

## 📐 Spec
> placeholder
<!-- write_task_section section=spec -->

## ✅ Validator Report
> placeholder
<!-- write_task_section section=validator_report -->

## 📊 Verification Output
> placeholder
<!-- write_task_section section=verification_output -->

## 🏁 COMPLETION SUMMARY (Post-Mortem)
> gate
- **Technical Meat:** (Filled by agent)

## 🔗 Related Context
- **Skills:** none
T_EOF
}

spec_content() { # <file> <marker> [prose]
  cat > "$1" <<C_EOF
## Spec: T
Files touched: .scripts/foo.sh
$2
${3:-}
### Responsibility map
- foo: .scripts/foo.sh
### Context pack
- Read: .scripts/foo.sh:1-5 - x
### Open questions
None.
C_EOF
}

count() { grep -cF -- "$2" "$1" || true; } # <file> <fixed string>; 0 on none

# ---- R cases: $1 = vault dir; return 0 when behaviour is correct ----
case_wts_overwrite_replaces() {
  local d="$1" T="$1/T.md" rc snap
  mk_task "$T"
  spec_content "$d/c1" OLD_MARKER; spec_content "$d/c2" NEW_MARKER
  "$d/.scripts/write_task_section.sh" --task-path "$T" --section spec --source-persona Executioner --content-file "$d/c1" >/dev/null 2>&1 || return 1
  "$d/.scripts/write_task_section.sh" --task-path "$T" --section spec --source-persona Executioner --content-file "$d/c2" --overwrite >/dev/null 2>&1 || return 1
  [[ "$(count "$T" '## Spec: T')" -eq 1 ]] || return 1
  [[ "$(count "$T" OLD_MARKER)" -eq 0 ]] || return 1
  [[ "$(count "$T" NEW_MARKER)" -eq 1 ]] || return 1
  [[ "$(count "$T" '## ✅ Validator Report')" -eq 1 ]] || return 1
  snap="$d/snap"; cp "$T" "$snap"
  "$d/.scripts/write_task_section.sh" --task-path "$T" --section spec --source-persona Executioner --content-file "$d/c2" --overwrite >/dev/null 2>&1 || return 1
  cmp -s "$T" "$snap" || return 1
}

case_wts_nested_counts_populated() {
  local d="$1" T="$1/T.md" rc=0 snap
  mk_task "$T"; spec_content "$d/c1" OLD_MARKER; spec_content "$d/c2" NEW_MARKER
  "$d/.scripts/write_task_section.sh" --task-path "$T" --section spec --source-persona Executioner --content-file "$d/c1" >/dev/null 2>&1 || return 1
  snap="$d/snap"; cp "$T" "$snap"
  "$d/.scripts/write_task_section.sh" --task-path "$T" --section spec --source-persona Executioner --content-file "$d/c2" >/dev/null 2>&1 || rc=$?
  [[ "$rc" -eq 3 ]] || return 1
  cmp -s "$T" "$snap" || return 1
}

case_rubric_nested_spec() {
  local d="$1" T="$1/T.md" rc=0 err
  mk_task "$T"; spec_content "$d/c1" "clean body"
  "$d/.scripts/write_task_section.sh" --task-path "$T" --section spec --source-persona Executioner --content-file "$d/c1" >/dev/null 2>&1 || return 1
  "$d/.scripts/spec_rubric.sh" --task-path "$T" >/dev/null 2>&1 || return 1
  mk_task "$T"; spec_content "$d/c2" "decision is TBD here" "- see ??? and FIXME"
  "$d/.scripts/write_task_section.sh" --task-path "$T" --section spec --source-persona Executioner --content-file "$d/c2" >/dev/null 2>&1 || return 1
  err="$("$d/.scripts/spec_rubric.sh" --task-path "$T" 2>&1 >/dev/null)" || rc=$?
  [[ "$rc" -eq 3 ]] || return 1
  [[ "$err" == "RUBRIC FAIL: open questions remain in spec" ]] || return 1
}

case_grep_section_nested_populated() {
  local d="$1" T="$1/T.md" rc=0
  mk_task "$T"
  # Spec body whose first real content sits under a nested "## Spec: T" line.
  awk '{print} /write_task_section section=spec/ {print ""; print "## Spec: T"; print "real content"}' "$T" > "$d/n.md"
  "$d/.scripts/grep_section.sh" "$d/n.md" "Spec" populated >/dev/null 2>&1 || return 1
  "$d/.scripts/grep_section.sh" "$d/n.md" "Spec" empty >/dev/null 2>&1 && return 1
  return 0
}

case_author_contract_overwrite() {
  local d="$1" T="$1/T.md"
  mk_task "$T"
  printf -- '- [ ] OLD_MARKER\n## Criteria: heading\n- [ ] more old\n' > "$d/c1"
  printf -- '- [ ] NEW_MARKER\n## Criteria: heading\n- [ ] more new\n' > "$d/c2"
  "$d/.scripts/author_contract.sh" --task-path "$T" --section objective --source-persona Executioner --content-file "$d/c1" >/dev/null 2>&1 || return 1
  "$d/.scripts/author_contract.sh" --task-path "$T" --section objective --source-persona Executioner --content-file "$d/c2" --overwrite >/dev/null 2>&1 || return 1
  [[ "$(count "$T" OLD_MARKER)" -eq 0 && "$(count "$T" 'more old')" -eq 0 ]] || return 1
  [[ "$(count "$T" NEW_MARKER)" -eq 1 ]] || return 1
  [[ "$(count "$T" '## Criteria: heading')" -eq 1 ]] || return 1
  [[ "$(count "$T" '## 🎯 Definition of Done')" -eq 1 ]] || return 1
}

case_populate_summary_overwrite() {
  local d="$1" T="$1/T.md" rc=0
  mk_task "$T"
  printf -- '- **Technical Meat:** OLD_MARKER\n## Summary: heading\n- **Proof:** old\n' > "$d/c1"
  printf -- '- **Technical Meat:** NEW_MARKER\n## Summary: heading\n- **Proof:** new\n' > "$d/c2"
  "$d/.scripts/populate_summary.sh" --task-path "$T" --source-persona Executioner --content-file "$d/c1" >/dev/null 2>&1 || return 1
  "$d/.scripts/populate_summary.sh" --task-path "$T" --source-persona Executioner --content-file "$d/c2" >/dev/null 2>&1 || rc=$?
  [[ "$rc" -eq 3 ]] || return 1
  "$d/.scripts/populate_summary.sh" --task-path "$T" --source-persona Executioner --content-file "$d/c2" --overwrite >/dev/null 2>&1 || return 1
  [[ "$(count "$T" OLD_MARKER)" -eq 0 && "$(count "$T" 'Proof:** old')" -eq 0 ]] || return 1
  [[ "$(count "$T" NEW_MARKER)" -eq 1 ]] || return 1
  [[ "$(count "$T" '## Summary: heading')" -eq 1 ]] || return 1
  [[ "$(count "$T" '## 🔗 Related Context')" -eq 1 ]] || return 1
}

case_run_gateway_nested_cmd() {
  local d="$1" T="$1/T.md" out
  cat > "$T" <<'G_EOF'
---
project: [[P]]
status: todo
type: task
---
# ⚡ Task: T

## 🧪 Verification Gateway
- [ ] **Protocol:** exit 0.
## Gateway notes
- [ ] **Test Command:** `test 1 -eq 1`

## 📝 Agent Implementation Plan
> x
G_EOF
  out="$("$d/.scripts/run_gateway.sh" --task-path "$T" --source-persona Executioner 2>/dev/null)" || return 1
  printf '%s\n' "$out" | grep -qx 'GATEWAY_EXIT=0' || return 1
}

# ---- G-only cases ----
case_grep_section_generic_backcompat() {
  local d="$1"
  cat > "$d/g.md" <<'B_EOF'
# Doc

## Alpha
## Beta
body in beta
B_EOF
  # Non-template target: any ## closes it, so Alpha stays empty.
  "$d/.scripts/grep_section.sh" "$d/g.md" "Alpha" empty >/dev/null 2>&1 || return 1
  "$d/.scripts/grep_section.sh" "$d/g.md" "Beta" populated >/dev/null 2>&1 || return 1
}

case_template_rule_table() {
  local d="$1" loc line want got
  for loc in C inherited; do
    while IFS='|' read -r want line; do
      if [[ "$loc" == C ]]; then
        got="$(LC_ALL=C awk "$(. "$d/.scripts/lib_section.sh"; printf '%s' "$SECTION_AWK")"'{ print sec_is_template($0) }' <<<"$line")"
      else
        got="$(awk "$(. "$d/.scripts/lib_section.sh"; printf '%s' "$SECTION_AWK")"'{ print sec_is_template($0) }' <<<"$line")"
      fi
      [[ "$got" == "$want" ]] || { echo "  rule[$loc] want=$want got=$got: $line" >&2; return 1; }
    done <<'TBL'
1|## 📋 Declarative Objective
1|## 🎯 Definition of Done (Success Criteria)
1|## 🧪 Verification Gateway
1|## 📝 Agent Implementation Plan
1|## 🔬 Research Notes
1|## 📐 Spec
1|## ✅ Validator Report
1|## 📊 Verification Output
1|## 🏁 COMPLETION SUMMARY (Post-Mortem)
1|## 🔗 Related Context
1|## ⚠️ Spec
1|## Spec
1|## Spec (draft)
1|## Spec  
0|## Spec: X
0|## Validator Report: X
0|## Spec: Research Notes Fix
0|### 📐 Spec
0|## Other
0|# ⚡ Task: T
TBL
  done
}

case_guard_foreign_heading_refuses() {
  local d="$1" T="$1/T.md" rc snap
  snap="$d/snap"
  # write_task_section: populate spec, hand-insert ## Strategy into it, overwrite must refuse.
  mk_task "$T"; spec_content "$d/c1" OLD_MARKER; spec_content "$d/c2" NEW_MARKER
  "$d/.scripts/write_task_section.sh" --task-path "$T" --section spec --source-persona Executioner --content-file "$d/c1" >/dev/null 2>&1 || return 1
  awk '{print} /^Files touched/ {print "## Strategy"; print "hand written"}' "$T" > "$d/h.md" && mv "$d/h.md" "$T"
  cp "$T" "$snap"; rc=0
  "$d/.scripts/write_task_section.sh" --task-path "$T" --section spec --source-persona Executioner --content-file "$d/c2" --overwrite >/dev/null 2>"$d/err" || rc=$?
  [[ "$rc" -eq 3 ]] || return 1
  grep -qF "E3: section contains hand-authored heading '## Strategy'; refusing write (move it out of the section first)" "$d/err" || return 1
  cmp -s "$T" "$snap" || return 1
  # author_contract
  mk_task "$T"
  printf -- '- [ ] OLD\n## Strategy\n- [ ] x\n' > "$d/c1"
  "$d/.scripts/author_contract.sh" --task-path "$T" --section objective --source-persona Executioner --content-file "$d/c1" >/dev/null 2>&1 || return 1
  cp "$T" "$snap"; rc=0
  "$d/.scripts/author_contract.sh" --task-path "$T" --section objective --source-persona Executioner --content-file "$d/c1" --overwrite >/dev/null 2>"$d/err" || rc=$?
  [[ "$rc" -eq 3 ]] || return 1
  grep -q "^E3: section contains hand-authored heading '## Strategy'" "$d/err" || return 1
  cmp -s "$T" "$snap" || return 1
  # populate_summary
  mk_task "$T"
  printf -- '- **Technical Meat:** OLD\n## Strategy\n- **Proof:** old\n' > "$d/c1"
  "$d/.scripts/populate_summary.sh" --task-path "$T" --source-persona Executioner --content-file "$d/c1" >/dev/null 2>&1 || return 1
  cp "$T" "$snap"; rc=0
  "$d/.scripts/populate_summary.sh" --task-path "$T" --source-persona Executioner --content-file "$d/c1" --overwrite >/dev/null 2>"$d/err" || rc=$?
  [[ "$rc" -eq 3 ]] || return 1
  grep -q "^E3: section contains hand-authored heading '## Strategy'" "$d/err" || return 1
  cmp -s "$T" "$snap" || return 1
}

case_guard_no_overwrite_refuses() {
  local d="$1" T="$1/T.md" rc=0 snap="$1/snap" ph
  mk_task "$T"
  ph="$(grep -n 'Verification Gateway' "$T" | head -1 | cut -d: -f1)"
  [[ -n "$ph" ]] || return 1
  printf '## Context\nHAND_WRITTEN_CONTEXT\n' > "$d/c1"
  awk -v n="$ph" '{print} NR==n {print ""; print "## Context"; print "HAND_WRITTEN_CONTEXT"}' "$T" > "$d/h.md" && mv "$d/h.md" "$T"
  printf -- '- [ ] NEW\n' > "$d/c2"
  cp "$T" "$snap"
  "$d/.scripts/author_contract.sh" --task-path "$T" --section gateway --source-persona Executioner --content-file "$d/c2" >/dev/null 2>"$d/err" || rc=$?
  [[ "$rc" -eq 3 ]] || return 1
  grep -qF "refusing write" "$d/err" || return 1
  cmp -s "$T" "$snap" || return 1
}

case_guard_agent_subheading_allowed() {
  local d="$1" T="$1/T.md"
  mk_task "$T"; spec_content "$d/c1" OLD_MARKER; spec_content "$d/c2" NEW_MARKER
  printf '## Criteria: T\nx\n## Summary: T\ny\n' >> "$d/c2"
  "$d/.scripts/write_task_section.sh" --task-path "$T" --section spec --source-persona Executioner --content-file "$d/c1" >/dev/null 2>&1 || return 1
  "$d/.scripts/write_task_section.sh" --task-path "$T" --section spec --source-persona Executioner --content-file "$d/c2" --overwrite >/dev/null 2>&1 || return 1
  [[ "$(count "$T" NEW_MARKER)" -eq 1 && "$(count "$T" OLD_MARKER)" -eq 0 ]] || return 1
}

case_agent_subheading_rule_table() {
  local d="$1" loc line want got
  for loc in C inherited; do
  while IFS='|' read -r want line; do
    if [[ "$loc" == C ]]; then
      got="$(LC_ALL=C awk "$(. "$d/.scripts/lib_section.sh"; printf '%s' "$SECTION_AWK")"'{ print sec_is_agent_subheading($0) }' <<<"$line")"
    else
      got="$(awk "$(. "$d/.scripts/lib_section.sh"; printf '%s' "$SECTION_AWK")"'{ print sec_is_agent_subheading($0) }' <<<"$line")"
    fi
    [[ "$got" == "$want" ]] || { echo "  agent-rule[$loc] want=$want got=$got: $line" >&2; return 1; }
  done <<'TBL'
1|## Spec: T
1|## 📐 Spec: T
1|## Validator Report: T
1|## Research report: T
1|## Criteria: T
1|## Summary: T
1|## Gateway: T
0|## Strategy
0|## Spec
0|## Context
0|## Spec:T
0|## : T
0|### Spec: T
0|## 🧭 Strategy: constraint, not correction
1|## Validator Report (re-audit): T
0|## Strategy (x): T
TBL
  done
}

# ---- F cases (fenced code is opaque): pass on GREEN, fail on fred ----
mk_ct_repo() { # <dir>
  mkdir -p "$1"
  git -C "$1" init -q -b main
  git -C "$1" config user.name t; git -C "$1" config user.email t@t
  echo a > "$1/a.txt"; git -C "$1" add a.txt; git -C "$1" commit -q -m init
}

run_ct() { # <vault> <repo> -> sets CT_RC, CT_OUT, CT_ERR
  CT_RC=0
  CT_OUT="$(cd "$2" && "$1/.scripts/commit_task.sh" --task-path "$1/T.md" --source-persona Executioner 2>"$1/ct_err")" || CT_RC=$?
  CT_ERR="$(cat "$1/ct_err")"
}

case_ct_fence_backtick() {
  local d="$1"
  mk_ct_repo "$d/repo"
  cat > "$d/T.md" <<'T_EOF'
# Task

## 📐 Spec

## Spec: T

Usage example:

```markdown
## Usage
### Example
```

### Files touched
- [EDIT] `a.txt`

## ✅ Validator Report
T_EOF
  echo b >> "$d/repo/a.txt"
  run_ct "$d" "$d/repo"
  [[ "$CT_RC" -eq 0 ]] || return 1
  grep -qx 'COMMIT_STAGED=1' <<<"$CT_OUT"
}

case_ct_fence_tilde_long() {
  local d="$1"
  mk_ct_repo "$d/repo"
  cat > "$d/T.md" <<'T_EOF'
# Task

## 📐 Spec

## Spec: T

~~~
## X
~~~

````
```
### Files touched
- [EDIT] `decoy.txt`
````

### Files touched
- [EDIT] `a.txt`

## ✅ Validator Report
T_EOF
  echo b >> "$d/repo/a.txt"; echo d > "$d/repo/decoy.txt"
  run_ct "$d" "$d/repo"
  [[ "$CT_RC" -eq 0 ]] || return 1
  grep -qx 'COMMIT_STAGED=1' <<<"$CT_OUT" || return 1
  [[ "$(git -C "$d/repo" show --name-only --format= HEAD)" == "a.txt" ]]
}

case_wts_fence_foreign_heading() {
  local d="$1" T="$1/T.md"
  mk_task "$T"
  spec_content "$d/c1" OLD_MARKER '```
## Strategy
```'
  spec_content "$d/c2" NEW_MARKER
  "$d/.scripts/write_task_section.sh" --task-path "$T" --section spec --source-persona Executioner --content-file "$d/c1" >/dev/null 2>&1 || return 1
  "$d/.scripts/write_task_section.sh" --task-path "$T" --section spec --source-persona Executioner --content-file "$d/c2" --overwrite >/dev/null 2>&1 || return 1
  [[ "$(count "$T" OLD_MARKER)" -eq 0 && "$(count "$T" NEW_MARKER)" -eq 1 ]]
}

case_wts_fence_template_heading() {
  local d="$1" T="$1/T.md"
  mk_task "$T"
  spec_content "$d/c1" "first" '~~~
## ✅ Validator Report
~~~
OLD_MARKER'
  spec_content "$d/c2" NEW_MARKER
  "$d/.scripts/write_task_section.sh" --task-path "$T" --section spec --source-persona Executioner --content-file "$d/c1" >/dev/null 2>&1 || return 1
  "$d/.scripts/write_task_section.sh" --task-path "$T" --section spec --source-persona Executioner --content-file "$d/c2" --overwrite >/dev/null 2>&1 || return 1
  [[ "$(count "$T" OLD_MARKER)" -eq 0 ]] || return 1
  [[ "$(count "$T" '## ✅ Validator Report')" -eq 1 ]]
}

# ---- G-only fence cases ----
case_wts_unclosed_fence_fallback() {
  local d="$1" T="$1/T.md"
  mk_task "$T"
  spec_content "$d/c1" OLD_MARKER '```
unclosed'
  spec_content "$d/c2" NEW_MARKER
  "$d/.scripts/write_task_section.sh" --task-path "$T" --section spec --source-persona Executioner --content-file "$d/c1" >/dev/null 2>&1 || return 1
  "$d/.scripts/write_task_section.sh" --task-path "$T" --section spec --source-persona Executioner --content-file "$d/c2" --overwrite >/dev/null 2>&1 || return 1
  [[ "$(count "$T" '## ✅ Validator Report')" -eq 1 ]] || return 1
  [[ "$(count "$T" '## 📊 Verification Output')" -eq 1 ]] || return 1
  [[ "$(count "$T" '## 🔗 Related Context')" -eq 1 ]] || return 1
  [[ "$(count "$T" OLD_MARKER)" -eq 0 ]]
}

case_ct_unclosed_fence_refuses() {
  local d="$1" before
  mk_ct_repo "$d/repo"
  cat > "$d/T.md" <<'T_EOF'
# Task

## 📐 Spec

## Spec: T

```
unclosed

### Files touched
- [EDIT] `a.txt`

## ✅ Validator Report
T_EOF
  echo b >> "$d/repo/a.txt"
  before="$(git -C "$d/repo" rev-parse HEAD)"
  run_ct "$d" "$d/repo"
  [[ "$CT_RC" -eq 3 ]] || return 1
  grep -qF 'E3: unclosed code fence in the Spec section' <<<"$CT_ERR" || return 1
  [[ "$(git -C "$d/repo" rev-parse HEAD)" == "$before" ]]
}

case_wts_unclosed_fence_later_fence() {
  local d="$1" T="$1/T.md"
  mk_task "$T"
  awk '{ print } /^## 📊 Verification Output/ { print "```bash"; print "echo LATER_MARKER"; print "```" }' "$T" > "$d/T2" && mv "$d/T2" "$T"
  spec_content "$d/c1" OLD_MARKER '```
unclosed'
  spec_content "$d/c2" NEW_MARKER
  "$d/.scripts/write_task_section.sh" --task-path "$T" --section spec --source-persona Executioner --content-file "$d/c1" >/dev/null 2>&1 || return 1
  "$d/.scripts/write_task_section.sh" --task-path "$T" --section spec --source-persona Executioner --content-file "$d/c2" --overwrite >/dev/null 2>&1 || return 1
  [[ "$(count "$T" '## ✅ Validator Report')" -eq 1 ]] || return 1
  [[ "$(count "$T" '## 📊 Verification Output')" -eq 1 ]] || return 1
  [[ "$(count "$T" '## 🏁 COMPLETION SUMMARY')" -eq 1 ]] || return 1
  [[ "$(count "$T" LATER_MARKER)" -eq 1 ]] || return 1
  [[ "$(count "$T" OLD_MARKER)" -eq 0 && "$(count "$T" NEW_MARKER)" -eq 1 ]]
}

case_ct_unclosed_fence_later_fence() {
  local d="$1" before
  mk_ct_repo "$d/repo"
  cat > "$d/T.md" <<'T_EOF'
# Task

## 📐 Spec

## Spec: T

```
unclosed

## ✅ Validator Report

## 📊 Verification Output
```bash
echo hi
```

### Files touched
- [EDIT] `decoy.txt`

## 🏁 COMPLETION SUMMARY
T_EOF
  echo d > "$d/repo/decoy.txt"
  before="$(git -C "$d/repo" rev-parse HEAD)"
  run_ct "$d" "$d/repo"
  [[ "$CT_RC" -eq 3 ]] || return 1
  [[ "$(git -C "$d/repo" rev-parse HEAD)" == "$before" ]]
}

case_ct_unclosed_fence_nontemplate_end() {
  local d="$1" before
  mk_ct_repo "$d/repo"
  cat > "$d/T.md" <<'T_EOF'
# Task

## 📐 Spec

## Spec: T

```
unclosed

## ✅ Validator Report

```bash
echo hi
```

### Files touched
- [EDIT] `decoy.txt`

## Validator Report: T
T_EOF
  echo d > "$d/repo/decoy.txt"
  before="$(git -C "$d/repo" rev-parse HEAD)"
  run_ct "$d" "$d/repo"
  [[ "$CT_RC" -eq 3 ]] || return 1
  [[ "$(git -C "$d/repo" rev-parse HEAD)" == "$before" ]]
}

case_ct_closed_fence_quotes_agent_heading() {
  local d="$1"
  mk_ct_repo "$d/repo"
  cat > "$d/T.md" <<'T_EOF'
# Task

## 📐 Spec

## Spec: T

```markdown
## Spec: Example
## Summary: x
## Validator Report: y
```

### Files touched
- [EDIT] `a.txt`

## ✅ Validator Report
T_EOF
  echo b >> "$d/repo/a.txt"; echo d > "$d/repo/decoy.txt"
  run_ct "$d" "$d/repo"
  [[ "$CT_RC" -eq 0 ]] || return 1
  grep -qx 'COMMIT_STAGED=1' <<<"$CT_OUT" || return 1
  [[ "$(git -C "$d/repo" show --name-only --format= HEAD)" == "a.txt" ]]
}

case_ct_closed_fence_quotes_earlier_template() {
  local d="$1"
  mk_ct_repo "$d/repo"
  cat > "$d/T.md" <<'T_EOF'
# Task

## 📐 Spec

## Spec: T

```markdown
## 📐 Spec
## 🎯 Definition of Done
```

### Files touched
- [EDIT] `a.txt`

## ✅ Validator Report
T_EOF
  echo b >> "$d/repo/a.txt"; echo d > "$d/repo/decoy.txt"
  run_ct "$d" "$d/repo"
  [[ "$CT_RC" -eq 0 ]] || return 1
  grep -qx 'COMMIT_STAGED=1' <<<"$CT_OUT" || return 1
  [[ "$(git -C "$d/repo" show --name-only --format= HEAD)" == "a.txt" ]]
}

case_fence_rule_table() {
  local d="$1" loc want got seq
  for loc in C inherited; do
  while IFS='|' read -r want seq; do
    seq="${seq//;/$'\n'}"
    if [[ "$loc" == C ]]; then
      got="$(LC_ALL=C awk "$(. "$d/.scripts/lib_section.sh"; printf '%s' "$SECTION_AWK")"'{ printf "%s", sec_fence($0) } END { print "" }' <<<"$seq")"
    else
      got="$(awk "$(. "$d/.scripts/lib_section.sh"; printf '%s' "$SECTION_AWK")"'{ printf "%s", sec_fence($0) } END { print "" }' <<<"$seq")"
    fi
    [[ "$got" == "$want" ]] || { echo "  fence-rule[$loc] want=$want got=$got: $seq" >&2; return 1; }
  done <<'TBL'
1110|```;x;```;y
110|```;```;x
11110|````;```;x;````;y
1110|~~~;```;~~~;y
0|    ```
111|```;``` x;y
0|``` a`b
TBL
  done
}

R_CASES="wts_overwrite_replaces wts_nested_counts_populated rubric_nested_spec grep_section_nested_populated author_contract_overwrite populate_summary_overwrite run_gateway_nested_cmd"
F_CASES="ct_fence_backtick ct_fence_tilde_long wts_fence_foreign_heading wts_fence_template_heading"
G_CASES="wts_unclosed_fence_fallback ct_unclosed_fence_refuses wts_unclosed_fence_later_fence ct_unclosed_fence_later_fence ct_unclosed_fence_nontemplate_end ct_closed_fence_quotes_agent_heading ct_closed_fence_quotes_earlier_template fence_rule_table grep_section_generic_backcompat template_rule_table guard_foreign_heading_refuses guard_no_overwrite_refuses guard_agent_subheading_allowed agent_subheading_rule_table"

run_case() { # <name> <mode> -> 0 if case passed
  local dir="$TMP/$2-$1"
  setup_vault "$dir" "$2"
  "case_$1" "$dir"
}

for c in $R_CASES $F_CASES $G_CASES; do
  if run_case "$c" green; then echo "GREEN ok:   $c"; else die "GREEN case failed: $c"; fi
done

for c in $R_CASES; do
  if run_case "$c" red; then die "RED case unexpectedly passed on $RED_REF: $c"; else echo "RED fails:  $c (expected)"; fi
done

for c in $F_CASES; do
  if run_case "$c" fred; then die "fred case unexpectedly passed on $FENCE_RED_REF: $c"; else echo "RED fails:  $c (expected)"; fi
done

echo "TEST: OK"

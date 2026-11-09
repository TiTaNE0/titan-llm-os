#!/usr/bin/env bash
# test_spec_gate_hardening.sh - gateway for Spec_Gate_And_Test_Isolation_Hardening.
# RED/GREEN proofs for the spec_rubric (b)/(c2) checks, the grep_section header normaliser,
# the install.sh bindings error, the live-telemetry checksum around every kit suite, and the
# aggregator skip-env wiring. Vault scripts only ever run from scratch copies, never live.
# SGH_SKIP_SUITES=1 skips the suite/live-telemetry section (aggregators use it to avoid recursion).
set -uo pipefail
unset TITAN_SESSION_ID TELEMETRY_DIR ACC_SKIP_GATEWAY

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
KIT="$(cd "${KIT_ROOT:-$HOME/AI_Workflow/claude-agent-kit}" && pwd -P)"
TMP="$(cd "$(mktemp -d)" && pwd -P)"; trap 'rm -rf "$TMP"' EXIT
RED_REF="${SGH_RED_REF:-0b2fe64d2985da00a87170710c42b0a4b1d34e87}"
FAILS=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAILS=$((FAILS + 1)); }
eq() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (got '$2', want '$3')"; fi; }

# --- scratch vaults: G = working tree, R = pre-fix ref ---------------------------------
G="$TMP/G"; R="$TMP/R"; mkdir -p "$G/.scripts" "$R/.scripts"
SCRIPTS="spec_rubric.sh grep_section.sh lib_section.sh"
if ! git -C "$REPO_ROOT" cat-file -e "$RED_REF^{commit}" 2>/dev/null; then
  fail "RED ref $RED_REF does not resolve"; echo "$FAILS check(s) failed"; exit 1
fi
for f in $SCRIPTS; do
  cp "$REPO_ROOT/.scripts/$f" "$G/.scripts/$f"
  git -C "$REPO_ROOT" show "$RED_REF:.scripts/$f" > "$R/.scripts/$f"
  chmod +x "$G/.scripts/$f" "$R/.scripts/$f"
done
grep -qF 'Files touched' "$R/.scripts/spec_rubric.sh" && fail "RED spec_rubric.sh is not pre-fix" || pass "RED spec_rubric.sh is pre-fix"
grep -qF 'sec_heading_name' "$R/.scripts/lib_section.sh" && fail "RED lib_section.sh is not pre-fix" || pass "RED lib_section.sh is pre-fix"
grep -qF 'sec_heading_name' "$G/.scripts/lib_section.sh" && pass "GREEN lib_section.sh has sec_heading_name" || fail "GREEN lib_section.sh lacks sec_heading_name"

# --- fixtures ---------------------------------------------------------------------------
# spec <file> <body>: task whose Spec holds the full template blockquote plus <body>.
spec() {
  {
    printf -- '---\nproject: [[P]]\nstatus: in_progress\ntype: task\n---\n\n# Task\n\n## 📐 Spec\n'
    printf -- '> Populated by `invoke_spec_writer` during `/execute_task` step 7, after user approval\n> at the spec gate. May be empty for tasks not run through `/execute_task`.\n'
    printf -- '<!-- write_task_section section=spec -->\n\n'
    printf -- '%s\n\n' "$2"
    printf -- '## ✅ Validator Report\n> placeholder\n'
  } > "$1"
}
MAP=$'### Responsibility map\n- Rubric: `.scripts/spec_rubric.sh`\n'
PACK=$'### Context pack\n- Read: `.scripts/spec_rubric.sh:1-20` - checks\n'
PROSE='Edit the gate, see .scripts/foo.sh for the shape.'
FILES=$'### Files touched\n- [EDIT] `.scripts/foo.sh`\n'
oq() { printf '### Open questions\n%s\n' "$1"; }
NONE="$(oq 'None.')"

rub() { # vault file -> RC, ERR
  RC=0; ERR="$(bash "$1/.scripts/spec_rubric.sh" --task-path "$2" 2>&1 >/dev/null)" || RC=$?
}
both() { # name body greenrc redrc(or "-") [stderr-prefix]
  local f="$TMP/$1.md"; spec "$f" "$2"
  rub "$G" "$f"; eq "$1 GREEN exit" "$RC" "$3"
  if [ -n "${5:-}" ]; then
    case "$ERR" in "$5"*) pass "$1 GREEN stderr" ;; *) fail "$1 GREEN stderr (got '$ERR')" ;; esac
  fi
  if [ "$4" != "-" ]; then rub "$R" "$f"; eq "$1 RED exit" "$RC" "$4"; fi
}
MSG_B='RUBRIC FAIL: no file-change list in spec'
MSG_C='RUBRIC FAIL: open questions remain in spec'

# --- DoD 1: Files touched ---------------------------------------------------------------
both d1_no_files_block "$PROSE
$MAP$PACK$NONE" 3 0 "$MSG_B"
rub "$G" "$TMP/d1_no_files_block.md"; eq "d1_no_files_block exact message" "$ERR" "$MSG_B"
both d1_heading_no_marker "$PROSE
$MAP$PACK### Files touched
- \`.scripts/foo.sh\` - edited
$NONE" 3 0 "$MSG_B"
both d1_marker_in_fence_heading "$PROSE
$MAP$PACK\`\`\`
### Files touched
- [EDIT] \`.scripts/foo.sh\`
\`\`\`
$NONE" 3 - "$MSG_B"
both d1_ok "$PROSE
$MAP$PACK$FILES$NONE" 0 0
both d1_ok_h2 "$PROSE
$MAP$PACK## Files touched
- [EDIT] \`.scripts/foo.sh\`
$NONE" 0 -
both d1_ok_h4 "$PROSE
$MAP$PACK#### Files touched
- [EDIT] \`.scripts/foo.sh\`
$NONE" 0 -
both d1_marker_after_block "$PROSE
$MAP$PACK### Files touched
- nothing here
### Risks
- [EDIT] \`.scripts/foo.sh\`
$NONE" 3 - "$MSG_B"

# --- DoD 2: OQ subsection None-only -----------------------------------------------------
both d2_numbered "$PROSE
$MAP$PACK$FILES$(oq '1. Which file owns the retry path?')" 3 0 "$MSG_C"
for v in 'None' 'None.' 'none' 'NONE.'; do
  both "d2_none_$v" "$PROSE
$MAP$PACK$FILES$(oq "$v")" 0 -
done
both d2_none_blank "$PROSE
$MAP$PACK$FILES$(oq $'None.\n\n')" 0 -
both d2_none_prose "$PROSE
$MAP$PACK$FILES$(oq 'None blocking.')" 3 0 "$MSG_C"
both d2_two_blocks "$PROSE
$MAP$PACK$FILES$NONE
### Open questions (for spec gate)
- Is the retry path owned here?" 3 - "$MSG_C"

# --- DoD 3: grep_section header normaliser ----------------------------------------------
gs() { # vault file mode -> RC
  RC=0; bash "$1/.scripts/grep_section.sh" "$2" "Validator Report" "$3" >/dev/null 2>&1 || RC=$?
}
d3() { # file agent-heading
  {
    printf -- '---\ntype: task\n---\n\n# Task\n\n## 📐 Spec\n> x\n\nbody\n\n%s\nagent wrote real content here\n\n' "$2"
    printf -- '## ✅ Validator Report\n> placeholder\n<!-- write_task_section section=validator -->\n'
  } > "$1"
}
d3 "$TMP/d3a.md" '## Spec: Validator Report'
gs "$G" "$TMP/d3a.md" empty; eq "d3_agent_heading GREEN exit" "$RC" 0
gs "$R" "$TMP/d3a.md" empty; eq "d3_agent_heading RED exit" "$RC" 1
d3 "$TMP/d3b.md" '## ⚡ Task: Validator Report'
gs "$G" "$TMP/d3b.md" empty; eq "d3_agent_heading two-token GREEN exit" "$RC" 0

printf -- '# T\n\n## ✅ Validator Report\ncontent\n' > "$TMP/d3c.md"
gs "$G" "$TMP/d3c.md" populated; eq "d3_emoji_still_matches populated" "$RC" 0
printf -- '# T\n\n## Validator Report\ncontent\n' > "$TMP/d3d.md"
gs "$G" "$TMP/d3d.md" populated; eq "d3_plain_still_matches populated" "$RC" 0

HDRS=$'## 📋 Declarative Objective\n## Declarative Objective\n## 🏁 COMPLETION SUMMARY (Post-Mortem)\n## 🔗 Related Context\n## 📐 Spec\n## Spec: T\n## Spec: Validator Report\n## ⚡ Task: Validator Report\n## 1. Spec\n## [x] Spec\n## Strategy'
tbl() { ( . "$1/.scripts/lib_section.sh"; printf '%s\n' "$HDRS" | awk "$SECTION_AWK"'{ print sec_tpl_idx($0) "," sec_is_template($0) }' ); }
[ "$(tbl "$G")" = "$(tbl "$R")" ] && pass "d3_template_table_unchanged" || fail "d3_template_table_unchanged"

# --- DoD 4: detector not vacuous ----------------------------------------------------------
V="$TMP/dv"; mkdir -p "$V/.scripts" "$V/04_Logs/Telemetry"
cp "$REPO_ROOT/.scripts/emit_telemetry.sh" "$REPO_ROOT/.scripts/telemetry_start.sh" "$V/.scripts/"
MONTH="$(date -u +%Y-%m)"
printf '{"seed":1}\n' > "$V/04_Logs/Telemetry/$MONTH.jsonl"
snap() { local f; for f in "$1"/*.jsonl; do [ -f "$f" ] && cksum "$f"; done; return 0; }
s0="$(snap "$V/04_Logs/Telemetry")"; s1="$(snap "$V/04_Logs/Telemetry")"
eq "d4_detector no emit -> snapshots equal" "$s1" "$s0"
env -u TELEMETRY_DIR bash "$V/.scripts/emit_telemetry.sh" sgh_probe success 5 null Executioner >/dev/null 2>&1
s2="$(snap "$V/04_Logs/Telemetry")"
[ -n "$s0" ] && [ "$s2" != "$s0" ] && pass "d4_detector_red emit changes snapshot" || fail "d4_detector_red emit did not change snapshot"

# --- DoD 5: install.sh bindings spaces ----------------------------------------------------
mkdir -p "$TMP/home" "$TMP/xdg" "$TMP/kitred"
sed "/spaces around '='/d" "$KIT/install.sh" > "$TMP/kitred/install.sh"
oc() { # install-script bindings-file -> RC, $TMP/err
  RC=0
  rm -rf "$TMP/oc"
  env HOME="$TMP/home" XDG_CONFIG_HOME="$TMP/xdg" bash "$1" setup-opencode --path "$TMP/oc/agent" --bindings "$2" >"$TMP/out" 2>"$TMP/err" || RC=$?
}
i=0
for c in 'gate = a/b' 'gate =a/b' 'gate= a/b'; do
  i=$((i + 1)); printf '%s\n' "$c" > "$TMP/b$i"
  oc "$KIT/install.sh" "$TMP/b$i"
  eq "d5_spaces '$c' GREEN exit" "$RC" 2
  grep -qF "spaces around '=' are not allowed" "$TMP/err" && pass "d5_spaces '$c' GREEN message" || fail "d5_spaces '$c' GREEN message"
  eq "d5_spaces '$c' GREEN writes nothing" "$(find "$TMP/oc" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')" 0
  oc "$TMP/kitred/install.sh" "$TMP/b$i"
  eq "d5_spaces '$c' RED exit" "$RC" 2
  grep -qF "spaces around '='" "$TMP/err" && fail "d5_spaces '$c' RED still has phrase" || pass "d5_spaces '$c' RED lacks phrase"
done
printf 'gate=kitfixture/m\n' > "$TMP/bok"
oc "$KIT/install.sh" "$TMP/bok"
grep -F '[ERROR]' "$TMP/err" | grep -qF "$TMP/bok" && fail "d5 positive control: bindings error on valid file" || pass "d5 positive control: valid binding parses"

echo "NOTE: DoD 6 is an Architect /graduate of Tool_Registry grep_section; not machine-checked"

# --- DoD 7: aggregator wiring -----------------------------------------------------------
for f in test_kit_telemetry_isolation.sh test_chain_consolidation.sh test_chain_targeted_tests.sh test_pm_reviewer_single_pass.sh test_hook_argument_scope.sh test_macro_start_timestamp.sh; do
  grep -qF '[ "$b" = test_spec_gate_hardening.sh ] && envp="SGH_SKIP_SUITES=1"' "$REPO_ROOT/tests/$f" && pass "$f wires SGH_SKIP_SUITES" || fail "$f missing SGH_SKIP_SUITES wiring"
done

# --- corpus note (informational) ----------------------------------------------------------
corpus() { # label files...
  local label="$1" f g r; shift
  for f in "$@"; do
    [ -f "$f" ] || continue
    rub "$R" "$f"; r="$RC"; rub "$G" "$f"; g="$RC"
    [ "$r" = 0 ] && [ "$g" = 3 ] && echo "NEWLY FAILS${label:+ ($label)}: $f"
  done
}
corpus "" "$REPO_ROOT"/02_Tasks/*/*.md
corpus ARCHIVE "$REPO_ROOT"/99_Archive/Tasks/*/*/*.md

# --- suites (skipped under SGH_SKIP_SUITES=1) ---------------------------------------------
if [ "${SGH_SKIP_SUITES:-0}" = 1 ]; then
  echo "suites skipped: SGH_SKIP_SUITES=1"
else
  # Leak check uses the mirror-based gateway (private vault mirror, also runs every kit suite);
  # the live log is never asserted because other sessions write it concurrently.
  if ( cd "$REPO_ROOT" && bash tests/test_kit_telemetry_isolation.sh >"$TMP/kti.out" 2>&1 ); then
    pass "kit suites leave no telemetry leak (mirror gateway green)"
  else
    fail "kit telemetry isolation gateway failed"; grep '^FAIL' "$TMP/kti.out"
  fi

  n=0
  for t in "$REPO_ROOT"/tests/test_*.sh "$REPO_ROOT"/tests/smoke_*.sh; do
    [ -f "$t" ] || continue
    b="$(basename "$t")"
    [ "$b" = test_spec_gate_hardening.sh ] && continue
    n=$((n + 1))
    if [ "$b" = test_chain_consolidation.sh ]; then
      out="$( cd "$REPO_ROOT" && CHAIN_SKIP_SUITES=1 bash "tests/$b" 2>&1 )"
      if ! printf '%s\n' "$out" | grep -q '^FAIL:' && printf '%s\n' "$out" | grep -qF 'suites skipped: not a gateway pass'; then
        pass "vault $b (skip mode)"; else fail "vault $b (skip mode)"; fi
      continue
    fi
    envp=""; [ "$b" = test_thin_orchestrator.sh ] && envp="THIN_ORCH_SKIP_SUITES=1"; [ "$b" = test_pm_reviewer_single_pass.sh ] && envp="PMR_SKIP_SUITES=1"; [ "$b" = test_kit_telemetry_isolation.sh ] && envp="KTI_SKIP_SUITES=1"; [ "$b" = test_chain_targeted_tests.sh ] && envp="CTT_SKIP_SUITES=1"; [ "$b" = test_macro_start_timestamp.sh ] && envp="MST_SKIP_SUITES=1"; [ "$b" = test_hook_argument_scope.sh ] && envp="HAS_SKIP_SUITES=1"; [ "$b" = test_codemap_refresh.sh ] && envp="CMR_SKIP_SUITES=1"
    if ( cd "$REPO_ROOT" && env $envp bash "tests/$b" >/dev/null 2>&1 ); then pass "vault $b"; else fail "vault $b"; fi
  done
  [ "$n" -ge 1 ] || fail "vault suite glob matched nothing"
fi

if [ "$FAILS" -eq 0 ]; then echo "ALL GREEN"; exit 0; fi
echo "$FAILS check(s) failed"; exit 1

#!/usr/bin/env bash
# Shared setup for Spec_Gate_And_Test_Isolation_Hardening acceptance tests.
# Vault scripts run only from scratch copies (GREEN = working tree, RED = pre-fix ref).
# Every write goes to a mktemp dir; the live 04_Logs/Telemetry is never written or counted.
set -uo pipefail
unset TITAN_SESSION_ID TELEMETRY_DIR

VAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
KIT="$(cd "${KIT_ROOT:-$HOME/AI_Workflow/claude-agent-kit}" && pwd -P)"
RED_REF="${SGH_RED_REF:-0b2fe64d2985da00a87170710c42b0a4b1d34e87}"

TMP="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

FAILED=0
fail() { echo "FAIL: $1" >&2; FAILED=1; }
pass() { echo "ok: $1"; }
finish() { [ "$FAILED" -eq 0 ] && { echo "PASS"; exit 0; }; echo "FAILED" >&2; exit 1; }
expect() { [ "$3" = "$2" ] && pass "$1" || fail "$1: expected [$2], got [$3]"; }

# build_vaults: $G/.scripts (working tree) and $R/.scripts (pre-fix ref) with the three
# scripts under test. Aborts if the RED copy is not really pre-fix.
build_vaults() {
  G="$TMP/green"; R="$TMP/red"
  mkdir -p "$G/.scripts" "$R/.scripts"
  local f
  for f in spec_rubric.sh grep_section.sh lib_section.sh; do
    cp "$VAULT/.scripts/$f" "$G/.scripts/$f"
    git -C "$VAULT" show "$RED_REF:.scripts/$f" > "$R/.scripts/$f" 2>/dev/null \
      || { fail "RED ref $RED_REF lacks .scripts/$f"; finish; }
  done
  chmod +x "$G/.scripts/"*.sh "$R/.scripts/"*.sh
  grep -q 'Files touched' "$R/.scripts/spec_rubric.sh" && { fail "RED spec_rubric is not pre-fix"; finish; }
  grep -q 'sec_heading_name' "$R/.scripts/lib_section.sh" && { fail "RED lib_section is not pre-fix"; finish; }
  return 0
}

# rubric <G|R dir> <task>: sets RC and ERR (stderr).
rubric() {
  ERR="$(bash "$1/.scripts/spec_rubric.sh" --task-path "$2" 2>&1 >/dev/null)"; RC=$?
}
gsec() { bash "$1/.scripts/grep_section.sh" "$2" "$3" "$4" >/dev/null 2>&1; echo $?; }

# Default spec pieces (planner format). Fixtures are assembled from these.
MAP=$'### Responsibility map\n- foo: `.scripts/foo.sh`\n'
PACK=$'### Context pack\n- Read: .scripts/foo.sh:1-10 - the thing\n'
PROSE=$'### Summary\nChanges `.scripts/foo.sh` so the retry is bounded.\n'
OQ_NONE=$'### Open questions\nNone.\n'
FILES=$'### Files touched\n- [EDIT] `.scripts/foo.sh`\n'

# task <path> <spec-body>: a full task file with the template placeholder blockquote
# (which contains /execute_task) under ## 📐 Spec, then the later template sections.
task() {
  cat > "$1" <<EOF
---
project: [[T]]
status: in_progress
type: task
---

# ⚡ Task: Fixture

## 📋 Declarative Objective
- [ ] Do the thing.

## 🎯 Definition of Done (Success Criteria)
1. Thing done.

## 🧪 Verification Gateway
**Test Command:** \`bash tests/x.sh\`

## 📐 Spec
> Populated by \`invoke_spec_writer\` during \`/execute_task\` step 7, after user approval
> at the spec gate. May be empty for tasks not run through \`/execute_task\`.
<!-- write_task_section section=spec -->

$2
## ✅ Validator Report
> Populated by \`invoke_validator\` during \`/execute_task\` step 11.
<!-- write_task_section section=validator_report -->

## 📊 Verification Output
> Populated by the Verification Gateway.
<!-- write_task_section section=verification_output -->

## 🏁 COMPLETION SUMMARY (Post-Mortem)
- **Technical Meat:** (Filled by agent)

## 🔗 Related Context
- **Skills:** none
EOF
}

# build_mirror: private vault mirror M (real .scripts copy, empty private 04_Logs/Telemetry,
# mutable state copied, everything else symlinked) plus kit copy K whose .vault_link -> M.
# Kit suites run from K therefore reach M's telemetry, never the live vault's.
build_mirror() {
  M="$TMP/mirror/vault"; K="$TMP/mirror/kit"
  mkdir -p "$M/04_Logs/Telemetry" "$K"
  local e
  while IFS= read -r e; do
    case "$e" in .scripts|04_Logs|.git|.vault_link) continue ;; esac
    case "$e" in .session_state*|Orchestrator_Config.yaml|Needs_Attention.md) cp -R "$VAULT/$e" "$M/$e"; continue ;; esac
    ln -s "$VAULT/$e" "$M/$e"
  done < <(ls -A "$VAULT")
  ln -s . "$M/.vault_link"
  cp -R "$VAULT/.scripts" "$M/.scripts"
  while IFS= read -r e; do
    [ "$e" = Telemetry ] && continue
    case "$e" in Orchestrator|Errors) cp -R "$VAULT/04_Logs/$e" "$M/04_Logs/$e"; continue ;; esac
    ln -s "$VAULT/04_Logs/$e" "$M/04_Logs/$e"
  done < <(ls -A "$VAULT/04_Logs")
  while IFS= read -r e; do
    case "$e" in .git|.vault_link) continue ;; esac
    cp -R "$KIT/$e" "$K/$e"
  done < <(ls -A "$KIT")
  ln -s "$M" "$K/.vault_link"
  MTEL="$M/04_Logs/Telemetry"
  local p1; p1="$(cd "$K/.vault_link/.scripts" && pwd -P)"
  [ "$p1" = "$(cd "$M/.scripts" && pwd -P)" ] && [ "$p1" != "$VAULT/.scripts" ] && [ ! -L "$MTEL" ] \
    || { fail "kit copy does not resolve to the private mirror"; finish; }
}
# tel_snap <dir>: checksum of every *.jsonl (the DoD 4 detector), "none" when there are none.
tel_snap() {
  local f out=""
  for f in "$1"/*.jsonl; do [ -f "$f" ] && out="$out$(cksum < "$f") $(basename "$f");"; done
  echo "${out:-none}"
}
# run_kit_suites <names...>: each from the kit copy as the gateway does; sets KIT_RED to failing names.
run_kit_suites() {
  KIT_RED=""; local n
  for n in "$@"; do
    ( cd "$K" && CLAUDE_BIN=__nonexistent__ bash "tests/$n" >"$TMP/suite.out" 2>&1 ) || KIT_RED="$KIT_RED $n"
  done
}

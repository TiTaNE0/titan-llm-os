#!/usr/bin/env bash
# test_kit_telemetry_isolation.sh - gateway for Kit_Suites_Live_Telemetry_Isolation.
# Checks that TELEMETRY_DIR overrides the telemetry dir in emit_telemetry.sh and
# telemetry_start.sh, then runs every kit suite against a private vault mirror (real
# copy of .scripts with an emit-call counter shim, empty private 04_Logs/Telemetry)
# and asserts zero rows landed in the mirror's default dir, with a positive control
# that the emitting suites really called emit. Fix_Telemetry acceptance runs
# concurrently, then the real kit suites and vault suites run.
# KTI_SKIP_SUITES=1 skips the suite loops (aggregators use it to avoid recursion).
# Live-safety rule: vault scripts are only ever run from scratch copies; the live log
# is reported (NOTE), never asserted. Kit suites must reach the vault only via the
# relative .vault_link/ so the mirror can intercept them.
# Scope note: Fix_Telemetry's "real telemetry untouched" check greps only its own
# sentinels, so running it concurrently proves non-interference (DoD3), not leak
# detection. Leak detection is the mirror pass.
set -uo pipefail
unset TITAN_SESSION_ID TELEMETRY_DIR

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
KIT="$(cd "${KIT_ROOT:-$HOME/AI_Workflow/claude-agent-kit}" && pwd -P)"
REAL="$REPO_ROOT/04_Logs/Telemetry"
# Physical path: darwin mktemp returns /var/..., which is /private/var/... once resolved.
TMP="$(cd "$(mktemp -d)" && pwd -P)"; trap 'rm -rf "$TMP"' EXIT
FAILS=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAILS=$((FAILS + 1)); }
eq() {
  if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (got '$2', want '$3')"; fi
}
live_rows() { cat "$REAL"/*.jsonl 2>/dev/null | wc -l | tr -d ' '; }
rows_in() { cat "$1"/*.jsonl 2>/dev/null | wc -l | tr -d ' '; }

# --- DoD 2: override unit checks on scratch copies ---------------------------------
V="$TMP/v"; mkdir -p "$V/.scripts" "$TMP/cwd"
cp "$REPO_ROOT/.scripts/emit_telemetry.sh" "$REPO_ROOT/.scripts/telemetry_start.sh" "$V/.scripts/"
EMIT="$V/.scripts/emit_telemetry.sh"; START="$V/.scripts/telemetry_start.sh"
DEF="$V/04_Logs/Telemetry"; TD="$TMP/td"
MONTH="$(date -u +%Y-%m)"

cmp -s "$EMIT" "$REPO_ROOT/.scripts/emit_telemetry.sh" && pass "emit copy matches source" || fail "emit copy differs from source"
cmp -s "$START" "$REPO_ROOT/.scripts/telemetry_start.sh" && pass "start copy matches source" || fail "start copy differs from source"

TELEMETRY_DIR="$TD" bash "$EMIT" kti_probe success 5 null Executioner >/dev/null 2>&1
eq "override: one row in override dir" "$(rows_in "$TD")" 1
grep -qF '"macro":"kti_probe"' "$TD/$MONTH.jsonl" 2>/dev/null && pass "override: row has probe macro" || fail "override: row missing probe macro"
eq "override: scratch default dir has no rows" "$(rows_in "$DEF")" 0

env -u TELEMETRY_DIR bash "$EMIT" kti_probe success 5 null Executioner >/dev/null 2>&1
grep -qF '"macro":"kti_probe"' "$DEF/$MONTH.jsonl" 2>/dev/null && pass "unset: row in default dir" || fail "unset: row not in default dir"

( cd "$TMP/cwd" && TELEMETRY_DIR= bash "$EMIT" kti_probe success 5 null Executioner >/dev/null 2>&1 )
eq "empty: default dir got second row" "$(rows_in "$DEF")" 2
eq "empty: nothing written in cwd" "$(ls -A "$TMP/cwd" | wc -l | tr -d ' ')" 0

TELEMETRY_DIR="$TD" bash "$START" kti_t T >/dev/null 2>&1
eq "start: timer under override .timers" "$(ls "$TD/.timers" 2>/dev/null | wc -l | tr -d ' ')" 1
TELEMETRY_DIR="$TD" bash "$EMIT" kti_t success auto null Executioner T >/dev/null 2>&1
eq "emit auto consumed timer" "$(ls "$TD/.timers" 2>/dev/null | wc -l | tr -d ' ')" 0
grep -qF '"macro":"kti_t"' "$TD/$MONTH.jsonl" 2>/dev/null && pass "emit auto: row in override dir" || fail "emit auto: row missing in override dir"

TELEMETRY_DIR="$TD" bash "$EMIT" onlyone >/dev/null 2>&1
grep -q 'reject' "$TD/.write_failures.log" 2>/dev/null && pass "reject line in override .write_failures.log" || fail "reject line missing in override .write_failures.log"

for f in test_gateway_allowlist.sh test_gateway_adversarial.sh test_resolve_attention.sh test_resolve_attention_edge.sh; do
  grep -qF 'export TELEMETRY_DIR' "$KIT/tests/$f" && pass "static: $f exports TELEMETRY_DIR" || fail "static: $f lacks export TELEMETRY_DIR"
done
grep -qF 'TELEMETRY_DIR="$TMPDIR_ROOT" "$SCRIPT"' "$KIT/tests/test_metrics_breakdown.sh" && pass "static: metrics_breakdown passes TELEMETRY_DIR" || fail "static: metrics_breakdown lacks TELEMETRY_DIR"

# --- Suites ---------------------------------------------------------------------
if [ "${KTI_SKIP_SUITES:-0}" = 1 ]; then
  echo "SKIP: suites"
else
  # Mirror build
  M="$TMP/mirror/vault"; K="$TMP/mirror/kit"; CALLS="$TMP/emit_calls.log"
  mkdir -p "$M/04_Logs/Telemetry" "$K" "$TMP/probe"; : > "$CALLS"
  ls -A "$REPO_ROOT" | while IFS= read -r e; do
    case "$e" in .scripts|04_Logs|.git) continue ;; esac
    # Paths kit suites write (session state, config, queue) are copied so the pass has no live side effects.
    case "$e" in .session_state*|Orchestrator_Config.yaml|Needs_Attention.md) cp -R "$REPO_ROOT/$e" "$M/$e"; continue ;; esac
    ln -s "$REPO_ROOT/$e" "$M/$e"
  done
  cp -R "$REPO_ROOT/.scripts" "$M/.scripts"
  ls -A "$REPO_ROOT/04_Logs" | while IFS= read -r e; do
    [ "$e" = Telemetry ] && continue
    case "$e" in Orchestrator|Errors) cp -R "$REPO_ROOT/04_Logs/$e" "$M/04_Logs/$e"; continue ;; esac
    ln -s "$REPO_ROOT/04_Logs/$e" "$M/04_Logs/$e"
  done
  mv "$M/.scripts/emit_telemetry.sh" "$M/.scripts/emit_telemetry.real.sh"
  {
    echo '#!/usr/bin/env bash'
    printf 'echo call >> "%s"\n' "$CALLS"
    echo 'exec "$(dirname "${BASH_SOURCE[0]}")/emit_telemetry.real.sh" "$@"'
  } > "$M/.scripts/emit_telemetry.sh"
  chmod +x "$M/.scripts/emit_telemetry.sh"
  ls -A "$KIT" | while IFS= read -r e; do
    case "$e" in .git|.vault_link) continue ;; esac
    cp -R "$KIT/$e" "$K/$e"
  done
  ln -s "$M" "$K/.vault_link"

  mirror_rows() { cat "$M"/04_Logs/Telemetry/*.jsonl "$M"/04_Logs/Telemetry/.write_failures.log 2>/dev/null | wc -l | tr -d ' '; }
  emit_calls() { wc -l < "$CALLS" 2>/dev/null | tr -d ' '; }

  # Mirror sanity
  MIRROR_OK=1
  mfail() { fail "mirror invalid: $1"; MIRROR_OK=0; }
  p1="$(cd "$K/.vault_link/.scripts" && pwd -P)"; p2="$(cd "$M/.scripts" && pwd -P)"
  [ "$p1" = "$p2" ] || mfail ".vault_link/.scripts ($p1) != mirror .scripts ($p2)"
  [ "$p1" != "$REPO_ROOT/.scripts" ] || mfail "mirror .scripts is the live .scripts"
  { [ -d "$M/04_Logs/Telemetry" ] && [ ! -L "$M/04_Logs/Telemetry" ] && [ "$(ls -A "$M/04_Logs/Telemetry" | wc -l | tr -d ' ')" = 0 ]; } || mfail "mirror telemetry dir not a private empty dir"
  TELEMETRY_DIR="$TMP/probe" "$M/.scripts/emit_telemetry.sh" kti_shim success 1 null Executioner >/dev/null 2>&1
  [ "$(emit_calls)" = 1 ] || mfail "shim probe call count $(emit_calls), want 1"
  [ "$(rows_in "$TMP/probe")" = 1 ] || mfail "shim probe row count $(rows_in "$TMP/probe"), want 1"
  [ "$(mirror_rows)" = 0 ] || mfail "shim probe wrote to mirror default dir"
  : > "$CALLS"

  if [ "$MIRROR_OK" = 1 ]; then
    # DoD 1, 3: mirror kit pass in background while Fix_Telemetry acceptance runs in foreground
    live0="$(live_rows)"
    RES="$TMP/leak_results"; : > "$RES"
    (
      n=0
      for t in "$K"/tests/test_*.sh; do
        [ -f "$t" ] || continue
        n=$((n + 1))
        r0="$(mirror_rows)"; c0="$(emit_calls)"
        ( cd "$K" && CLAUDE_BIN=__nonexistent__ bash "$t" >/dev/null 2>&1 ); rc=$?
        echo "$(basename "$t") $rc $(( $(mirror_rows) - r0 )) $(( $(emit_calls) - c0 ))" >> "$RES"
      done
      echo "DONE $n" >> "$RES"
    ) &
    bg=$!
    fx="$(bash "$REPO_ROOT/tests/acceptance/Fix_Telemetry_Duration_And_Task_Field/run_all.sh" 2>&1)"; fxrc=$?
    wait "$bg"

    last="$(tail -n 1 "$RES")"; nres="$(grep -vc '^DONE ' "$RES")"
    case "$last" in
      "DONE "*) dn="${last#DONE }"; if [ "$dn" -ge 1 ] && [ "$dn" = "$nres" ]; then pass "leak pass complete ($dn suites)"; else fail "leak pass incomplete (DONE $dn, $nres results)"; fi ;;
      *) fail "leak pass incomplete (no DONE marker)" ;;
    esac
    while read -r name rc dr dc; do
      [ "$name" = DONE ] && continue
      if [ "$dr" = 0 ]; then pass "kit $name wrote 0 rows to the vault default telemetry dir"; else fail "kit $name leaked $dr rows"; fi
    done < "$RES"
    for name in test_gateway_allowlist.sh test_gateway_adversarial.sh test_resolve_attention.sh test_resolve_attention_edge.sh test_metrics_breakdown.sh; do
      line="$(grep "^$name " "$RES" | head -n 1)"
      if [ -z "$line" ]; then fail "emitting suite missing: $name"; continue; fi
      set -- $line; rc="$2"; dc="$4"
      if [ "$rc" = 0 ] && [ "$dc" -ge 1 ]; then pass "kit $name emitted $dc times, all to its override"
      else fail "kit $name positive control: rc=$rc emit_calls=$dc"; fi
    done
    [ "$fxrc" -eq 0 ] && pass "Fix_Telemetry run_all exit 0" || fail "Fix_Telemetry run_all exit $fxrc"
    printf '%s\n' "$fx" | grep -qF 'PASS DoD4 real telemetry untouched' && pass "Fix_Telemetry real telemetry untouched" || fail "Fix_Telemetry real telemetry untouched line missing"
    echo "NOTE: live telemetry rows changed by $(( $(live_rows) - live0 )) during the run (other sessions included; not asserted)"
  fi

  # DoD 4: kit suites green (real kit)
  n=0
  for t in "$KIT"/tests/test_*.sh; do
    [ -f "$t" ] || continue
    n=$((n + 1))
    if ( cd "$KIT" && CLAUDE_BIN=__nonexistent__ bash "$t" >/dev/null 2>&1 ); then pass "kit green $(basename "$t")"; else fail "kit green $(basename "$t")"; fi
  done
  [ "$n" -ge 1 ] || fail "kit suite glob matched nothing"

  # DoD 4: vault suites
  n=0
  for t in "$REPO_ROOT"/tests/test_*.sh "$REPO_ROOT"/tests/smoke_*.sh; do
    [ -f "$t" ] || continue
    b="$(basename "$t")"
    [ "$b" = test_kit_telemetry_isolation.sh ] && continue
    n=$((n + 1))
    if [ "$b" = test_chain_consolidation.sh ]; then
      out="$( cd "$REPO_ROOT" && CHAIN_SKIP_SUITES=1 bash "tests/$b" 2>&1 )"
      if ! printf '%s\n' "$out" | grep -q '^FAIL:' && printf '%s\n' "$out" | grep -qF 'suites skipped: not a gateway pass'; then
        pass "vault $b (skip mode)"; else fail "vault $b (skip mode)"; fi
      continue
    fi
    envp=""; [ "$b" = test_thin_orchestrator.sh ] && envp="THIN_ORCH_SKIP_SUITES=1"; [ "$b" = test_pm_reviewer_single_pass.sh ] && envp="PMR_SKIP_SUITES=1"; [ "$b" = test_chain_targeted_tests.sh ] && envp="CTT_SKIP_SUITES=1"; [ "$b" = test_macro_start_timestamp.sh ] && envp="MST_SKIP_SUITES=1"; [ "$b" = test_hook_argument_scope.sh ] && envp="HAS_SKIP_SUITES=1"; [ "$b" = test_spec_gate_hardening.sh ] && envp="SGH_SKIP_SUITES=1"
    if ( cd "$REPO_ROOT" && env $envp bash "tests/$b" >/dev/null 2>&1 ); then pass "vault $b"; else fail "vault $b"; fi
  done
  [ "$n" -ge 1 ] || fail "vault suite glob matched nothing"
  echo "not in suite glob: tests/acceptance/ folders and tests/acceptance_commit_task.sh (Fix_Telemetry run_all is run above)"
fi

if [ "$FAILS" -eq 0 ]; then echo "ALL GREEN"; exit 0; fi
echo "$FAILS check(s) failed"; exit 1

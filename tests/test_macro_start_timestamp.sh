#!/usr/bin/env bash
# test_macro_start_timestamp.sh - gateway for Macro_Start_Timestamp_Across_Shell_Calls.
# Greps kit commands and install.sh for stale START_TS_MS arithmetic and <duration_ms> placeholders,
# replays the real new_task/retrospective telemetry lines one shell per call, runs a two-shell
# start/emit timing check against a mktemp telemetry dir, then runs kit and vault suites.
# MST_SKIP_SUITES=1 skips the suite loops (the aggregators use it to avoid recursion).
set -uo pipefail
unset TITAN_SESSION_ID ACC_SKIP_GATEWAY TELEMETRY_DIR

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
KIT="${KIT_ROOT:-$HOME/AI_Workflow/claude-agent-kit}"
CMDS="$KIT/project-template/.claude/commands"
OC_CMD="${MST_OC_CMD_DIR:-$HOME/.config/opencode/command}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
FAILS=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAILS=$((FAILS + 1)); }
eq() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (got '$2', want '$3')"; fi; }
has() { if grep -qF -- "$3" "$2"; then pass "$1"; else fail "$1 (missing: $3)"; fi; }
nonzero() { if [ "$2" -ne 0 ]; then pass "$1"; else fail "$1 not detected"; fi; }
stale() { cat "$@" 2>/dev/null | grep -cE 'START_TS_MS|END_TS_MS|<duration_ms>' || true; }

# --- DoD 1/2 static ------------------------------------------------------------
eq "no stale START_TS_MS/<duration_ms> in kit commands and install.sh" "$(stale "$CMDS"/*.md "$KIT/install.sh")" 0
for m in new_task retrospective; do
  has "$m.md starts timer" "$CMDS/$m.md" "telemetry_start.sh $m"
  has "$m.md success emit uses auto" "$CMDS/$m.md" "emit_telemetry.sh $m success auto"
  has "$m.md error emit uses auto" "$CMDS/$m.md" "emit_telemetry.sh $m error auto"
done
has "install.sh preflight emit uses auto" "$KIT/install.sh" "emit_telemetry.sh execute_task error auto E1 Executioner"

# RED controls
cp "$CMDS/new_task.md" "$TMP/red1.md"; echo 'START_TS_MS=$(($(date +%s) * 1000))' >> "$TMP/red1.md"
nonzero "RED: START_TS_MS line detected" "$(stale "$TMP/red1.md")"
echo 'x <duration_ms> y' > "$TMP/red2.md"
nonzero "RED: <duration_ms> detected" "$(stale "$TMP/red2.md")"

# generated OpenCode commands
if [ -f "$OC_CMD/execute_task.md" ]; then
  eq "generated OpenCode commands have no stale patterns" "$(stale "$OC_CMD"/*.md)" 0
else
  fail "OpenCode execute_task.md missing; run install.sh setup-opencode"
fi

# aggregator wiring
for f in test_chain_consolidation.sh test_chain_targeted_tests.sh test_pm_reviewer_single_pass.sh test_kit_telemetry_isolation.sh; do
  has "$f wires MST_SKIP_SUITES" "$REPO_ROOT/tests/$f" '[ "$b" = test_macro_start_timestamp.sh ] && envp="MST_SKIP_SUITES=1"'
done

# --- behavioural replay --------------------------------------------------------
mkdir -p "$TMP/vault/.scripts" "$TMP/work"
cp "$REPO_ROOT/.scripts/telemetry_start.sh" "$REPO_ROOT/.scripts/emit_telemetry.sh" "$TMP/vault/.scripts/"
ln -s "$TMP/vault" "$TMP/work/.vault_link"
TD="$TMP/td"

run() { (cd "$TMP/work" && TELEMETRY_DIR="$1" bash -c "$2") >/dev/null 2>&1; }
lastrow() { cat "$1"/*.jsonl 2>/dev/null | tail -n1; }

for m in new_task retrospective; do
  lines="$(grep -o '\.vault_link/\.scripts/\(telemetry_start\|emit_telemetry\)\.sh '"$m"'[^`]*' "$CMDS/$m.md" | sed 's/[[:space:]]*$//')"
  ok="$(printf '%s\n' "$lines" | grep -v ' error ')"
  err="$(printf '%s\n' "$lines" | grep ' error ')"
  start="$(printf '%s\n' "$ok" | grep -F telemetry_start.sh)"
  emit="$(printf '%s\n' "$ok" | grep -F emit_telemetry.sh)"
  eq "$m: one start line" "$(printf '%s\n' "$start" | grep -c .)" 1
  eq "$m: one success emit line" "$(printf '%s\n' "$emit" | grep -c .)" 1
  D="$TD/$m"
  run "$D" "$start"; sleep 1; run "$D" "$emit"
  row="$(lastrow "$D")"
  d="$(printf '%s' "$row" | jq -r '.duration_ms' 2>/dev/null)"
  eq "$m: success row status" "$(printf '%s' "$row" | jq -r '.status' 2>/dev/null)" success
  if [ "${d:-x}" -ge 1000 ] 2>/dev/null && [ "$d" -lt 3600000 ]; then pass "$m: replay duration $d ms"; else fail "$m: replay duration ($d)"; fi
  if grep -q 'missing-timer' "$D/.write_failures.log" 2>/dev/null; then fail "$m: missing-timer note"; else pass "$m: no missing-timer note"; fi
  eq "$m: timers consumed" "$(ls "$D/.timers" 2>/dev/null | grep -vc '^\.' )" 0
  # error path
  E="$TD/${m}_err"
  run "$E" "$start"; sleep 1; run "$E" "${err//<E-class>/E3}"
  row="$(lastrow "$E")"
  eq "$m: error row" "$(printf '%s' "$row" | jq -r '[.status,.error_class]|join("/")' 2>/dev/null)" error/E3
  d="$(printf '%s' "$row" | jq -r '.duration_ms' 2>/dev/null)"
  if [ "${d:-x}" -ge 1000 ] 2>/dev/null; then pass "$m: error duration $d ms"; else fail "$m: error duration ($d)"; fi
done

# --- DoD 3 two-shell timing ----------------------------------------------------
TD2="$TMP/td2"
TELEMETRY_DIR="$TD2" bash -c '"$0" mst_probe "MST Task"' "$TMP/vault/.scripts/telemetry_start.sh"
sleep 1
TELEMETRY_DIR="$TD2" bash -c '"$0" mst_probe success auto null Executioner "MST Task"' "$TMP/vault/.scripts/emit_telemetry.sh" >/dev/null 2>&1
if lastrow "$TD2" | jq -e '.macro=="mst_probe" and .task=="MST Task" and .duration_ms > 0 and .duration_ms < 3600000' >/dev/null 2>&1; then
  pass "two-shell start/emit duration in (0, 3600000)"; else fail "two-shell start/emit duration"; fi
eq "two-shell timer consumed" "$(ls "$TD2/.timers" 2>/dev/null | wc -l | tr -d ' ')" 0
TELEMETRY_DIR="$TD2" bash -c '"$0" mst_nostart success auto null Executioner' "$TMP/vault/.scripts/emit_telemetry.sh" >/dev/null 2>&1
eq "negative control: no start gives duration 0" "$(lastrow "$TD2" | jq -r '.duration_ms')" 0
if grep -q 'missing-timer' "$TD2/.write_failures.log" 2>/dev/null; then pass "negative control: missing-timer note"; else fail "negative control: missing-timer note"; fi

# live safety
if cat "$REPO_ROOT"/04_Logs/Telemetry/*.jsonl 2>/dev/null | grep -qE 'mst_probe|mst_nostart'; then
  fail "live telemetry contains mst sentinel rows"; else pass "live telemetry clean of mst sentinels"; fi

# --- DoD 4: suites -------------------------------------------------------------
if [ "${MST_SKIP_SUITES:-0}" = 1 ]; then
  echo "SKIP: suites"
else
  n=0
  for t in "$KIT"/tests/test_*.sh; do
    [ -f "$t" ] || continue
    n=$((n + 1))
    if ( cd "$KIT" && CLAUDE_BIN=__nonexistent__ bash "$t" >/dev/null 2>&1 ); then pass "kit $(basename "$t")"; else fail "kit $(basename "$t")"; fi
  done
  [ "$n" -ge 1 ] || fail "kit suite glob matched nothing"
  n=0
  for t in "$REPO_ROOT"/tests/test_*.sh "$REPO_ROOT"/tests/smoke_*.sh; do
    [ -f "$t" ] || continue
    b="$(basename "$t")"
    [ "$b" = test_macro_start_timestamp.sh ] && continue
    n=$((n + 1))
    if [ "$b" = test_chain_consolidation.sh ]; then
      out="$( cd "$REPO_ROOT" && CHAIN_SKIP_SUITES=1 bash "tests/$b" 2>&1 )"
      if ! printf '%s\n' "$out" | grep -q '^FAIL:' && printf '%s\n' "$out" | grep -qF 'suites skipped: not a gateway pass'; then
        pass "vault $b (skip mode)"; else fail "vault $b (skip mode)"; fi
      continue
    fi
    envp=""; [ "$b" = test_thin_orchestrator.sh ] && envp="THIN_ORCH_SKIP_SUITES=1"; [ "$b" = test_pm_reviewer_single_pass.sh ] && envp="PMR_SKIP_SUITES=1"; [ "$b" = test_kit_telemetry_isolation.sh ] && envp="KTI_SKIP_SUITES=1"; [ "$b" = test_chain_targeted_tests.sh ] && envp="CTT_SKIP_SUITES=1"; [ "$b" = test_hook_argument_scope.sh ] && envp="HAS_SKIP_SUITES=1"; [ "$b" = test_spec_gate_hardening.sh ] && envp="SGH_SKIP_SUITES=1"
    if ( cd "$REPO_ROOT" && env $envp bash "tests/$b" >/dev/null 2>&1 ); then pass "vault $b"; else fail "vault $b"; fi
  done
  [ "$n" -ge 1 ] || fail "vault suite glob matched nothing"
fi

if [ "$FAILS" -eq 0 ]; then echo "ALL GREEN"; exit 0; fi
echo "$FAILS check(s) failed"; exit 1

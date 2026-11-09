#!/usr/bin/env bash
# Shared setup for Kit_Suites_Live_Telemetry_Isolation acceptance tests.
# Every write goes to mktemp dirs. The live 04_Logs/Telemetry is never written by these
# tests and never counted (other sessions append to it concurrently).
set -uo pipefail
unset TITAN_SESSION_ID TELEMETRY_DIR

VAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
KIT="$(cd "${KIT_ROOT:-$HOME/AI_Workflow/claude-agent-kit}" && pwd -P)"
GATEWAY="$VAULT/tests/test_kit_telemetry_isolation.sh"
FIXTEL_RUN_ALL="$VAULT/tests/acceptance/Fix_Telemetry_Duration_And_Task_Field/run_all.sh"
# The suites the spec names as reaching emitting atoms through .vault_link.
EMITTING="test_gateway_allowlist.sh test_gateway_adversarial.sh test_resolve_attention.sh test_resolve_attention_edge.sh test_metrics_breakdown.sh"
SENTINEL="acc_kti_"

# Physical path: darwin mktemp gives /var/..., which resolves to /private/var/...
TMP="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

FAILED=0
fail() { echo "FAIL: $1" >&2; FAILED=1; }
pass() { echo "ok: $1"; }
finish() { [ "$FAILED" -eq 0 ] && { echo "PASS"; exit 0; }; echo "FAILED" >&2; exit 1; }
expect() { [ "$3" = "$2" ] && pass "$1" || fail "$1: expected [$2], got [$3]"; }
rows_in() { cat "$1"/*.jsonl 2>/dev/null | wc -l | tr -d ' '; }

# build_mirror: private vault mirror M (real .scripts copy, empty private
# 04_Logs/Telemetry; session state, config, queue, Orchestrator/Errors logs copied; rest symlinked) plus kit copy K whose .vault_link -> M.
# emit_telemetry.sh and telemetry_start.sh are wrapped by shims that log one line per
# call to $CALLS: "<script> <TELEMETRY_DIR as seen by the call, or <unset>>".
build_mirror() {
  M="$TMP/mirror/vault"; K="$TMP/mirror/kit"; CALLS="$TMP/calls.log"
  mkdir -p "$M/04_Logs/Telemetry" "$K"; : > "$CALLS"
  local e s
  while IFS= read -r e; do
    case "$e" in .scripts|04_Logs|.git) continue ;; esac
    case "$e" in .session_state*|Orchestrator_Config.yaml|Needs_Attention.md) cp -R "$VAULT/$e" "$M/$e"; continue ;; esac
    ln -s "$VAULT/$e" "$M/$e"
  done < <(ls -A "$VAULT")
  cp -R "$VAULT/.scripts" "$M/.scripts"
  while IFS= read -r e; do
    [ "$e" = Telemetry ] && continue
    case "$e" in Orchestrator|Errors) cp -R "$VAULT/04_Logs/$e" "$M/04_Logs/$e"; continue ;; esac
    ln -s "$VAULT/04_Logs/$e" "$M/04_Logs/$e"
  done < <(ls -A "$VAULT/04_Logs")
  for s in emit_telemetry telemetry_start; do
    mv "$M/.scripts/$s.sh" "$M/.scripts/$s.real.sh"
    {
      echo '#!/usr/bin/env bash'
      printf 'echo "%s ${TELEMETRY_DIR:-<unset>}" >> "%s"\n' "$s" "$CALLS"
      printf 'exec "$(dirname "${BASH_SOURCE[0]}")/%s.real.sh" "$@"\n' "$s"
    } > "$M/.scripts/$s.sh"
    chmod +x "$M/.scripts/$s.sh"
  done
  while IFS= read -r e; do
    case "$e" in .git|.vault_link) continue ;; esac
    cp -R "$KIT/$e" "$K/$e"
  done < <(ls -A "$KIT")
  ln -s "$M" "$K/.vault_link"
  MTEL="$M/04_Logs/Telemetry"
}

# mirror_valid: the kit copy really resolves to the private mirror, not the live vault.
mirror_valid() {
  local p1 p2
  p1="$(cd "$K/.vault_link/.scripts" && pwd -P)"; p2="$(cd "$M/.scripts" && pwd -P)"
  [ "$p1" = "$p2" ] && [ "$p1" != "$VAULT/.scripts" ] && [ -d "$MTEL" ] && [ ! -L "$MTEL" ] \
    && [ -z "$(ls -A "$MTEL")" ]
}

# Anything at all under the mirror's default telemetry dir (rows, sentinels, timers).
mirror_files() { find "$MTEL" -type f 2>/dev/null | wc -l | tr -d ' '; }
mirror_rows() { rows_in "$MTEL"; }

# run_mirror_suite <name>: run one kit suite from the kit copy, the way the gateway does.
run_mirror_suite() { ( cd "$K" && CLAUDE_BIN=__nonexistent__ bash "tests/$1" >"$TMP/suite.out" 2>&1 ); }

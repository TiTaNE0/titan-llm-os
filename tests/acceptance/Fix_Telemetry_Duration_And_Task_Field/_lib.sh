#!/usr/bin/env bash
# Shared setup for Fix_Telemetry_Duration_And_Task_Field acceptance tests.
# Every script runs from a mktemp vault copy; the real telemetry dir is never a target.
set -uo pipefail

VAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
KIT_CMDS="${KIT_COMMANDS_DIR:-$HOME/AI_Workflow/claude-agent-kit/project-template/.claude/commands}"
SENTINEL="acc_tdtf_$$"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/vault/.scripts"
for f in emit_telemetry.sh telemetry_start.sh telemetry_task_report.sh; do
  cp "$VAULT/.scripts/$f" "$TMP/vault/.scripts/"
done
S="$TMP/vault/.scripts"
TDIR="$TMP/vault/04_Logs/Telemetry"
FAILS="$TDIR/.write_failures.log"

FAILED=0
fail() { echo "FAIL: $1" >&2; FAILED=1; }
pass() { echo "ok: $1"; }
assert() { local n="$1"; shift; if "$@" >/dev/null 2>&1; then pass "$n"; else fail "$n"; fi; }

rows() { cat "$TDIR"/*.jsonl 2>/dev/null; }
row_count() { rows | wc -l | tr -d ' '; }
last_row() { rows | tail -n 1; }
emit() { bash "$S/emit_telemetry.sh" "$@"; }
start() { bash "$S/telemetry_start.sh" "$@"; }
finish() { [ "$FAILED" -eq 0 ] && { echo "PASS"; exit 0; }; echo "FAILED" >&2; exit 1; }

# Shared helpers for Telemetry_Task_Report_CSV_Quoting acceptance tests.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
R="$REPO_ROOT/.scripts/telemetry_task_report.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/tel"
PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); echo "PASS $1"; }
fail() { FAIL=$((FAIL+1)); echo "FAIL $1"; }
# row <ts> <json-task-literal> [macro] [duration]
row() { printf '{"ts":"%s","macro":"%s","status":"success","duration_ms":%s,"task":%s}\n' "$1" "${3:-invoke_builders}" "${4:-1000}" "$2"; }
run() { TELEMETRY_DIR="$TMP/tel" bash "$R" "$@" 2>/dev/null; }
finish() { echo "$PASS passed, $FAIL failed"; [ "$FAIL" -eq 0 ]; }

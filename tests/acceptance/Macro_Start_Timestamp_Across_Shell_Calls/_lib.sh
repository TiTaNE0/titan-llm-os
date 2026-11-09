#!/usr/bin/env bash
# Shared setup for Macro_Start_Timestamp_Across_Shell_Calls acceptance tests.
# Every write goes to mktemp dirs; the real vault, kit, live telemetry and ~/.config/opencode are only read.
set -uo pipefail
unset TITAN_SESSION_ID TELEMETRY_DIR

VAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
KIT="$(cd "${KIT_ROOT:-$HOME/AI_Workflow/claude-agent-kit}" && pwd -P)"
CMDS="$KIT/project-template/.claude/commands"
GATEWAY="$VAULT/tests/test_macro_start_timestamp.sh"

TMP="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

FAILED=0
fail() { echo "FAIL: $1" >&2; FAILED=1; }
pass() { echo "ok: $1"; }
finish() { [ "$FAILED" -eq 0 ] && { echo "PASS"; exit 0; }; echo "FAILED" >&2; exit 1; }
expect() { [ "$3" = "$2" ] && pass "$1" || fail "$1: expected [$2], got [$3]"; }

# Scratch project whose .vault_link points at a scratch vault holding the real telemetry scripts
# and a persona_check.sh stub, so command blocks run exactly as written in a project.
make_project() {
  mkdir -p "$TMP/vault/.scripts" "$TMP/proj"
  cp "$VAULT/.scripts/telemetry_start.sh" "$VAULT/.scripts/emit_telemetry.sh" "$TMP/vault/.scripts/"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$TMP/vault/.scripts/persona_check.sh"
  chmod +x "$TMP/vault/.scripts/"*.sh
  [ -e "$TMP/proj/.vault_link" ] || ln -s "$TMP/vault" "$TMP/proj/.vault_link"
}

# step_bash <file> <n>: the first ```bash fenced block under "## Step <n> ".
step_bash() {
  awk -v a="## Step $2 " '
    index($0,a)==1 {on=1; next}
    on && /^## / {exit}
    on && /^```bash/ {inb=1; next}
    inb && /^```/ {exit}
    inb {print}' "$1"
}

# in_new_shell <telemetry_dir> <script-text>: one Bash call, as Claude Code makes it (no shared vars).
in_new_shell() { ( cd "$TMP/proj" && env -i PATH="$PATH" HOME="$HOME" TELEMETRY_DIR="$1" bash -c "$2" ) >/dev/null 2>&1; }

lastrow() { cat "$1"/*.jsonl 2>/dev/null | tail -n1; }

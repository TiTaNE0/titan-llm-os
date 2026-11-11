# Shared helpers for Execute_Task_Coordinator_Source_Firewall acceptance tests. Sourced, not run.
# Runbooks are read through the vault's own .claude/commands symlinks (what the harness loads).
# Every script call runs in a mktemp sandbox vault (copied .scripts), never the live vault.
set -uo pipefail
unset TITAN_SESSION_ID TELEMETRY_DIR ORCH_RUN_ID EVIDENCE_OVERRIDE
VAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
KIT="$(cd "${KIT_ROOT:-$HOME/AI_Workflow/claude-agent-kit}" && pwd -P)"
ET="$VAULT/.claude/commands/execute_task.md"
CT="$VAULT/.claude/commands/close_task.md"
OC_CMD="$(dirname "${ECF_OC_AGENT_DIR:-$HOME/.config/opencode/agent}")/command"
TMP="$(cd "$(mktemp -d)" && pwd -P)"; trap 'rm -rf "$TMP"' EXIT
FAILS=0
TASK="Acc_Firewall_Fixture"
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1" >&2; FAILS=$((FAILS + 1)); }
eq() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (got '$2', want '$3')"; fi; }
done_() { [ "$FAILS" -eq 0 ] && exit 0; echo "$FAILS failed" >&2; exit 1; }

# section <file> <heading-regex> : body from the heading line to the next "## " heading
section() { awk -v h="$2" '$0 ~ h {f=1; print; next} f && /^## /{f=0} f' "$1"; }
# fenced <text-file> <first-line-regex> : the fenced block whose first code line matches, indent stripped
fenced() { awk -v r="$2" '
  /^[[:space:]]*```/ { if (inb) { if (keep) exit; inb=0; next } inb=1; first=1; next }
  inb && first { first=0; if ($0 ~ r) keep=1 }
  inb && keep { sub(/^[[:space:]]+/, ""); print }' "$1"; }

# Sandbox vault: copied scripts + templates + an Executioner session; scripts resolve the vault from their own dir.
sandbox() {
  SB="$TMP/vault"; mkdir -p "$SB/04_Logs/Telemetry" "$SB/02_Tasks/P" "$SB/00_Templates"
  cp -R "$VAULT/.scripts" "$SB/.scripts"
  cp "$VAULT/00_Templates/Needs_Attention_Template.md" "$VAULT/00_Templates/Task_Template.md" "$SB/00_Templates/"
  printf '{\n  "persona": "Executioner",\n  "session_id": "acc",\n  "started_at": "2026-11-11T00:00:00Z",\n  "agent_surface": "test"\n}\n' > "$SB/.session_state.json"
  TEL="$SB/04_Logs/Telemetry/$(date -u +%Y-%m).jsonl"
}
# Project repo whose .vault_link points at the sandbox vault.
project() {
  P="$TMP/proj"; mkdir -p "$P"; git -C "$P" init -q
  git -C "$P" config user.name t; git -C "$P" config user.email t@t; git -C "$P" config commit.gpgsign false
  ln -s "$SB" "$P/.vault_link"; echo .vault_link >> "$P/.git/info/exclude"
}
# run_block <script-text> [env...] : runs a runbook block as the coordinator would, from the project root
run_block() { local s="$1"; shift; OUT="$(cd "$P" && env "$@" bash -c "$s" 2>&1)"; RC=$?; }
sub_task() { sed -e "s/<Task_Name>/$TASK/g"; }

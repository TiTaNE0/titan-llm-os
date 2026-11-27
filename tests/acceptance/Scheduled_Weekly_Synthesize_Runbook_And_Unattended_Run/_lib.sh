#!/usr/bin/env bash
# Shared setup for the Scheduled_Weekly_Synthesize_Runbook_And_Unattended_Run acceptance tests.
# Every write goes to a mktemp sandbox vault; the real vault is only read.
set -uo pipefail
unset TITAN_SESSION_ID TELEMETRY_DIR

VAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
RUNBOOK="$VAULT/.scripts/runbooks/synthesize.md"
PROMPT="$VAULT/.scripts/runbooks/synthesize_scheduled_task_prompt.md"
HELPER="$VAULT/.scripts/synthesize_run.sh"
BUILDER_TEST="$VAULT/tests/test_synthesize_scheduled_run.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/synacc.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

FAILED=0
fail() { echo "FAIL: $1" >&2; FAILED=1; }
pass() { echo "ok: $1"; }
finish() { [ "$FAILED" -eq 0 ] && { echo "PASS"; exit 0; }; echo "FAILED" >&2; exit 1; }
eq() { [ "$2" = "$3" ] && pass "$1" || fail "$1 (got '$2', want '$3')"; }
has() { grep -qF -- "$2" "$1" && pass "$3" || fail "$3 (missing: $2)"; }
hasnt() { grep -qF -- "$2" "$1" && fail "$3 (present: $2)" || pass "$3"; }

# section <file> <heading-prefix>: lines from the heading to the next heading of the same or higher level.
section() {
  awk -v h="$2" '
    index($0, h) == 1 && !on { on = 1; lvl = match($0, /[^#]/) - 1; print; next }
    on { l = match($0, /[^#]/) - 1; if ($0 ~ /^#+ / && l <= lvl) exit; print }' "$1"
}

# mk_sandbox <dir>: minimal vault with the real atoms copied in, fixture logs and a git repo.
mk_sandbox() {
  local d="$1" s
  mkdir -p "$d/.scripts" "$d/04_Logs/Telemetry" "$d/03_Brain/Weekly_Synthesis" \
           "$d/01_Projects" "$d/02_Tasks/P" "$d/05_Content"
  for s in synthesize_run session_state_write persona_check append_log emit_telemetry telemetry_start; do
    cp "$VAULT/.scripts/$s.sh" "$d/.scripts/"
  done
  chmod +x "$d/.scripts/"*.sh
  ln -s . "$d/.vault_link"
  local day
  for day in 2026-11-15 2026-11-16 2026-11-22 2026-11-23; do echo "- log $day" > "$d/04_Logs/$day.md"; done
  echo '{}' > "$d/04_Logs/2026-11-18_extra.json"
  printf '%s\n' '{"id":"fact_2026-W20_001","claim":"a","confidence":0.9,"citations":5,"status":"active"}' \
                '{"id":"fact_2026-W20_002","claim":"b","confidence":0.5,"citations":1,"status":"active"}' \
    > "$d/03_Brain/Weekly_Synthesis/facts.jsonl"
  echo "kernel" > "$d/03_Brain/System_Agents.md"
  echo "p" > "$d/01_Projects/P.md"; echo "t" > "$d/02_Tasks/P/T.md"
  echo "board" > "$d/P_Board.md"; echo "att" > "$d/Needs_Attention.md"
  ( cd "$d" && git init -q && git add -A && git -c user.name=t -c user.email=t@t commit -q -m init ) >/dev/null 2>&1
}

# manifest <dir>: sorted "sha  path" of every file except .git.
manifest() { ( cd "$1" && find . -path ./.git -prune -o \( -type f -o -type l \) -print | LC_ALL=C sort | while read -r f; do
  if [ -L "$f" ]; then echo "link  $f"; else echo "$(shasum -a 256 "$f" | cut -d' ' -f1)  $f"; fi; done ); }

# write_w47 <dir>: simulated model output for 2026-W47 (1 open + 1 resolved contradiction, 2 pending + 1 promoted + 1 rejected proposal).
write_w47() {
  local d="$1" syn="$1/03_Brain/Weekly_Synthesis"
  cat > "$syn/2026-W47.synthesis.json" <<'J'
{"iso_week":"2026-W47","dates":"2026-11-16..2026-11-22","synthesized_at":"2026-11-30T06:00:00Z","persona":"Synthesizer",
 "logs_read":["04_Logs/2026-11-16.md","04_Logs/2026-11-22.md"],"facts_added":["fact_2026-W47_001","fact_2026-W47_002"],
 "contradictions":[
  {"facts":["fact_A","fact_B"],"summary":"A says\n  yes,   B says no","status":"open"},
  {"facts":["fact_C","fact_D"],"summary":"old","status":"resolved"}],
 "rule_proposals":[
  {"id":"proposal_2026-W47_001","source_fact":"fact_A","proposed_rule":"Always   do\nX","rationale":"r","confidence":0.9,"target_file":"03_Brain/Agent_Roles.md","status":"pending"},
  {"id":"proposal_2026-W47_002","source_fact":"fact_B","proposed_rule":"Never do Y","rationale":"r","confidence":0.9,"target_file":"03_Brain/Memory_Schema.md"},
  {"id":"proposal_2026-W47_003","source_fact":"fact_C","proposed_rule":"done","rationale":"r","confidence":0.9,"target_file":"03_Brain/X.md","status":"promoted"},
  {"id":"proposal_2026-W47_004","source_fact":"fact_D","proposed_rule":"nope","rationale":"r","confidence":0.9,"target_file":"03_Brain/Z.md","status":"rejected"}]}
J
  printf '# Synthesis\n## Summary\nx\n## Facts\n## Contradictions\n## Rule Proposals\n' > "$syn/2026-W47.synthesis.md"
  cp "$syn/facts.jsonl" "$syn/facts.jsonl.next"
  echo '{"id":"fact_2026-W47_001","claim":"c","confidence":0.5,"citations":1,"status":"active"}' >> "$syn/facts.jsonl.next"
}

# syn <dir> <args...>: run the sandbox's synthesize_run.sh from the sandbox root.
syn() { local d="$1"; shift; ( cd "$d" && ./.vault_link/.scripts/synthesize_run.sh "$@" ); }

# drive_unattended <dir>: the runbook UNATTENDED MODE order up to and including the scope check.
# Sets SID, HEAD0, REPORT (file with report stdout), SCOPE_OUT, SCOPE_RC.
drive_unattended() {
  local d="$1"
  SID="synth-20261130T060000Z"
  export TELEMETRY_DIR="$d/04_Logs/Telemetry"
  ( cd "$d" && ./.vault_link/.scripts/telemetry_start.sh synthesize )
  WEEK="$(cd "$d" && ./.vault_link/.scripts/synthesize_run.sh week --today 2026-11-23)"
  ( cd "$d" && ./.vault_link/.scripts/session_state_write.sh --persona Synthesizer --session-id "$SID" \
      --started-at 2026-11-30T06:00:00Z --no-legacy-mirror ) >/dev/null
  ( cd "$d" && TITAN_SESSION_ID="$SID" ./.vault_link/.scripts/persona_check.sh Synthesizer ) >/dev/null
  HEAD0="$(git -C "$d" rev-parse HEAD)"
  ( cd "$d" && ./.vault_link/.scripts/synthesize_run.sh plan --week "$WEEK" ) > "$TMP/plan.out"
  sleep 0.1
  write_w47 "$d"
  REPORT="$TMP/report.out"
  ( cd "$d" && ./.vault_link/.scripts/synthesize_run.sh report --week "$WEEK" --unattended ) > "$REPORT"
  ( cd "$d/03_Brain/Weekly_Synthesis" && mv facts.jsonl.next facts.jsonl )
  SCOPE_OUT="$(cd "$d" && ./.vault_link/.scripts/synthesize_run.sh scope --session-id "$SID" --head "$HEAD0")"; SCOPE_RC=$?
  unset TELEMETRY_DIR
}

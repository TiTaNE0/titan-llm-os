#!/usr/bin/env bash
# preflight.sh — step 0 of every reply pipeline run (v3.2, E21/E23): live probes, run lock,
# branch guard and Mail readiness, each with a time limit. Prints one JSON object.
#
# Usage:
#   preflight.sh [--slot HH:MM] [--run-token T] full preflight (RESUME / second attempt: the token of the run)
#   preflight.sh --critic-only --exclude NAME pick the next critic rung (after a calibration failure)
#   preflight.sh --release                    remove the run lock (last step of maintenance)
#
# Steps, in order: bash 4+; params; pattern sheet (target_filter.py hooks); authority zones;
# slot id; branch main and clean C/skill, C/agents, C/bin; atomic mkdir lock (stale after
# lock_stale_min). The first preflight of a run creates a run token, writes it into the lock and into
# the run's batch folder (runs/SLOT_ID_batch/run_token) and prints it; only a caller presenting that
# token (--run-token: RESUME or a new attempt of the run) passes a held lock, any other session gets 5.
# Mail automation answer, empty Outbox, no pipeline message in Drafts; endpoint probe (reported, not a
# stop); grok fenced-JSON probe only when grok_probe_needed (slot_state.py: after a good grok call of
# this slot, the probe included, none is spent again until a grok call of the slot fails), spent from
# the run's grok budget first (budget at 0 stops a new run with 7 and reason grok_budget; a RESUME is
# never stopped by it: it skips the probe and reports grok_probe_skipped); the probe result is recorded
# (slot_state.py grok-result); agy models, then a probe down agents/critic_ladder.json (first answer wins,
# written to runs/_index/critic_model.json); search_vectors.json freshness; slot_state.py health.
# On any stop it writes the slot-log line itself, so every stop is counted and can alarm.
# Exit: 0 ok, 2 config, 3 outside slot window, 5 locked, 6 branch or dirty tree, 7 grok dead or grok budget at 0,
# 8 no usable critic rung, 9 Mail not ready, 10 pattern sheet missing or unusable,
# 11 grok balance exhausted.
# Test guard: with PIPELINE_TEST=1, OSASCRIPT_BIN, GROK_BIN and AGY_BIN must point inside tests/stubs/.
set -uo pipefail

if (( ${BASH_VERSINFO[0]:-0} < 4 )); then
  echo "preflight: needs bash >= 4 (run with /opt/homebrew/bin/bash)" >&2; exit 2
fi

BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
C="$(cd "$BIN/.." && pwd -P)"
STUBS="$C/tests/stubs"
STATE="${PIPELINE_STATE_DIR:-$C/runs/_index}"
PARAMS="${PIPELINE_PARAMS:-$C/agents/params.json}"
PATTERNS="${PIPELINE_PATTERNS:-$C/reply_patterns.md}"
LADDER="$C/agents/critic_ladder.json"
OSA="${OSASCRIPT_BIN:-osascript}"
GROK="${GROK_BIN:-grok}"
AGY="${AGY_BIN:-agy}"
LOCK="$STATE/.run.lock"
if [ -n "${PIPELINE_RUNS_DIR:-}" ]; then RUNS="$PIPELINE_RUNS_DIR"
elif [ "${PIPELINE_TEST:-0}" = "1" ]; then RUNS="$STATE/runs"   # never the live runs/ in tests
else RUNS="$C/runs"; fi
PROBE_URL="https://x.com/nateherk/status/2124541215333044480"
mkdir -p "$STATE"

pj() { python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(eval(sys.argv[2], {}, {'d': d}))" "$@"; }
tmo() { local s="$1"; shift; perl -e 'alarm shift; exec @ARGV' "$s" "$@"; }
now_epoch() { python3 -c 'import os,datetime as dt; v=os.environ.get("PIPELINE_NOW"); print(int((dt.datetime.fromisoformat(v.replace("Z","+00:00")) if v else dt.datetime.now(dt.timezone.utc)).timestamp()))'; }
has_fence() { grep -q '```json' <<<"$1"; }

if [ "${PIPELINE_TEST:-0}" = "1" ]; then
  for b in "$OSA" "$GROK" "$AGY"; do
    case "$(cd "$(dirname "$b")" 2>/dev/null && pwd -P)/" in
      "$STUBS/"*) ;;
      *) echo "preflight: test guard: PIPELINE_TEST=1 needs OSASCRIPT_BIN, GROK_BIN, AGY_BIN inside tests/stubs/" >&2; exit 2 ;;
    esac
  done
fi

if [ "${1:-}" = "--release" ]; then
  rm -rf "$LOCK"; echo '{"released": true}'; exit 0
fi

critic_only=0; exclude=""; slot_arg=(); run_token=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --critic-only) critic_only=1; shift ;;
    --exclude)     exclude="${2:-}"; shift 2 ;;
    --slot)        slot_arg=(--slot "${2:-}"); shift 2 ;;
    --run-token)   run_token="${2:-}"; shift 2 ;;
    *) echo "preflight: unknown arg $1" >&2; exit 2 ;;
  esac
done

SID="$(python3 "$BIN/slot_state.py" slot-id "${slot_arg[@]}" 2>/dev/null || true)"
LOCKED_BY_ME=0
GROK_CALLS=0; GROK_OK=""

stop() {  # stop EXIT REASON DETAIL
  local code="$1" reason="$2" detail="$3"
  echo "preflight: $detail" >&2
  if [ -n "$SID" ]; then
    local g=()
    [ "$GROK_CALLS" -gt 0 ] && g=(--grok-calls "$GROK_CALLS" --grok-ok "$GROK_OK")
    python3 "$BIN/slot_state.py" log --slot "$SID" --reason "$reason" --detail "preflight exit $code: $detail" \
      --attempts 1 "${g[@]}" >/dev/null 2>&1 || true
  fi
  [ "$LOCKED_BY_ME" = "1" ] && rm -rf "$LOCK"
  printf '{"ok": false, "exit": %s, "reason": "%s", "detail": "%s"}\n' "$code" "$reason" "${detail//\"/\'}"
  exit "$code"
}

# ---------- critic ladder ---------------------------------------------------------------
rung_failed_recently() {  # rung telemetry id -> 0 when its last qualification inside the window failed
  python3 - "$STATE/critic_qualified.json" "$1" "$PARAMS" <<'PY'
import json, sys, os, datetime as dt
try:
    q = json.load(open(sys.argv[1]))
except (OSError, ValueError):
    sys.exit(1)
days = json.load(open(sys.argv[3]))["critic_qualified_days"]
e = q.get(sys.argv[2])
if not e or e.get("result") != "fail":
    sys.exit(1)
v = os.environ.get("PIPELINE_NOW")
now = dt.datetime.fromisoformat(v.replace("Z", "+00:00")) if v else dt.datetime.now(dt.timezone.utc)
at = dt.datetime.fromisoformat(e["at"].replace("Z", "+00:00"))
sys.exit(0 if now - at < dt.timedelta(days=days) else 1)
PY
}

pick_critic() {
  local models n i name tid prov out
  models="$(tmo 60 "$AGY" models 2>&1)" || models=""
  n="$(pj "$LADDER" 'len(d["rungs"])')"
  for ((i=0; i<n; i++)); do
    name="$(pj "$LADDER" "d['rungs'][$i]['cli_name']")"
    tid="$(pj "$LADDER" "d['rungs'][$i]['telemetry_id']")"
    prov="$(pj "$LADDER" "d['rungs'][$i]['provider']")"
    [ "$name" = "$exclude" ] || [ "$tid" = "$exclude" ] && continue
    rung_failed_recently "$tid" && continue
    out="$(tmo 180 "$AGY" -p 'Reply with exactly one fenced json block and nothing else: {"probe": "ok"}' \
           --model "$name" --print-timeout 2m 2>&1)" || continue
    if has_fence "$out"; then
      python3 -c 'import json,sys; json.dump({"cli_name": sys.argv[1], "telemetry_id": sys.argv[2], "provider": sys.argv[3], "chosen_at": sys.argv[4], "listed": sys.argv[5] == "1"}, open(sys.argv[6], "w"))' \
        "$name" "$tid" "$prov" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(grep -qF "$name" <<<"$models" && echo 1 || echo 0)" "$STATE/critic_model.json"
      CRITIC="$tid"
      return 0
    fi
  done
  return 1
}

if [ "$critic_only" = "1" ]; then
  CRITIC=""
  pick_critic || { echo '{"ok": false, "exit": 8, "reason": "infra", "detail": "no usable critic rung"}'; exit 8; }
  printf '{"ok": true, "critic_model": "%s"}\n' "$CRITIC"; exit 0
fi

# ---------- 1-4: params, pattern sheet, zones, slot -------------------------------------------
python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$PARAMS" 2>/dev/null || stop 2 infra "params unreadable: $PARAMS"
python3 "$BIN/target_filter.py" hooks --patterns "$PATTERNS" >/dev/null 2>&1 \
  || stop 10 preflight_failed "pattern sheet missing or without a usable hook: $PATTERNS"
python3 "$BIN/target_filter.py" zones --out "$STATE/authority_zones.json" >/dev/null 2>&1 \
  || stop 2 infra "authority zones not readable from voice.md"
[ -n "$SID" ] || { echo '{"ok": false, "exit": 3, "reason": "outside_slot"}'; exit 3; }

# ---------- 5: branch guard ------------------------------------------------------------------
branch="${PIPELINE_GIT_BRANCH:-$(git -C "$C" rev-parse --abbrev-ref HEAD 2>/dev/null)}"
if [ -n "${PIPELINE_GIT_DIRTY+x}" ]; then
  dirty="$([ "$PIPELINE_GIT_DIRTY" = "1" ] && echo dirty)"
else
  dirty="$(git -C "$C" status --porcelain -- skill agents bin 2>/dev/null | head -1)"
fi
[ "$branch" = "main" ] || stop 6 guard "branch is '$branch', not main"
[ -z "$dirty" ] || stop 6 guard "uncommitted changes under skill/, agents/ or bin/"

# ---------- 6: lock --------------------------------------------------------------------------
BATCH_DIR="$RUNS/${SID}_batch"
RESUMING=0
[ -n "$run_token" ] && [ "$run_token" = "$(cat "$BATCH_DIR/run_token" 2>/dev/null)" ] && RESUMING=1
if mkdir "$LOCK" 2>/dev/null; then
  now_epoch > "$LOCK/started_at"
elif [ -n "$run_token" ] && [ "$(cat "$LOCK/token" 2>/dev/null)" = "$run_token" ]; then
  :  # this run's own lock: RESUME or a new attempt of the run
else
  started="$(cat "$LOCK/started_at" 2>/dev/null || echo 0)"
  stale_min="$(pj "$PARAMS" 'd["lock_stale_min"]')"
  if (( $(now_epoch) - started > stale_min * 60 )); then
    rm -rf "$LOCK"; mkdir "$LOCK" 2>/dev/null || stop 5 locked "run lock held"
    now_epoch > "$LOCK/started_at"
  else
    stop 5 locked "run lock held by another session (slot $(cat "$LOCK/slot_id" 2>/dev/null || echo '?'), pid $(cat "$LOCK/pid" 2>/dev/null || echo '?'))"
  fi
fi
LOCKED_BY_ME=1
if [ "$RESUMING" = "1" ]; then
  TOKEN="$run_token"
else
  TOKEN="$(python3 -c 'import secrets; print(secrets.token_hex(8))')"
  mkdir -p "$BATCH_DIR" && printf '%s\n' "$TOKEN" > "$BATCH_DIR/run_token" || stop 2 infra "cannot write $BATCH_DIR/run_token"
fi
printf '%s\n' "$TOKEN" > "$LOCK/token"; printf '%s\n' "$SID" > "$LOCK/slot_id"; echo "$$" > "$LOCK/pid"

# ---------- 7: Mail ---------------------------------------------------------------------------
OSA_ACCOUNTS='on run argv
  tell application "Mail" to return name of every account
end run'
OSA_OUTBOX='on run argv
  tell application "Mail" to return count of messages of outbox
end run'
# a pipeline draft whose subject is in Sent is a leftover copy of a delivered mail, not a stuck send
OSA_DRAFTS='on run argv
  set n to 0
  tell application "Mail"
    repeat with m in (messages of drafts mailbox whose subject contains "Twitter repl")
      set s to subject of m
      if (count of (messages of sent mailbox whose subject is s)) = 0 then set n to n + 1
    end repeat
  end tell
  return n
end run'
tmo 30 "$OSA" -e "$OSA_ACCOUNTS" accounts >/dev/null 2>&1 || stop 9 preflight_failed "Mail automation does not answer"
ob="$(tmo 30 "$OSA" -e "$OSA_OUTBOX" outbox_count 2>/dev/null | tr -dc '0-9')"
[ "${ob:-x}" = "0" ] || stop 9 preflight_failed "Mail Outbox holds ${ob:-?} message(s): clear it and check the outgoing server (I-9)"
dr="$(tmo 30 "$OSA" -e "$OSA_DRAFTS" drafts_pipeline 2>/dev/null | tr -dc '0-9')"
[ "${dr:-x}" = "0" ] || stop 9 preflight_failed "Mail Drafts holds a pipeline message: a send is stuck (I-9)"

# ---------- 8: endpoint (reported, not a stop) -------------------------------------------------
endpoint_ok=false
tmo 30 python3 "$BIN/fetch_posts.py" status --url "$PROBE_URL" >/dev/null 2>&1 && endpoint_ok=true

# ---------- 9: grok probe, only when the last grok call did not succeed --------------------------
hhmm="${SID: -4:2}:${SID: -2}"
need="$(python3 "$BIN/slot_state.py" budget --posted-today-unknown --slot "$hhmm" 2>/dev/null \
        | python3 -c 'import json,sys; print(json.load(sys.stdin)["grok_probe_needed"])' 2>/dev/null || echo True)"
grok_probe=false; grok_probe_skipped=false
probe_result() { python3 "$BIN/slot_state.py" grok-result --slot "$SID" --purpose probe --ok "$1" >/dev/null 2>&1 || true; }
if [ "${need}" = "True" ]; then
  if ! why="$(python3 "$BIN/slot_state.py" grok-call --slot "$SID" --purpose probe 2>&1 >/dev/null)"; then
    # a resume continues from saved artifacts and is never stopped by the budget for its probe
    [ "$RESUMING" = "1" ] || stop 7 grok_budget "${why:-grok budget at 0}; no probe"
    grok_probe_skipped=true
  else
    grok_probe=true; GROK_CALLS=1
    out="$(tmo 420 "$GROK" -p 'Reply with exactly one fenced json block and nothing else: {"probe": "ok"}' 2>&1)"
    if grep -q "402" <<<"$out" && grep -qi "balance exhausted" <<<"$out"; then
      GROK_OK=false; probe_result false; stop 11 grok_balance "grok balance exhausted"
    fi
    has_fence "$out" || { GROK_OK=false; probe_result false; stop 7 infra "grok fenced-JSON probe failed"; }
    GROK_OK=true; probe_result true
  fi
fi

# ---------- 10: critic ladder ---------------------------------------------------------------------
CRITIC=""
pick_critic || stop 8 infra "no usable critic rung on agents/critic_ladder.json"

# ---------- 11-12: vectors, health ----------------------------------------------------------------
vectors_fresh="$(python3 - "$STATE/search_vectors.json" <<'PY'
import json, sys, datetime as dt
try:
    v = json.load(open(sys.argv[1]))
except (OSError, ValueError):
    print("false"); sys.exit()
at = v.get("generated_at")
try:
    age = dt.datetime.now(dt.timezone.utc) - dt.datetime.fromisoformat(str(at).replace("Z", "+00:00"))
    fresh = age < dt.timedelta(days=7)
except ValueError:
    fresh = False
print("true" if fresh else "false")
PY
)"
health="$(python3 "$BIN/slot_state.py" health 2>/dev/null | python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin)))' 2>/dev/null || echo '{}')"

printf '{"ok": true, "slot_id": "%s", "run_token": "%s", "resuming": %s, "endpoint_ok": %s, "grok_probe": %s, "grok_probe_skipped": %s, "grok_calls": %s, "grok_ok": %s, "critic_model": "%s", "vectors_fresh": %s, "health": %s}\n' \
  "$SID" "$TOKEN" "$([ "$RESUMING" = 1 ] && echo true || echo false)" "$endpoint_ok" "$grok_probe" "$grok_probe_skipped" "$GROK_CALLS" "${GROK_OK:-null}" "$CRITIC" "${vectors_fresh:-false}" "$health"
exit 0

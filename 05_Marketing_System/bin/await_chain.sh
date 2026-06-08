#!/usr/bin/env bash
# await_chain.sh — durable observe-and-surface for a native-dispatch pipeline run (FIX 2b/2c/2d).
# The gateway walks the DAG (no external driver). This watches the board and GUARANTEES a
# visible terminal outcome — never a silent stall:
#   - terminal node done                       -> SUCCESS (exit 0)
#   - a downstream node blocked by a gatekeeper kill (expected content gate) -> KILL (exit 0)
#   - any node infra-blocked/failed (retries exhausted / crash / timeout / no kanban_complete)
#                                               -> write FAILURE.md, exit 20
#   - overall timeout with no terminal          -> write FAILURE.md (stuck node), exit 20
# Completed step outputs stay on disk throughout — paid work is preserved.
#
# Usage:
#   await_chain.sh --run-dir <abs> --board <slug> --terminal <task-id> \
#     --map "id1=Scout id2=Strategist id3=Creator id4=Gatekeeper id5=Debate id6=Judge id7=Producer" \
#     [--timeout 3600] [--interval 20]
# Exit: 0 success or expected content-kill · 20 infra failure (FAILURE.md written) · 2 usage
set -euo pipefail

RUN_DIR=""; BOARD=""; TERMINAL=""; MAP=""; TIMEOUT=3600; INTERVAL=20
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-dir)  RUN_DIR="$2"; shift 2 ;;
    --board)    BOARD="$2"; shift 2 ;;
    --terminal) TERMINAL="$2"; shift 2 ;;
    --map)      MAP="$2"; shift 2 ;;
    --timeout)  TIMEOUT="$2"; shift 2 ;;
    --interval) INTERVAL="$2"; shift 2 ;;
    -h|--help)  sed -n '2,18p' "$0"; exit 0 ;;
    *)          echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done
[[ -n "$RUN_DIR" && -n "$BOARD" && -n "$TERMINAL" && -n "$MAP" ]] || { echo "E2: --run-dir, --board, --terminal, --map required" >&2; exit 2; }
[[ -d "$RUN_DIR" ]] || { echo "E2: run-dir not found: $RUN_DIR" >&2; exit 2; }

# Parse ordered "id=Label id=Label" map into parallel arrays.
IDS=(); LABELS=()
for pair in $MAP; do IDS+=("${pair%%=*}"); LABELS+=("${pair#*=}"); done

label_of(){ local id="$1" i; for i in "${!IDS[@]}"; do [[ "${IDS[$i]}" == "$id" ]] && { echo "${LABELS[$i]}"; return; }; done; echo "$id"; }
status_of(){ hermes kanban --board "$BOARD" show "$1" 2>/dev/null | grep -m1 -oE 'status:[[:space:]]+[a-z_]+' | grep -oE '[a-z_]+$'; }

# Reason for a non-success node: prefer the last run's status/outcome/error; fall back to the
# block note in `show`. Used both to classify infra failures and to detect a gatekeeper kill.
reason_of(){
  local id="$1" r
  r="$(hermes kanban --board "$BOARD" runs "$id" --json 2>/dev/null | python3 -c "
import json,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
r=d if isinstance(d,list) else d.get('runs',[])
if r:
    last=r[-1]
    print(' '.join(str(last.get(k,'') or '') for k in ('status','outcome','error','summary')).split('\n')[0].strip())
" 2>/dev/null)"
  if [[ -z "$r" ]]; then
    r="$(hermes kanban --board "$BOARD" show "$id" 2>/dev/null | grep -iE 'block|reason|fail' | head -1)"
  fi
  printf '%s' "$r" | tr '\n' ' '
}

DEADLINE=$(( $(date +%s) + TIMEOUT ))
echo "await_chain: watching ${#IDS[@]} nodes on board=$BOARD (timeout ${TIMEOUT}s, terminal=$(label_of "$TERMINAL"))"

while :; do
  line="[await]"
  for id in "${IDS[@]}"; do line+=" $(label_of "$id")=$(status_of "$id")"; done
  echo "$line"

  # Success: terminal node reached done.
  if [[ "$(status_of "$TERMINAL")" == "done" ]]; then
    echo "SUCCESS: terminal node '$(label_of "$TERMINAL")' done — chain complete."
    exit 0
  fi

  # Inspect any non-success node.
  for id in "${IDS[@]}"; do
    st="$(status_of "$id")"
    case "$st" in
      blocked|failed)
        reason="$(reason_of "$id")"
        if printf '%s' "$reason" | grep -qiE 'gatekeeper kill|killed by gatekeeper'; then
          echo "CONTENT KILL (expected): '$(label_of "$id")' blocked by the Gatekeeper gate — chain short-circuited by design, not an infra failure."
          exit 0
        fi
        # Infra failure: classify from the last attempt, preserve everything, surface it.
        cls="worker-failed"
        case "$reason" in
          *timed_out*|*timeout*) cls="timeout (worker exceeded wall-clock/turn cap)" ;;
          *spawn_failed*)        cls="spawn-failed (worker could not start — bad model/provider/auth)" ;;
          *crashed*)             cls="crash (worker process died)" ;;
          *)                     cls="retries-exhausted / protocol-violation (no kanban_complete)" ;;
        esac
        echo "INFRA FAILURE at '$(label_of "$id")' — $cls"
        "$SCRIPT_DIR/write_failure.sh" --run-dir "$RUN_DIR" --node "$(label_of "$id")" \
          --reason "$cls" --board "$BOARD" --task "$id" --detail "$reason" >&2 || true
        exit 20
        ;;
    esac
  done

  if [[ $(date +%s) -ge $DEADLINE ]]; then
    stuck=""; for id in "${IDS[@]}"; do [[ "$(status_of "$id")" != "done" ]] && { stuck="$id"; break; }; done
    echo "INFRA FAILURE: overall timeout ${TIMEOUT}s with no terminal — stuck at '$(label_of "$stuck")'"
    "$SCRIPT_DIR/write_failure.sh" --run-dir "$RUN_DIR" --node "$(label_of "$stuck")" \
      --reason "timeout: chain exceeded ${TIMEOUT}s without reaching the terminal node" \
      --board "$BOARD" --task "$stuck" >&2 || true
    exit 20
  fi

  sleep "$INTERVAL"
done

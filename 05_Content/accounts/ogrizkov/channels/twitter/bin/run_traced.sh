#!/usr/bin/env bash
# run_traced.sh — run a CLI model call, time it, capture output, emit telemetry.
#
# For non-Claude CLI roles (grok Scout / Critic / Wins-logger) where the harness
# does NOT report token usage. It measures wall-clock and a char/4 token PROXY
# from the prompt + captured output, then calls trace.sh. It is TRANSPARENT:
# it returns the wrapped command's own exit code, so callers can branch on it.
#
# (Claude sub-agents do NOT use this — the orchestrator already gets real
# subagent_tokens from the Agent tool and calls trace.sh directly with them.)
#
# Usage:
#   run_traced.sh --run-dir <dir> --role <name> --model <id> --provider <p> \
#     --out <output_file> [--target <url>] [--vector <v>] [--retry <n>] \
#     [--prompt-file <f>] [--timeout <seconds>] \
#     [--grok-slot <SLOT_ID> --grok-purpose discovery|widen|read|maintenance [--grok-batch <B>]] \
#     -- <command> [args...]
#
# Grok budget: with --grok-purpose the call is first spent through `slot_state.py grok-call`; when
# that refuses (budget at 0, or a second attempt asking for a new discovery) the command is not
# run, the refusal goes to --out and the exit is 75. A command named grok without --grok-purpose
# is refused with exit 64, so no grok call bypasses the budget. After the call its result (ok, or
# failed for error/timeout/no_block) is recorded with `slot_state.py grok-result`; a failed call of
# the slot makes the next preflight of that slot probe grok again.
#
# Output of <command> is written to --out (stdout+stderr). Telemetry line is
# appended to <run-dir>/_telemetry.jsonl. duration_ms and char-proxy token counts
# are filled automatically; outcome = ok|error from the command's exit code,
# timeout when --timeout fired (exit 124; macOS has no `timeout`, so perl's alarm is used),
# no_block when the command exited 0 but its output holds no fenced ```json block.

set -uo pipefail
BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

run_dir="" role="" model="" provider="" out="" target="" vector="" retry="" prompt_file="" timeout_s=""
grok_slot="" grok_purpose="" grok_batch=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --run-dir)     run_dir="${2:-}";     shift 2 ;;
    --role)        role="${2:-}";        shift 2 ;;
    --model)       model="${2:-}";       shift 2 ;;
    --provider)    provider="${2:-}";    shift 2 ;;
    --out)         out="${2:-}";         shift 2 ;;
    --target)      target="${2:-}";      shift 2 ;;
    --vector)      vector="${2:-}";      shift 2 ;;
    --retry)       retry="${2:-}";       shift 2 ;;
    --prompt-file) prompt_file="${2:-}"; shift 2 ;;
    --timeout)     timeout_s="${2:-}";   shift 2 ;;
    --grok-slot)   grok_slot="${2:-}";   shift 2 ;;
    --grok-purpose) grok_purpose="${2:-}"; shift 2 ;;
    --grok-batch)  grok_batch="${2:-}";  shift 2 ;;
    --)            shift; break ;;
    *)             echo "run_traced: unknown arg: $1" >&2; shift ;;
  esac
done

if [ -z "$run_dir" ] || [ -z "$role" ] || [ -z "$out" ] || [ "$#" -eq 0 ]; then
  echo "run_traced: need --run-dir, --role, --out, and a -- <command>" >&2
  exit 64
fi

if [ -z "$grok_purpose" ] && [ "$(basename "$1")" = "grok" ]; then
  echo "run_traced: a grok call needs --grok-slot and --grok-purpose (grok budget)" >&2
  exit 64
fi
if [ -n "$grok_purpose" ]; then
  [ -n "$grok_slot" ] || { echo "run_traced: --grok-purpose needs --grok-slot" >&2; exit 64; }
  gargs=(grok-call --slot "$grok_slot" --purpose "$grok_purpose")
  [ -n "$grok_batch" ] && gargs+=(--batch "$grok_batch")
  if ! why="$(python3 "$BIN_DIR/slot_state.py" "${gargs[@]}" 2>&1 >/dev/null)"; then
    printf 'grok budget: %s\n' "$why" > "$out"
    echo "run_traced: grok budget: $why" >&2
    exit 75
  fi
fi

now_ms() {
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import time;print(int(time.time()*1000))'
  else
    echo $(( $(date +%s) * 1000 ))
  fi
}

start_ms="$(now_ms)"
timed_out=0
if [ -n "$timeout_s" ]; then
  ( perl -e 'alarm shift; exec @ARGV' "$timeout_s" "$@" > "$out" 2>&1; exit $? ) 2>/dev/null
  code=$?
  # SIGALRM kills the command: 128 + 14
  if [ "$code" -eq 142 ]; then code=124; timed_out=1; fi
else
  "$@" > "$out" 2>&1
  code=$?
fi
end_ms="$(now_ms)"
dur=$(( end_ms - start_ms ))

# char/4 token proxies (CLI models don't report real token counts)
in_chars=0
[ -n "$prompt_file" ] && [ -r "$prompt_file" ] && in_chars=$(wc -c < "$prompt_file" | tr -d ' ')
out_chars=0
[ -r "$out" ] && out_chars=$(wc -c < "$out" | tr -d ' ')
tin=$(( in_chars / 4 ))
tout=$(( out_chars / 4 ))

outcome="ok"; [ "$code" -ne 0 ] && outcome="error"
[ "$timed_out" -eq 1 ] && outcome="timeout"
if [ "$code" -eq 0 ] && ! grep -q '```json' "$out" 2>/dev/null; then outcome="no_block"; fi

if [ -n "$grok_purpose" ]; then
  python3 "$BIN_DIR/slot_state.py" grok-result --slot "$grok_slot" --purpose "$grok_purpose" \
    --ok "$([ "$outcome" = "ok" ] && echo true || echo false)" >/dev/null 2>&1 || true
fi

# Telemetry is best-effort; never let it change our exit code.
"$BIN_DIR/trace.sh" --run-dir "$run_dir" --role "$role" --model "$model" \
  --provider "${provider:-cli}" --target "$target" --vector "$vector" --retry "$retry" \
  --duration-ms "$dur" --tokens-in "$tin" --tokens-out "$tout" \
  --reason "char-proxy tokens (CLI; not exact)" --outcome "$outcome" >/dev/null 2>&1 || true

exit "$code"

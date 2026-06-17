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
#     [--prompt-file <f>] -- <command> [args...]
#
# Output of <command> is written to --out (stdout+stderr). Telemetry line is
# appended to <run-dir>/_telemetry.jsonl. duration_ms and char-proxy token counts
# are filled automatically; outcome = ok|error from the command's exit code.

set -uo pipefail
BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

run_dir="" role="" model="" provider="" out="" target="" vector="" retry="" prompt_file=""
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
    --)            shift; break ;;
    *)             echo "run_traced: unknown arg: $1" >&2; shift ;;
  esac
done

if [ -z "$run_dir" ] || [ -z "$role" ] || [ -z "$out" ] || [ "$#" -eq 0 ]; then
  echo "run_traced: need --run-dir, --role, --out, and a -- <command>" >&2
  exit 64
fi

now_ms() {
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import time;print(int(time.time()*1000))'
  else
    echo $(( $(date +%s) * 1000 ))
  fi
}

start_ms="$(now_ms)"
"$@" > "$out" 2>&1
code=$?
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

# Telemetry is best-effort; never let it change our exit code.
"$BIN_DIR/trace.sh" --run-dir "$run_dir" --role "$role" --model "$model" \
  --provider "${provider:-cli}" --target "$target" --vector "$vector" --retry "$retry" \
  --duration-ms "$dur" --tokens-in "$tin" --tokens-out "$tout" \
  --reason "char-proxy tokens (CLI; not exact)" --outcome "$outcome" >/dev/null 2>&1 || true

exit "$code"

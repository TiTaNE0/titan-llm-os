#!/usr/bin/env bash
# trace.sh — append ONE per-call telemetry event to runs/<batch>/_telemetry.jsonl
#
# CAK-07 doctrine: telemetry OBSERVES, it never blocks. A tracing bug must never
# halt a pipeline run. This script ALWAYS exits 0 — on missing args, bad paths,
# or write failure. Errors go to stderr; the exit code stays 0.
#
# One line per role invocation (Scout call, a single Matcher bind, one Drafter
# draft, one Critic verdict, a Gatekeeper run, etc). Per-criterion detail lives
# in 03_review.json; this file is the EXECUTION log (timing, cost, headline
# outcome) that batch_report.sh rolls up.
#
# Usage:
#   trace.sh --run-dir <dir> --role <name> --model <id> --provider <p> \
#     [--vector <v>] [--target <url>] [--retry <n>] \
#     [--duration-ms <n>] [--tokens-in <n>] [--tokens-out <n>] \
#     [--verdict <s>] [--confidence <0..1>] [--reason <text>] \
#     [--outcome <drafted|passed|failed|skipped|held|quarantined|...>]
#
# Notes:
#   * tokens are often unavailable for CLI models (grok). Pass char-proxy counts
#     or leave unset (recorded as null). Claude sub-agents: pass the harness's
#     subagent_tokens.
#   * confidence is ORDINAL, not calibrated — a sort/triage signal, never a gate.

_trace_main() {
  local run_dir="" role="" model="" provider="" vector="" target="" retry=""
  local duration_ms="" tokens_in="" tokens_out="" verdict="" confidence="" reason="" outcome=""

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --run-dir)     run_dir="${2:-}";     shift 2 || return 0 ;;
      --role)        role="${2:-}";        shift 2 || return 0 ;;
      --model)       model="${2:-}";       shift 2 || return 0 ;;
      --provider)    provider="${2:-}";    shift 2 || return 0 ;;
      --vector)      vector="${2:-}";      shift 2 || return 0 ;;
      --target)      target="${2:-}";      shift 2 || return 0 ;;
      --retry)       retry="${2:-}";       shift 2 || return 0 ;;
      --duration-ms) duration_ms="${2:-}"; shift 2 || return 0 ;;
      --tokens-in)   tokens_in="${2:-}";   shift 2 || return 0 ;;
      --tokens-out)  tokens_out="${2:-}";  shift 2 || return 0 ;;
      --verdict)     verdict="${2:-}";     shift 2 || return 0 ;;
      --confidence)  confidence="${2:-}";  shift 2 || return 0 ;;
      --reason)      reason="${2:-}";      shift 2 || return 0 ;;
      --outcome)     outcome="${2:-}";     shift 2 || return 0 ;;
      *)             echo "trace: ignoring unknown arg: $1" >&2; shift ;;
    esac
  done

  if [ -z "${run_dir}" ] || [ -z "${role}" ]; then
    echo "trace: missing --run-dir or --role; skipping (non-blocking)" >&2
    return 0
  fi

  mkdir -p "${run_dir}" 2>/dev/null || echo "trace: mkdir failed for ${run_dir}" >&2
  local target_file="${run_dir}/_telemetry.jsonl"

  # Prefer python3 for safe JSON encoding (reasons may contain quotes/newlines).
  if command -v python3 >/dev/null 2>&1; then
    TRACE_RUNDIR="${run_dir}" TRACE_ROLE="${role}" TRACE_MODEL="${model}" \
    TRACE_PROVIDER="${provider}" TRACE_VECTOR="${vector}" TRACE_TARGET="${target}" \
    TRACE_RETRY="${retry}" TRACE_DUR="${duration_ms}" TRACE_TIN="${tokens_in}" \
    TRACE_TOUT="${tokens_out}" TRACE_VERDICT="${verdict}" TRACE_CONF="${confidence}" \
    TRACE_REASON="${reason}" TRACE_OUTCOME="${outcome}" TRACE_FILE="${target_file}" \
    python3 - <<'PY' 2>/dev/null || echo "trace: python encode/write failed" >&2
import json, os, datetime
def s(k):
    v = os.environ.get(k, "")
    return v if v != "" else None
def num(k):
    v = os.environ.get(k, "")
    if v == "": return None
    try: return int(v)
    except ValueError:
        try: return float(v)
        except ValueError: return None
rec = {
    "ts": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "role": s("TRACE_ROLE"),
    "model": s("TRACE_MODEL"),
    "provider": s("TRACE_PROVIDER"),
    "vector": s("TRACE_VECTOR"),
    "target": s("TRACE_TARGET"),
    "retry": num("TRACE_RETRY"),
    "duration_ms": num("TRACE_DUR"),
    "tokens_in": num("TRACE_TIN"),
    "tokens_out": num("TRACE_TOUT"),
    "verdict": s("TRACE_VERDICT"),
    "confidence": num("TRACE_CONF"),
    "reason": s("TRACE_REASON"),
    "outcome": s("TRACE_OUTCOME"),
}
with open(os.environ["TRACE_FILE"], "a") as f:
    f.write(json.dumps(rec, ensure_ascii=False) + "\n")
PY
    return 0
  fi

  # Fallback: minimal escaping in pure bash if python3 is unavailable.
  local ts; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)" || ts="unknown"
  esc() { printf '%s' "${1:-}" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
  {
    printf '{"ts":"%s","role":"%s","model":"%s","provider":"%s","target":"%s","verdict":"%s","reason":"%s","outcome":"%s","note":"bash-fallback"}\n' \
      "$ts" "$(esc "$role")" "$(esc "$model")" "$(esc "$provider")" "$(esc "$target")" "$(esc "$verdict")" "$(esc "$reason")" "$(esc "$outcome")"
  } >> "${target_file}" 2>/dev/null || echo "trace: append failed for ${target_file}" >&2
  return 0
}

( _trace_main "$@" ) 2>&2 || true
exit 0

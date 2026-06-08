#!/usr/bin/env bash
# trace_step.sh — append a non-blocking per-step trace record. PRD §8.9, §11.
#
# Trace OBSERVES, it never blocks. A tracing bug must NEVER halt a pipeline run.
# This script ALWAYS exits 0 — on missing args, bad paths, or write failure.
# Any internal error is logged to stderr; the exit code stays 0.
#
# Usage:
#   trace_step.sh --run-dir <dir> --step <NN_name> --agent <name> \
#     --model <id> --provider <p> --tokens-in <n> --tokens-out <n> \
#     --input <summary> --decision <text> [--output-file <path>]

# Deliberately NO `set -e` / `set -u` / `set -o pipefail`. The entire body runs
# inside a function whose failures are swallowed so the script cannot abort.

_trace_main() {
  local run_dir="" step="" agent="" model="" provider=""
  local tokens_in="" tokens_out="" input_summary="" decision="" output_file=""

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --run-dir)     run_dir="${2:-}";       shift 2 || return 0 ;;
      --step)        step="${2:-}";          shift 2 || return 0 ;;
      --agent)       agent="${2:-}";         shift 2 || return 0 ;;
      --model)       model="${2:-}";         shift 2 || return 0 ;;
      --provider)    provider="${2:-}";      shift 2 || return 0 ;;
      --tokens-in)   tokens_in="${2:-}";     shift 2 || return 0 ;;
      --tokens-out)  tokens_out="${2:-}";    shift 2 || return 0 ;;
      --input)       input_summary="${2:-}"; shift 2 || return 0 ;;
      --decision)    decision="${2:-}";      shift 2 || return 0 ;;
      --output-file) output_file="${2:-}";   shift 2 || return 0 ;;
      *)             echo "trace_step: ignoring unknown arg: $1" >&2; shift ;;
    esac
  done

  if [ -z "${run_dir}" ] || [ -z "${step}" ]; then
    echo "trace_step: missing --run-dir or --step; skipping trace (non-blocking)" >&2
    return 0
  fi

  # Best-effort: ensure the run dir exists. Failure is logged, not fatal.
  mkdir -p "${run_dir}" 2>/dev/null || echo "trace_step: mkdir failed for ${run_dir}" >&2

  local target="${run_dir}/${step}.md"
  local ts
  ts="$(date +%Y-%m-%dT%H:%M:%S%z 2>/dev/null)" || ts="unknown"

  # Resolve output: prefer file contents if provided/readable, else n/a excerpt.
  local output="n/a"
  if [ -n "${output_file}" ]; then
    if [ -r "${output_file}" ]; then
      output="see file: ${output_file}"
    else
      output="output-file unreadable: ${output_file}"
    fi
  fi

  # Defaults for unset mandatory cost fields so the record stays schema-shaped.
  [ -n "${agent}" ]        || agent="unknown"
  [ -n "${model}" ]        || model="unknown"
  [ -n "${provider}" ]     || provider="unknown"
  [ -n "${tokens_in}" ]    || tokens_in="n/a"
  [ -n "${tokens_out}" ]   || tokens_out="n/a"
  [ -n "${input_summary}" ] || input_summary="n/a"
  [ -n "${decision}" ]     || decision="n/a"

  {
    printf '## %s — %s\n' "${step}" "${ts}"
    printf -- '- agent: %s\n' "${agent}"
    printf -- '- model: %s\n' "${model}"
    printf -- '- provider: %s\n' "${provider}"
    printf -- '- tokens_in: %s\n' "${tokens_in}"
    printf -- '- tokens_out: %s\n' "${tokens_out}"
    printf -- '- input_summary: %s\n' "${input_summary}"
    printf -- '- output: %s\n' "${output}"
    printf -- '- decision: %s\n' "${decision}"
    printf '\n'
  } >> "${target}" 2>/dev/null || echo "trace_step: append failed for ${target}" >&2

  return 0
}

# Run the body in a subshell so even an unexpected `exit N` inside cannot
# propagate. Swallow everything; the wrapper guarantees exit 0.
( _trace_main "$@" ) 2>&2 || true

exit 0

#!/usr/bin/env bash
# Runs every acceptance test of this folder under the default bash and /bin/bash (3.2),
# then proves the live vault was not written by them. Telemetry and the daily log are
# append-only shared files, so only the bytes appended during the run are inspected; the
# session file, the Weekly_Synthesis listing and the synthesize error reports are strict.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
VAULT="$(cd "$HERE/../../.." && pwd -P)"
ERR="$(mktemp "${TMPDIR:-/tmp}/synth_acc_err.XXXXXX")"
SELF="$(mktemp -d "${TMPDIR:-/tmp}/synth_acc_self.XXXXXX")"
trap 'rm -rf "$ERR" "$SELF"' EXIT

size_of() { if [ -f "$1" ]; then wc -c < "$1" | tr -d ' '; else echo 0; fi; }
appended() { tail -c +$(($2 + 1)) "$1" 2>/dev/null; } # file size-before
tel_ok() { ! appended "$1" "$2" | grep -q '"macro":"synthesize"'; }
log_ok() { ! appended "$1" "$2" | grep -q '^Synthes'; }
strict_snap() {
  { shasum "$VAULT/.session_state.json" 2>/dev/null
    ls "$VAULT/03_Brain/Weekly_Synthesis"
    ls "$VAULT/04_Logs/Errors" 2>/dev/null | grep synthesize; } | shasum
}

rc=0
# Self-test of the append-only checks on sandbox copies (never the live files).
printf '{"macro":"x"}\n' > "$SELF/tel"; printf 'log line\n' > "$SELF/log"
tsz="$(size_of "$SELF/tel")"; lsz="$(size_of "$SELF/log")"
printf '{"macro":"close_task"}\n' >> "$SELF/tel"; printf 'other session line\n' >> "$SELF/log"
tel_ok "$SELF/tel" "$tsz" && log_ok "$SELF/log" "$lsz" && echo "PASS self-test: concurrent unrelated appends are accepted" || { echo "FAIL self-test: unrelated append rejected"; rc=1; }
printf '{"macro":"synthesize"}\n' >> "$SELF/tel"; printf 'Synthesize 2026-W47 (unattended): success.\n' >> "$SELF/log"
tel_ok "$SELF/tel" "$tsz" && { echo "FAIL self-test: appended synthesize row accepted"; rc=1; } || echo "PASS self-test: appended synthesize telemetry row is rejected"
log_ok "$SELF/log" "$lsz" && { echo "FAIL self-test: appended Synthes line accepted"; rc=1; } || echo "PASS self-test: appended Synthes daily-log line is rejected"
printf '{"macro":"synthesize"}\n' > "$SELF/tel_pre"; psz="$(size_of "$SELF/tel_pre")"; printf '{"macro":"y"}\n' >> "$SELF/tel_pre"
tel_ok "$SELF/tel_pre" "$psz" && echo "PASS self-test: a synthesize row already before the run is ignored" || { echo "FAIL self-test: pre-existing row counted"; rc=1; }
[ "$(size_of "$SELF/absent")" = 0 ] && echo "PASS self-test: absent file counts as size 0" || { echo "FAIL self-test: absent file size"; rc=1; }

LIVE_TEL="$VAULT/04_Logs/Telemetry/$(date -u +%Y-%m).jsonl"
LIVE_LOG="$VAULT/04_Logs/$(date +%Y-%m-%d).md"
tel_before="$(size_of "$LIVE_TEL")"; log_before="$(size_of "$LIVE_LOG")"
before="$(strict_snap)"
for sh in bash /bin/bash; do
  for t in "$HERE"/test_*.sh; do
    if "$sh" "$t" >/dev/null 2>"$ERR"; then echo "PASS [$sh] $(basename "$t")"
    else echo "FAIL [$sh] $(basename "$t")"; cat "$ERR"; rc=1; fi
  done
done
tel_ok "$LIVE_TEL" "$tel_before" && echo "PASS live telemetry gained no synthesize row" || { echo "FAIL live telemetry gained a synthesize row"; rc=1; }
log_ok "$LIVE_LOG" "$log_before" && echo "PASS live daily log gained no Synthes line" || { echo "FAIL live daily log gained a Synthes line"; rc=1; }
[ "$(strict_snap)" = "$before" ] && echo "PASS live session file / Weekly_Synthesis listing / synthesize error reports untouched" || { echo "FAIL live session file, Weekly_Synthesis or synthesize error reports changed"; rc=1; }
exit $rc

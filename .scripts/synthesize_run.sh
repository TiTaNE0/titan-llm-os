#!/usr/bin/env bash
# synthesize_run.sh
#
# Read-only helper for the /synthesize runbook (.scripts/runbooks/synthesize.md).
# Holds the deterministic parts: previous ISO week, week log selection, the
# overwrite guard, output validation with log-line rendering, and the
# write-scope check of an unattended run. It writes nothing and calls no other
# atom; no telemetry (Composition Rule 4, read-only tool).
#
# Idempotent: Yes (read-only). Persona Gate: Any.
#
# Subcommands:
#   week  [--today YYYY-MM-DD]           previous ISO week of (today - 7 days)
#   plan  --week YYYY-Www                week bounds, logs to read, output paths
#   report --week YYYY-Www [--unattended]  validate outputs, render log lines
#   scope --session-id <id> [--head <sha>] list writes outside the allowed paths
#
# Exit codes:
#   0  ok
#   1  E1 blocker (Weekly_Synthesis or facts.jsonl missing, no session marker,
#      python3 missing)
#   3  E3 malformed input or inconsistent outputs, or an unresolved
#      facts.jsonl.next from a failed run (usage errors too)
#   4  E4 scope violation (scope only)
#   6  plan only: both outputs already exist (already_synthesized)
#
# Needs python3 3.8+ (date.fromisocalendar). Runs under bash 3.2.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
VAULT_DIR="$(dirname "$SCRIPT_DIR")"
SYN_REL="03_Brain/Weekly_Synthesis"
SYN_DIR="$VAULT_DIR/$SYN_REL"

usage() {
  cat <<EOF
Usage: $(basename "$0") <subcommand> [args]

  week   [--today YYYY-MM-DD]
  plan   --week YYYY-Www
  report --week YYYY-Www [--unattended]
  scope  --session-id <id> [--head <sha>]
EOF
}

die3() { echo "E3: $1" >&2; exit 3; }
die1() { echo "E1: $1" >&2; exit 1; }

need_python() { command -v python3 >/dev/null 2>&1 || die1 "python3 not installed"; }

valid_week_arg() {
  [[ "$1" =~ ^[0-9]{4}-W[0-9]{2}$ ]] || die3 "malformed --week '$1' (expected YYYY-Www)"
}

# Prints "<monday> <sunday>" for an ISO week; exit 3 when the week does not exist.
week_bounds() {
  python3 -I - "$1" <<'PY'
import sys, datetime
y, w = sys.argv[1].split("-W")
try:
    mon = datetime.date.fromisocalendar(int(y), int(w), 1)
except ValueError:
    sys.exit(3)
print(mon.isoformat(), (mon + datetime.timedelta(days=6)).isoformat())
PY
}

cmd_week() {
  local today=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --today) [[ $# -ge 2 ]] || die3 "--today needs a value"; today="$2"; shift 2 ;;
      *) die3 "unknown arg: $1" ;;
    esac
  done
  need_python
  [[ -n "$today" ]] || today="$(TZ=Asia/Jerusalem date +%Y-%m-%d)"
  [[ "$today" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || die3 "malformed --today '$today' (expected YYYY-MM-DD)"
  python3 -I - "$today" <<'PY'
import sys, datetime
try:
    d = datetime.date.fromisoformat(sys.argv[1]) - datetime.timedelta(days=7)
except ValueError:
    sys.exit(3)
iso = d.isocalendar()
print("%04d-W%02d" % (iso[0], iso[1]))
PY
  local rc=$?
  [[ $rc -eq 0 ]] && return 0
  [[ $rc -eq 3 ]] && die3 "impossible --today '$today'"
  exit 1
}

cmd_plan() {
  local week=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --week) [[ $# -ge 2 ]] || die3 "--week needs a value"; week="$2"; shift 2 ;;
      *) die3 "unknown arg: $1" ;;
    esac
  done
  [[ -n "$week" ]] || die3 "missing --week"
  valid_week_arg "$week"
  need_python
  local bounds monday sunday
  bounds="$(week_bounds "$week")" || die3 "week '$week' does not exist in the ISO calendar"
  monday="${bounds%% *}"
  sunday="${bounds##* }"

  [[ -d "$SYN_DIR" ]] || die1 "$SYN_REL/ is missing"
  [[ -f "$SYN_DIR/facts.jsonl" ]] || die1 "$SYN_REL/facts.jsonl is missing"
  [[ ! -e "$SYN_DIR/facts.jsonl.next" ]] \
    || die3 "unresolved facts.jsonl.next from a failed run; delete it and the failed week's outputs, then rerun /synthesize interactively"

  local out_md="$SYN_REL/$week.synthesis.md" out_json="$SYN_REL/$week.synthesis.json"
  local has_md=0 has_json=0
  [[ -e "$VAULT_DIR/$out_md" ]] && has_md=1
  [[ -e "$VAULT_DIR/$out_json" ]] && has_json=1
  if [[ $has_md -eq 1 && $has_json -eq 1 ]]; then
    echo "week=$week"
    echo "status=already_synthesized"
    exit 6
  fi
  if [[ $has_md -ne $has_json ]]; then
    die3 "exactly one of $out_md and $out_json exists; resolve by hand"
  fi

  echo "week=$week"
  echo "monday=$monday"
  echo "sunday=$sunday"
  local f name date count=0
  for f in "$VAULT_DIR"/04_Logs/*.md; do
    [[ -f "$f" ]] || continue
    name="$(basename "$f")"
    [[ "$name" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}\.md$ ]] || continue
    date="${name%.md}"
    if [[ ! "$date" < "$monday" && ! "$date" > "$sunday" ]]; then
      echo "log=04_Logs/$name"
      count=$((count + 1))
    fi
  done
  echo "logs=$count"
  echo "out_md=$out_md"
  echo "out_json=$out_json"
  echo "facts=$SYN_REL/facts.jsonl"
}

cmd_report() {
  local week="" mode="interactive"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --week) [[ $# -ge 2 ]] || die3 "--week needs a value"; week="$2"; shift 2 ;;
      --unattended) mode="unattended"; shift ;;
      *) die3 "unknown arg: $1" ;;
    esac
  done
  [[ -n "$week" ]] || die3 "missing --week"
  valid_week_arg "$week"
  need_python
  PYTHONIOENCODING=utf-8 python3 -I - "$week" "$mode" "$SYN_DIR" <<'PY'
import sys, os, json, re

week, mode, syn = sys.argv[1], sys.argv[2], sys.argv[3]

def fail(msg):
    sys.stderr.write("E3: %s\n" % msg)
    sys.exit(3)

def collapse(s):
    return re.sub(r"\s+", " ", str(s)).strip()

jpath = os.path.join(syn, week + ".synthesis.json")
mpath = os.path.join(syn, week + ".synthesis.md")
if not os.path.isfile(jpath):
    fail("missing %s.synthesis.json" % week)
try:
    with open(jpath, encoding="utf-8") as fh:
        data = json.load(fh)
except (ValueError, OSError) as e:
    fail("%s.synthesis.json is not valid JSON (%s)" % (week, e))
if not isinstance(data, dict):
    fail("%s.synthesis.json is not a JSON object" % week)

for key in ("iso_week", "dates", "synthesized_at", "persona", "logs_read",
            "facts_added", "contradictions", "rule_proposals"):
    if key not in data:
        fail("synthesis json lacks key '%s'" % key)
if data["iso_week"] != week:
    fail("iso_week '%s' does not match %s" % (data["iso_week"], week))
for key in ("logs_read", "facts_added", "contradictions", "rule_proposals"):
    if not isinstance(data[key], list):
        fail("'%s' must be an array" % key)

for i, c in enumerate(data["contradictions"]):
    if not isinstance(c, dict):
        fail("contradictions[%d] is not an object" % i)
    pair = c.get("facts")
    if not isinstance(pair, list) or len(pair) != 2:
        fail("contradictions[%d].facts must be an array of two fact ids" % i)
    st = c.get("status", "open")
    if not isinstance(st, str) or st not in ("open", "resolved"):
        fail("contradictions[%d].status '%s' is not open or resolved" % (i, st))
for i, p in enumerate(data["rule_proposals"]):
    if not isinstance(p, dict):
        fail("rule_proposals[%d] is not an object" % i)
    for key in ("id", "proposed_rule", "target_file"):
        if not p.get(key):
            fail("rule_proposals[%d] lacks '%s'" % (i, key))
    st = p.get("status", "pending")
    if not isinstance(st, str) or st not in ("pending", "promoted", "rejected"):
        fail("rule_proposals[%d].status '%s' is not pending, promoted or rejected" % (i, st))

if not os.path.isfile(mpath) or os.path.getsize(mpath) == 0:
    fail("%s.synthesis.md is missing or empty" % week)

store = os.path.join(syn, "facts.jsonl.next")
if not os.path.isfile(store):
    store = os.path.join(syn, "facts.jsonl")
if not os.path.isfile(store):
    fail("no fact store (facts.jsonl.next or facts.jsonl)")
with open(store, encoding="utf-8") as fh:
    for n, line in enumerate(fh, 1):
        if not line.strip():
            continue
        try:
            rec = json.loads(line)
        except ValueError:
            fail("%s line %d is not JSON" % (os.path.basename(store), n))
        if not isinstance(rec, dict) or "id" not in rec or "claim" not in rec:
            fail("%s line %d lacks id or claim" % (os.path.basename(store), n))

open_c = [c for c in data["contradictions"] if c.get("status", "open") == "open"]
pend_p = [p for p in data["rule_proposals"] if p.get("status", "pending") == "pending"]

print("Synthesize %s (%s): success. logs=%d facts_added=%d contradictions=%d "
      "rule_proposals=%d. Report: [[%s.synthesis]]."
      % (week, mode, len(data["logs_read"]), len(data["facts_added"]),
         len(open_c), len(pend_p), week))
for c in open_c:
    print("Synthesis contradiction (%s): %s vs %s: %s. Resolve in a Synthesizer session."
          % (week, c["facts"][0], c["facts"][1], collapse(c.get("summary", ""))))
for p in pend_p:
    print("Synthesis proposal %s (%s) for %s: %s. Approve: /graduate as Architect. "
          "Reject: tell a Synthesizer session \"reject %s\"."
          % (p["id"], week, p["target_file"], collapse(p["proposed_rule"]), p["id"]))
PY
}

cmd_scope() {
  local sid="" head=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --session-id) [[ $# -ge 2 ]] || die3 "--session-id needs a value"; sid="$2"; shift 2 ;;
      --head) [[ $# -ge 2 ]] || die3 "--head needs a value"; head="$2"; shift 2 ;;
      *) die3 "unknown arg: $1" ;;
    esac
  done
  [[ -n "$sid" ]] || die3 "missing --session-id"
  need_python
  local safe="${sid//[^A-Za-z0-9._-]/_}"
  local marker=".session_state.$safe.json"
  [[ -f "$VAULT_DIR/$marker" ]] || die1 "session marker $marker not found"

  local cur=""
  if [[ -n "$head" ]]; then
    cur="$(git -C "$VAULT_DIR" rev-parse HEAD 2>/dev/null || true)"
    [[ -n "$cur" ]] || cur="unknown"
  fi

  python3 -I - "$VAULT_DIR" "$marker" "$head" "$cur" <<'PY'
import sys, os

vault, marker, old_head, new_head = sys.argv[1:5]
ref = os.lstat(os.path.join(vault, marker)).st_mtime_ns
prune = {".git", ".obsidian", ".claude"}
allowed = ("03_Brain/Weekly_Synthesis", "04_Logs")
bad = []

def allowed_path(rel):
    if rel == marker:
        return True
    return any(rel == a or rel.startswith(a + "/") for a in allowed)

for root, dirs, files in os.walk(vault, followlinks=False):
    dirs[:] = [d for d in dirs if d not in prune]
    for name in dirs + files:
        if name == ".DS_Store":
            continue
        full = os.path.join(root, name)
        try:
            mt = os.lstat(full).st_mtime_ns
        except OSError:
            continue
        if mt <= ref:
            continue
        rel = os.path.relpath(full, vault)
        if not allowed_path(rel):
            bad.append("OUT_OF_SCOPE: " + rel)

bad.sort()
if old_head and old_head != new_head:
    bad.append("OUT_OF_SCOPE: git HEAD moved %s -> %s" % (old_head, new_head))
if bad:
    print("\n".join(bad))
    sys.exit(4)
print("SCOPE: clean")
PY
}

[[ $# -ge 1 ]] || { usage >&2; die3 "missing subcommand"; }
sub="$1"; shift
case "$sub" in
  week)    cmd_week "$@" ;;
  plan)    cmd_plan "$@" ;;
  report)  cmd_report "$@" ;;
  scope)   cmd_scope "$@" ;;
  -h|--help) usage ;;
  *) usage >&2; die3 "unknown subcommand: $sub" ;;
esac

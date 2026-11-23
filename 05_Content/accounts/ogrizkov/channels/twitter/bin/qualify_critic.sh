#!/usr/bin/env bash
# qualify_critic.sh — probe choice, probe evaluation and critic qualification (v3.2, E5/E20).
#
# Usage:
#   qualify_critic.sh --pick --slot SLOT_ID
#       prints the ids of the probes_per_call probes for one critic call: one must-fail and one
#       must-ship; the must-fail one rotates with the slot (derived from the slot id, no state file).
#   qualify_critic.sh --evaluate CRITIC_OUTPUT_JSON --model NAME [--probes ID,ID] [--labelled F] [--record]
#       offline. --probes (per critic call: the ids --pick printed) requires every listed probe in the
#       output; a missing one fails the call. For every probe present (matched by its draft text), each criterion
#       in expect_fail must have verdict fail and the overall verdict must not be SHIP; a SHIP probe
#       must have verdict SHIP. With --labelled, the critic must also agree with his marks on
#       marks_agree of marks_needed items. --record writes pass/fail to runs/_index/critic_qualified.json;
#       a recorded failure raises an alarm line (slot_state.py alarm), never an email.
# The full probe set runs in the weekly qualification, after delivery.
# Exit: 0 calibrated, 1 not, 2 usage.
set -uo pipefail
BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
C="$(cd "$BIN/.." && pwd -P)"
export QC_PROBES="${PIPELINE_PROBES:-$C/tests/critic_probes.json}"
export QC_PARAMS="${PIPELINE_PARAMS:-$C/agents/params.json}"
export QC_LADDER="$C/agents/critic_ladder.json"
export QC_STATE="${PIPELINE_STATE_DIR:-$C/runs/_index}"
export QC_BIN="$BIN"

python3 - "$@" <<'PY'
import argparse, datetime as dt, json, os, re, subprocess, sys

def load(p):
    try:
        return json.load(open(p))
    except (OSError, ValueError) as e:
        print(f"cannot read {p}: {e}", file=sys.stderr)
        sys.exit(2)

ap = argparse.ArgumentParser(add_help=False)
ap.add_argument("--pick", action="store_true")
ap.add_argument("--slot")
ap.add_argument("--evaluate")
ap.add_argument("--model")
ap.add_argument("--labelled")
ap.add_argument("--record", action="store_true")
ap.add_argument("--probes", action="append", default=[])
try:
    a = ap.parse_args()
except SystemExit:
    sys.exit(2)
probes = load(os.environ["QC_PROBES"])["probes"]
params = load(os.environ["QC_PARAMS"])

if a.pick:
    m = re.match(r"^(\d{4}-\d{2}-\d{2})_(\d{2})(\d{2})", a.slot or "")
    if not m:
        print("--pick needs --slot YYYY-MM-DD_HHMM", file=sys.stderr); sys.exit(2)
    starts = sorted(s for slot in params["slots"] for s in slot["starts"])
    hhmm = f"{m.group(2)}:{m.group(3)}"
    idx = starts.index(hhmm) if hhmm in starts else 0
    turn = dt.date.fromisoformat(m.group(1)).toordinal() * len(starts) + idx
    fail = [p for p in probes if p["expect"] == "FIX"]
    ship = [p for p in probes if p["expect"] == "SHIP"]
    if not fail or not ship:
        print("probe set needs one must-fail and one must-ship probe", file=sys.stderr); sys.exit(2)
    picks = [fail[turn % len(fail)]["id"], ship[turn % len(ship)]["id"]]
    extra = params.get("probes_per_call", 2) - 2
    rest = [p["id"] for p in fail if p["id"] not in picks]
    picks += rest[turn % max(len(rest), 1):][:max(extra, 0)]
    print("\n".join(picks)); sys.exit(0)

if not a.evaluate or not a.model:
    print("usage: --pick --slot ID | --evaluate FILE --model NAME [--probes ID,ID] [--labelled F] [--record]", file=sys.stderr); sys.exit(2)
picked = [i for arg in a.probes for i in re.split(r"[,\s]+", arg) if i]
unknown = [i for i in picked if i not in {p["id"] for p in probes}]
if unknown:
    print(f"unknown probe id(s): {', '.join(unknown)}", file=sys.stderr); sys.exit(2)

out = load(a.evaluate)
results = out.get("results", out if isinstance(out, list) else [])
squash = lambda s: re.sub(r"\s+", " ", s or "").strip()
by_draft = {squash(r.get("draft") or r.get("DRAFT")): r for r in results}
problems, seen = [], 0
for p in probes:
    r = by_draft.get(squash(p["draft"]))
    if not r:
        if p["id"] in picked:
            problems.append(f"{p['id']}: picked probe missing from the critic output")
        continue
    seen += 1
    verdict = str(r.get("critic_verdict") or r.get("verdict") or "").upper()
    crit = {c.get("criterion"): str(c.get("verdict", "")).lower() for c in r.get("criteria") or []}
    if p["expect"] == "SHIP":
        if verdict != "SHIP":
            problems.append(f"{p['id']}: must SHIP, got {verdict or 'none'}")
        continue
    if verdict == "SHIP":
        problems.append(f"{p['id']}: must not SHIP")
    for c in p["expect_fail"]:
        if not crit.get(c, "").startswith("fail"):
            problems.append(f"{p['id']}: {c} must fail, got {crit.get(c) or 'none'}")
if seen == 0:
    problems.append("no probe found in the critic output")

agree_line = ""
if a.labelled:
    lab = load(a.labelled)
    items = lab.get("items", lab if isinstance(lab, list) else [])
    need, bar = params["trial"]["marks_needed"], params["trial"]["marks_agree"]
    agree = 0
    for it in items[:need]:
        r = by_draft.get(squash(it.get("draft")))
        v = str((r or {}).get("critic_verdict") or "").upper()
        if r and (v == "SHIP") == (it.get("mark") == "would_post"):
            agree += 1
    agree_line = f"labelled agreement {agree}/{min(len(items), need)} (bar {bar})"
    if len(items) < need or agree < bar:
        problems.append(agree_line)

ok = not problems
print(json.dumps({"model": a.model, "probes_checked": seen, "calibrated": ok, "problems": problems,
                  "labelled": agree_line or None}, indent=2))
if a.record:
    key = a.model
    for r in load(os.environ["QC_LADDER"])["rungs"]:
        if a.model in (r["cli_name"], r["telemetry_id"]):
            key = r["telemetry_id"]
    path = os.path.join(os.environ["QC_STATE"], "critic_qualified.json")
    try:
        q = json.load(open(path))
    except (OSError, ValueError):
        q = {}
    v = os.environ.get("PIPELINE_NOW")
    at = (dt.datetime.fromisoformat(v.replace("Z", "+00:00")) if v else dt.datetime.now(dt.timezone.utc))
    q[key] = {"result": "pass" if ok else "fail", "at": at.astimezone(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
              "problems": problems}
    os.makedirs(os.path.dirname(path), exist_ok=True)
    json.dump(q, open(path, "w"), indent=2)
    if not ok:
        subprocess.run([sys.executable, os.path.join(os.environ["QC_BIN"], "slot_state.py"), "alarm",
                        "--reason", "critic_qualification", "--text",
                        f"critic {key} failed the weekly qualification: {'; '.join(problems)[:200]}"],
                       capture_output=True)
sys.exit(0 if ok else 1)
PY

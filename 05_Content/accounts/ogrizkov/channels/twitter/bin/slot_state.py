#!/usr/bin/env python3
"""slot_state.py - slot identity, delivery ledger, posting recommendation, stages, slot log,
alarms and the status view of the @ogrizkov reply pipeline (v3.2).

Subcommands:
  slot-id [--slot HH:MM]
  budget (--posted-today N [--partial] | --posted-today-unknown) [--slot HH:MM]
  set-stage 2|3 --reason T
  record --slot ID --replies FILE
  log --slot ID --reason R [--funnel JSON] [--minutes-to-sent N] [--grok-calls N --grok-ok BOOL] ...
  grok-call --slot ID --purpose probe|discovery|widen|read|maintenance [--batch B]
  grok-result --slot ID --purpose P --ok true|false
  health
  alarm --reason R --text T
  status [--line]
  history --days N [--urls]
  set-mode --slot HH:MM trial|live
  pause --days N --reason R
  trial-report

Exit: 0 ok, 1 refused / deduplicated / not met, 2 usage or config, 3 no slot window.
grok-call spends one grok call from the budget before the call is made: probe, discovery, widen and
read count against cost.max_grok_calls per slot (all attempts together), maintenance against
cost.maintenance_grok_calls per slot, every call against cost.max_grok_calls_day. Exit 1 when the
budget is at 0, and for a discovery in a second batch of a slot that already ran discovery (that
attempt reuses the first batch's 00_candidates.json); the refusal is kept and shown in the slot log.
grok-result records how a spent call ended, with its time; a good result (the preflight probe too)
means no probe is spent again in that slot until a later grok call of the slot fails.
Delivery never depends on the posting recommendation; nothing here sends email.
"""
import argparse
import datetime as dt
import json
import os
import re
import statistics
import subprocess
import sys
from pathlib import Path
from zoneinfo import ZoneInfo

BIN = Path(__file__).resolve().parent
C = BIN.parent
VAULT = C.parents[4]
REASONS = {"delivered", "no_pass", "locked", "guard", "preflight_failed", "grok_balance", "grok_budget",
           "delivery_failed", "infra", "outside_slot", "missed"}
REASON_WORDS = {"no_pass": "nothing passed", "delivery_failed": "mail not delivered",
                "preflight_failed": "preflight", "grok_balance": "grok balance", "grok_budget": "grok budget used up",
                "outside_slot": "outside slot"}
RUN_PURPOSES = ("probe", "discovery", "widen", "read")


# ---------- paths, params, time -------------------------------------------
def env_path(name, default):
    return Path(os.environ.get(name) or default)


STATE = env_path("PIPELINE_STATE_DIR", C / "runs" / "_index")
ANALYTICS = env_path("PIPELINE_ANALYTICS_DIR", C / "runs" / "_analytics")
STATUS_FILE = env_path("PIPELINE_STATUS_FILE", C / "STATUS.md")
PARAMS_FILE = env_path("PIPELINE_PARAMS", C / "agents" / "params.json")
AUTHORITY = C / "project_authority.md"


def die(msg, code=2):
    print(msg, file=sys.stderr)
    sys.exit(code)


def load_params():
    try:
        return json.loads(PARAMS_FILE.read_text())
    except (OSError, ValueError) as e:
        die(f"params unreadable: {PARAMS_FILE}: {e}")


P = load_params()
TZ = ZoneInfo(P["timezone"])


def now_utc():
    v = os.environ.get("PIPELINE_NOW")
    if not v:
        return dt.datetime.now(dt.timezone.utc)
    t = dt.datetime.fromisoformat(v.replace("Z", "+00:00"))
    return (t if t.tzinfo else t.replace(tzinfo=dt.timezone.utc)).astimezone(dt.timezone.utc)


def local(t):
    return t.astimezone(TZ)


def iso(t):
    return t.astimezone(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def parse_ts(s):
    if not s:
        return None
    try:
        t = dt.datetime.fromisoformat(str(s).replace("Z", "+00:00"))
    except ValueError:
        return None
    return t if t.tzinfo else t.replace(tzinfo=dt.timezone.utc)


def today_local():
    return local(now_utc()).date()


# ---------- json helpers ----------------------------------------------------
def read_json(path, default):
    try:
        return json.loads(Path(path).read_text())
    except (OSError, ValueError):
        return default


def write_json(path, obj):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(obj, indent=2, ensure_ascii=False) + "\n")
    tmp.replace(path)


def read_jsonl(path):
    rows = []
    try:
        for line in Path(path).read_text().splitlines():
            line = line.strip()
            if line:
                try:
                    rows.append(json.loads(line))
                except ValueError:
                    pass
    except OSError:
        pass
    return rows


def append_jsonl(path, row):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a") as f:
        f.write(json.dumps(row, ensure_ascii=False) + "\n")


def state_file(name):
    return STATE / name


def delivery_state():
    return read_json(state_file("delivery_state.json"), {})


def save_delivery_state(s):
    write_json(state_file("delivery_state.json"), s)


def ledger():
    return read_jsonl(state_file("delivered.jsonl"))


def slot_log():
    return read_jsonl(state_file("scheduler_log.jsonl"))


def reply_log():
    return read_jsonl(ANALYTICS / "reply_log.jsonl")


# ---------- slots -----------------------------------------------------------
def all_starts():
    out = []
    for i, s in enumerate(P["slots"]):
        for st in s["starts"]:
            out.append((st, i))
    return sorted(out)


def slot_for_start(hhmm):
    for st, i in all_starts():
        if st == hhmm:
            return P["slots"][i]
    return None


def at_local(day, hhmm):
    h, m = map(int, hhmm.split(":"))
    return dt.datetime(day.year, day.month, day.day, h, m, tzinfo=TZ)


def slot_id_of(day, hhmm):
    return f"{day.isoformat()}_{hhmm.replace(':', '')}"


def parse_slot_id(slot_id):
    m = re.match(r"^(\d{4}-\d{2}-\d{2})_(\d{2})(\d{2})", slot_id or "")
    if not m:
        die(f"bad slot id: {slot_id}")
    return dt.date.fromisoformat(m.group(1)), f"{m.group(2)}:{m.group(3)}"


def current_slot_id(override=None):
    t = local(now_utc())
    if override:
        if not slot_for_start(override):
            die(f"no configured start {override}")
        return slot_id_of(t.date(), override)
    grace = dt.timedelta(minutes=P["slot_grace_min"])
    best = None
    for st, _ in all_starts():
        start = at_local(t.date(), st)
        if start <= t < start + grace and (best is None or start > best[0]):
            best = (start, st)
    return slot_id_of(t.date(), best[1]) if best else None


def slot_window(slot_id):
    day, hhmm = parse_slot_id(slot_id)
    s = slot_for_start(hhmm)
    if not s:
        die(f"slot id {slot_id} has no configured start")
    return at_local(day, s["window"][0]), at_local(day, s["window"][1])


def expected_slots_between(first, last):
    """Slot ids whose start lies in [first, last] (local datetimes)."""
    out = []
    day = first.date()
    while day <= last.date():
        for st, _ in all_starts():
            start = at_local(day, st)
            if first <= start <= last:
                out.append(slot_id_of(day, st))
        day += dt.timedelta(days=1)
    return out


# ---------- authority reuse -------------------------------------------------
def reuse_days():
    days, cur = {}, None
    try:
        text = AUTHORITY.read_text()
    except OSError:
        return days
    for line in text.splitlines():
        m = re.match(r"^###\s+([A-Z]{2,4}-\d+)\b", line)
        if m:
            cur = m.group(1)
            continue
        m = re.match(r"^-\s*reuse:\s*(\d+)d", line)
        if m and cur:
            days[cur] = int(m.group(1))
    return days


# ---------- posting counts ----------------------------------------------------
def posted_counts():
    return read_json(state_file("posted_counts.json"), {})


def avg_last_7(day):
    days = posted_counts().get("days", {})
    tot = sum(int(days.get((day - dt.timedelta(days=i)).isoformat(), 0) or 0) for i in range(1, 8))
    return tot / 7.0


def pipeline_rows(rows=None):
    rows = reply_log() if rows is None else rows
    seen, out = set(), []
    for r in rows:
        if r.get("arm") != "pipeline" or r.get("reply_url") in seen:
            continue
        seen.add(r.get("reply_url"))
        out.append(r)
    return out


def local_date_of(ts):
    t = parse_ts(ts)
    return local(t).date() if t else None


def pipeline_posted_on(day):
    return sum(1 for r in pipeline_rows() if local_date_of(r.get("posted_at")) == day)


# ---------- stages ------------------------------------------------------------
def stage_of(s):
    return int(s.get("stage") or 1)


def stage_params(n):
    st = P["volume"]["stages"]
    return st[max(1, min(n, len(st))) - 1]


def posting_days_in_stage(s):
    # After a tripwire or label restart, days posted inside the pause do not count.
    since = parse_ts(s.get("stage_set_at"))
    floor = s.get("stage_days_from")
    floor = dt.date.fromisoformat(floor) if floor else None
    days = set()
    for r in pipeline_rows():
        t = parse_ts(r.get("posted_at"))
        if t and (since is None or t >= since) and (floor is None or local(t).date() >= floor):
            days.add(local(t).date())
    return sorted(days)


def tripwire_since(s):
    # Strictly after: apply_pause stores the tripwire and the stage-1 restart with the same
    # whole-second stamp, and that tripwire belongs to the stage it ended, not to the restart.
    since = parse_ts(s.get("stage_set_at"))
    for t in s.get("tripwires", []):
        tt = parse_ts(t)
        if tt and (since is None or tt > since):
            return True
    return False


def latest_period_verdict():
    files = sorted(ANALYTICS.glob("period_*.md"))
    if not files:
        return None
    m = re.search(r"^Verdict:\s*([a-z][a-z ]*?)[:.]", files[-1].read_text(), re.M)
    return m.group(1).strip() if m else None


def latest_monthly_label_free():
    files = sorted((ANALYTICS / "under_the_hood").glob("*.json"))
    if not files:
        return False
    d = read_json(files[-1], None)
    if not isinstance(d, dict):
        return False
    if "accountLabels" not in d or "postLabels" not in d:
        return False  # absent keys do not prove the account is label-free
    return not d["accountLabels"] and not d["postLabels"]


def stage_check(s, target):
    """Return (ok, reason) for opening stage `target` from the current state."""
    if target == 2:
        n = len(posting_days_in_stage(s))
        need = P["volume"]["stage2_posting_days"]
        if tripwire_since(s):
            return False, "a tripwire fired in this stage"
        if n < need:
            return False, f"posted pipeline items on {n} days in stage 1; {need} needed"
        return True, "ok"
    if target == 3:
        if latest_period_verdict() != "raise":
            return False, "the newest period report has no 'raise' verdict"
        if not latest_monthly_label_free():
            return False, "the newest monthly X report is missing or shows a label"
        return True, "ok"
    return False, f"no stage {target}"


def stage_started(s):
    days = posting_days_in_stage(s)
    return days[0].isoformat() if days else None


# ---------- budget ------------------------------------------------------------
def paused(s, day):
    pu = s.get("paused_until")
    return bool(pu) and day < dt.date.fromisoformat(pu)


def pause_reason_text(s):
    if s.get("pause_reason") == "tripwire":
        t = P["tripwire"]
        return (f"tripwire: the last {t['run_length']} posted replies had {t['max_views']} views or fewer "
                f"at {t['at_hours']} hours; back on {s.get('paused_until')}")
    return f"paused: {s.get('pause_reason')}; back on {s.get('paused_until')}"


def recommended_today(day):
    rows = [r for r in ledger() if r.get("recommended") and local_date_of(r.get("delivered_at")) == day]
    return {"authors": sorted({r.get("author") for r in rows if r.get("author")}),
            "deep": sum(1 for r in rows if r.get("reply_type") == "deep"),
            "large": sum(1 for r in rows if str(r.get("tier")) == "3")}


def resting_entries(now):
    reuse = reuse_days()
    led = ledger()
    by_item = {r.get("item_id"): r for r in led}
    posted_items = set()
    rest = set()
    for r in reply_log():
        item = by_item.get(r.get("item_id"))
        if not item:
            continue
        posted_items.add(item.get("item_id"))
        entry = item.get("ground_with")
        t = parse_ts(r.get("posted_at"))
        if entry and t and now - t < dt.timedelta(days=reuse.get(entry, 30)):
            rest.add(entry)
    for item in led:
        t = parse_ts(item.get("delivered_at"))
        if (item.get("ground_with") and item.get("item_id") not in posted_items
                and t and now - t < dt.timedelta(hours=48)):
            rest.add(item["ground_with"])
    return sorted(rest)


def hooks_recent():
    n = P["hooks"]["rotation_window"]
    return [r.get("hook") for r in ledger()[-n:] if r.get("hook")] if n else []


def grok_probe_needed(slot_id=None):
    """The slot's own grok results decide first: after a recorded good call (the probe included) no
    probe is spent again in that slot, unless a later grok call of the slot failed. Otherwise the
    last slot-log line with a grok call decides."""
    results = [r for r in grok_rows() if r.get("slot_id") == slot_id and r.get("result")] if slot_id else []
    if results:
        return results[-1]["result"] != "ok"
    for line in reversed(slot_log()):
        if line.get("grok_calls") or line.get("grok_ok") is not None:
            return line.get("grok_ok") is not True
    return True


def attempts_left_today(day):
    used = sum(int(l.get("attempts") or 0) for l in slot_log()
               if l.get("slot_id", "").startswith(day.isoformat()))
    return max(0, P["cost"]["attempts_per_day"] - used)


def posting_recommendation(s, day, posted, known):
    st = stage_params(stage_of(s))
    allowance = int(min(st["all_replies_per_day"], avg_last_7(day) + P["volume"]["allowance_avg_plus"]))
    today_more = max(0, allowance - (posted or 0)) if known != "unknown" else None
    pipe_left = max(0, st["pipeline_per_day"] - pipeline_posted_on(day))
    cand = [st["post_per_run"], pipe_left] + ([today_more] if today_more is not None else [allowance])
    post_today = max(0, min(cand))
    reason = f"stage {stage_of(s)}: up to {st['post_per_run']} per run, {st['pipeline_per_day']} pipeline items a day"
    if known in ("partial", "unknown"):
        post_today = min(post_today, 1)
        reason = f"his reply count today is {'partial' if known == 'partial' else 'unknown'}; at most 1"
    if today_more == 0:
        post_today, reason = 0, f"you already posted {posted} replies today"
    elif pipe_left == 0:
        post_today, reason = 0, f"the {st['pipeline_per_day']} pipeline items of today are posted"
    if paused(s, day):
        post_today, reason = 0, pause_reason_text(s)
    if known in ("partial", "unknown"):
        today_line = f"stay within {allowance} replies in total today"
    else:
        today_line = str(today_more)
    return allowance, today_more, post_today, reason, today_line


# ---------- grok budget --------------------------------------------------------------
def grok_rows():
    return read_jsonl(state_file("grok_calls.jsonl"))


def grok_left(slot_id, day):
    """(left in this slot's run budget, left in the maintenance budget, left today)."""
    spent = [r for r in grok_rows() if not r.get("refused") and not r.get("result")]
    run = sum(1 for r in spent if r.get("slot_id") == slot_id and r.get("purpose") in RUN_PURPOSES)
    maint = sum(1 for r in spent if r.get("slot_id") == slot_id and r.get("purpose") == "maintenance")
    today = sum(1 for r in spent if local_date_of(r.get("ts")) == day)
    left_day = max(0, P["cost"]["max_grok_calls_day"] - today)
    return (min(max(0, P["cost"]["max_grok_calls"] - run), left_day),
            min(max(0, P["cost"]["maintenance_grok_calls"] - maint), left_day), left_day)


def discovery_batch(slot_id):
    return next((r.get("batch") for r in grok_rows() if r.get("slot_id") == slot_id and r.get("purpose") == "discovery"
                 and not r.get("refused") and not r.get("result")), None)


def cmd_grok_result(a):
    """Record how a spent grok call ended (run_traced.sh and preflight.sh call this after the call)."""
    if str(a.ok).lower() not in ("true", "false"):
        die("--ok needs true or false")
    ok = to_bool(a.ok)
    append_jsonl(state_file("grok_calls.jsonl"), {"ts": iso(now_utc()), "slot_id": a.slot, "purpose": a.purpose,
                                                 "result": "ok" if ok else "failed"})
    print(json.dumps({"slot_id": a.slot, "purpose": a.purpose, "result": "ok" if ok else "failed",
                      "probe_needed_next": grok_probe_needed(a.slot)}))


def cmd_grok_call(a):
    day = local(now_utc()).date()
    left_run, left_maint, left_day = grok_left(a.slot, day)
    left = left_maint if a.purpose == "maintenance" else left_run
    first = discovery_batch(a.slot)
    why = None
    if a.purpose == "discovery" and first and a.batch and first != a.batch:
        why = f"discovery already ran in {first} for this slot: reuse runs/{first}/00_candidates.json"
    elif left <= 0:
        scope = "today" if left_day <= 0 else ("maintenance" if a.purpose == "maintenance" else "run")
        why = f"grok budget at 0 ({scope}): no {a.purpose} call"
    row = {"ts": iso(now_utc()), "slot_id": a.slot, "purpose": a.purpose, "batch": a.batch}
    if why:
        append_jsonl(state_file("grok_calls.jsonl"), dict(row, refused=why))
        print(why, file=sys.stderr)
        sys.exit(1)
    append_jsonl(state_file("grok_calls.jsonl"), row)
    print(json.dumps({"ok": True, "purpose": a.purpose, "grok_calls_left_run": left_run - (a.purpose != "maintenance"),
                      "grok_calls_left_today": left_day - 1}))


def cmd_budget(a):
    sid = current_slot_id(a.slot)
    if not sid:
        die("no slot window now", 3)
    now = now_utc()
    day = local(now).date()
    s = delivery_state()
    known = "unknown" if a.posted_today_unknown else ("partial" if a.partial else "full")
    posted = None if a.posted_today_unknown else a.posted_today
    allowance, today_more, post_today, reason, today_line = posting_recommendation(s, day, posted, known)
    stage = stage_of(s)
    ready = stage < 3 and stage_check(s, stage + 1)[0]
    grok = grok_left(sid, day)
    w0, w1 = slot_window(sid)
    cutoff = w0 - dt.timedelta(minutes=P["timing"]["send_margin_min"])
    _, hhmm = parse_slot_id(sid)
    caps = dict(P["cost"])
    caps["bind_max"] = P["volume"]["deliver_per_run"] + P["cost"]["bind_extra"]
    caps["attempts_left_today"] = attempts_left_today(day)
    out = {
        "slot_id": sid, "mode": s.get("modes", {}).get(hhmm, "trial"), "stage": stage,
        "stage_ready": ready, "stage_started": stage_started(s), "stage_note": s.get("stage_note") or "",
        "paused_until": s.get("paused_until"), "pause_reason": s.get("pause_reason"),
        "allowance_today": allowance, "posted_today": posted, "count": known,
        "today_more": today_more, "today_line": today_line, "post_today": post_today, "post_reason": reason,
        "deliver_cap": P["volume"]["deliver_per_run"], "recommended_today": recommended_today(day),
        "urls_delivered": sorted({r.get("url") for r in ledger() if r.get("url")}),
        "resting_entries": resting_entries(now), "hooks_recent": hooks_recent(),
        "window": [w0.strftime("%H:%M"), w1.strftime("%H:%M")], "window_end_utc": iso(w1),
        "send_cutoff": cutoff.strftime("%H:%M"), "send_cutoff_utc": iso(cutoff),
        "grok_probe_needed": grok_probe_needed(sid), "status_line": status_line(),
        "capture": P["capture"], "ranking": P["ranking"], "tiers": P["tiers"],
        "volume": {k: P["volume"][k] for k in ("author_per_day", "deep_per_day")},
        "large_per_day": stage_params(stage)["large_per_day"], "caps": caps,
        "grok_calls_left_run": grok[0], "grok_calls_left_today": grok[2],
        "grok_discovery_batch": discovery_batch(sid),
    }
    print(json.dumps(out, indent=2, ensure_ascii=False))


# ---------- set-stage / set-mode / pause ------------------------------------------
def set_stage(s, n, note):
    s["stage"] = n
    s["stage_set_at"] = iso(now_utc())
    s["stage_started"] = None
    s["stage_days_from"] = None
    s["stage_note"] = note


def cmd_set_stage(a):
    s = delivery_state()
    cur = stage_of(s)
    if a.stage != cur + 1:
        die(f"refused: stage {cur} can only move to stage {cur + 1}", 1)
    ok, why = stage_check(s, a.stage)
    if not ok:
        die(f"refused: {why}", 1)
    set_stage(s, a.stage, f"Stage {a.stage} from today: {a.reason}")
    save_delivery_state(s)
    print(json.dumps({"stage": a.stage, "stage_note": s["stage_note"]}))


def pinned_post_url():
    try:
        text = (ANALYTICS / "weekly.md").read_text()
    except OSError:
        return ""
    m = re.search(r"^pinned_post_url:[ \t]*(\S*)", text, re.M)
    return m.group(1) if m else ""


def cmd_set_mode(a):
    if not slot_for_start(a.slot):
        die(f"no configured start {a.slot}")
    if a.mode == "live" and not pinned_post_url().startswith("http"):
        die("refused: runs/_analytics/weekly.md has no pinned_post_url (post the new pinned post first)", 1)
    s = delivery_state()
    s.setdefault("modes", {})[a.slot] = a.mode
    if a.mode == "live" and not s.get("live_since"):
        s["live_since"] = today_local().isoformat()
    save_delivery_state(s)
    print(json.dumps({"slot": a.slot, "mode": a.mode}))


def apply_pause(s, days, reason, back_to_stage1):
    until = today_local() + dt.timedelta(days=days)
    s["paused_until"] = until.isoformat()
    s["pause_reason"] = reason
    if back_to_stage1:
        s.setdefault("tripwires", []).append(iso(now_utc()))
        set_stage(s, 1, f"Stage 1 again: {reason} pause until {until.isoformat()}")
        s["stage_days_from"] = until.isoformat()
    return s


def cmd_pause(a):
    s = apply_pause(delivery_state(), a.days, a.reason, a.reason in ("tripwire", "label"))
    save_delivery_state(s)
    print(json.dumps({"paused_until": s["paused_until"], "pause_reason": a.reason, "stage": stage_of(s)}))


# ---------- record ------------------------------------------------------------------
def parse_items(md):
    head = re.split(r"^## (?:Skipped|Quarantined)\b", md, maxsplit=1, flags=re.M)[0]
    items = []
    for block in re.split(r"^### ", head, flags=re.M)[1:]:
        lines = block.splitlines()
        m = re.match(r"(\d+)\.\s+(https://\S+)", lines[0])
        if not m:
            continue
        it = {"n": int(m.group(1)), "url": m.group(2)}
        for l in lines[1:]:
            fm = re.match(r"-\s+([A-Za-z_]+):\s*(.*)", l)
            if fm:
                it[fm.group(1)] = fm.group(2).strip()
        items.append(it)
    return items


def anchored_by_url(run_dir):
    a = read_json(Path(run_dir) / "01_anchored.json", {})
    return {t.get("url"): t for t in a.get("targets", []) or []}


def to_int(v):
    try:
        return int(str(v).replace(",", ""))
    except (TypeError, ValueError):
        return None


def ledger_row(slot, it, t, mode, now):
    hook = (it.get("HOOK") or "").split("·")[0].strip()
    post_time = parse_ts(it.get("posted_at") or t.get("posted_at"))
    _, w1 = slot_window(slot)
    limits = [now + dt.timedelta(minutes=P["timing"]["post_within_min"]), w1]
    if post_time:
        limits.append(post_time + dt.timedelta(minutes=P["timing"]["land_within_min"]))
    return {
        "item_id": f"{slot}#{it['n']}", "slot_id": slot, "url": it["url"],
        "reply_to_url": t.get("reply_to_url") or it["url"], "author": it.get("author") or t.get("author"),
        "author_followers": to_int(it.get("followers")) or t.get("author_followers"),
        "tier": to_int(it.get("tier")) or t.get("tier"), "recommended": it.get("mark") == "recommended",
        "reply_type": it.get("type") or t.get("reply_type"), "claim_origin": it.get("claim") or t.get("claim_origin"),
        "zone": t.get("zone"), "move": t.get("move"), "ground_with": t.get("ground_with"),
        "hook": hook, "starter": it.get("DRAFT"), "point": it.get("POINT"),
        "question_form": (it.get("DRAFT") or "").rstrip().endswith("?"),
        "posted_at": it.get("posted_at") or t.get("posted_at"),
        "age_min_at_capture": to_int(it.get("age_min")) or t.get("age_min_at_capture"),
        "parent_views_at_capture": to_int(it.get("views")) or t.get("parent_views_at_capture"),
        "momentum": bool(t.get("momentum")), "replies_at_capture": (t.get("engagement") or {}).get("replies"),
        "delivered_at": iso(now), "mode": mode, "post_by": iso(min(limits)),
    }


def cmd_record(a):
    if any(r.get("slot_id") == a.slot for r in ledger()):
        print(json.dumps({"slot": a.slot, "recorded": 0, "note": "already recorded"}))
        return
    path = Path(a.replies)
    try:
        md = path.read_text()
    except OSError as e:
        die(f"cannot read {path}: {e}")
    mode = (re.search(r"^mode:\s*(\w+)", md, re.M) or [None, "trial"])[1]
    anch = anchored_by_url(path.parent)
    now = now_utc()
    rows = [ledger_row(a.slot, it, anch.get(it["url"], {}), mode, now) for it in parse_items(md)]
    for r in rows:
        append_jsonl(state_file("delivered.jsonl"), r)
    s = delivery_state()
    if s.get("stage_note"):
        s["stage_note"] = ""
        save_delivery_state(s)
    print(json.dumps({"slot": a.slot, "recorded": len(rows)}))


# ---------- log / health / alarm -------------------------------------------------------
def to_bool(v):
    if v is None:
        return None
    return str(v).lower() in ("1", "true", "yes", "y")


def write_missed_lines():
    lines = slot_log()
    if not lines:
        return []
    first = min(parse_ts(l.get("ts")) for l in lines if parse_ts(l.get("ts")))
    now = local(now_utc())
    grace = dt.timedelta(minutes=P["slot_grace_min"])
    seen = {l.get("slot_id") for l in lines}
    missed = []
    for sid in expected_slots_between(local(first) - dt.timedelta(minutes=1), now):
        day, hhmm = parse_slot_id(sid)
        if sid not in seen and at_local(day, hhmm) + grace < now:
            missed.append(sid)
            append_jsonl(state_file("scheduler_log.jsonl"), {
                "ts": iso(now_utc()), "slot_id": sid, "reason": "missed",
                "detail": "no run reached this slot (Mac asleep, task off or session failed)"})
    return missed


def slot_outcomes():
    """Last outcome per slot id, in slot order; a delivered line wins."""
    out = {}
    for l in slot_log():
        sid = l.get("slot_id")
        if not sid:
            continue
        if out.get(sid) == "delivered":
            continue
        out[sid] = l.get("reason")
    return dict(sorted(out.items()))


def health():
    missed = write_missed_lines()
    outcomes = list(slot_outcomes().items())[-P["alarm"]["window_runs"]:]
    bad = [(s, r) for s, r in outcomes if r != "delivered"]
    by_reason = {}
    for _, r in bad:
        by_reason[r] = by_reason.get(r, 0) + 1
    any_missed = any(r == "missed" for _, r in bad)
    alarm = len(bad) > P["alarm"]["max_empty"] or any_missed
    text = ""
    if alarm:
        parts = ", ".join(f"{REASON_WORDS.get(k, k)} {v}" for k, v in sorted(by_reason.items()))
        text = f"{len(bad)} of the last {len(outcomes)} slots without mail ({parts})"
    return {"missed_slots": missed, "non_delivered_in_window": by_reason, "window_slots": len(outcomes),
            "alarm": alarm, "alarm_reason": "missed" if any_missed else ("non_delivery" if alarm else None),
            "alarm_text": text}


def cmd_health(a):
    print(json.dumps(health(), indent=2))


def run_alarm(reason, text):
    rows = read_jsonl(state_file("alarms.jsonl"))
    now = now_utc()
    for r in rows:
        t = parse_ts(r.get("ts"))
        if r.get("reason") == reason and t and now - t < dt.timedelta(days=7):
            return 1
    lt = local(now)
    entry = f"ALARM reply pipeline {lt.strftime('%H:%M')}: {text}"
    args = ["--date", lt.date().isoformat(), "--entry", entry, "--source-persona", "Executioner"]
    alarm_bin = os.environ.get("PIPELINE_ALARM_BIN")
    if os.environ.get("PIPELINE_TEST") == "1" and not alarm_bin:
        die("test guard: PIPELINE_TEST=1 needs PIPELINE_ALARM_BIN", 2)
    cmd = [alarm_bin] + args if alarm_bin else [str(VAULT / ".vault_link" / ".scripts" / "append_log.sh")] + args
    try:
        r = subprocess.run(cmd, cwd=str(VAULT), capture_output=True, text=True, timeout=30)
        ok = r.returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        ok = False
    append_jsonl(state_file("alarms.jsonl"), {"ts": iso(now), "reason": reason, "text": text, "written": ok})
    return 0


def release_lock(slot_id):
    """A run that ends with nothing passed releases its own run lock (preflight.sh writes run_id)."""
    lock = state_file(".run.lock")
    owner = (lock / "slot_id").read_text().strip() if (lock / "slot_id").exists() else ""
    if lock.is_dir() and owner in ("", slot_id):
        for f in lock.iterdir():
            f.unlink()
        lock.rmdir()


def cmd_alarm(a):
    code = run_alarm(a.reason, a.text)
    print("alarm written" if code == 0 else "alarm deduplicated (same reason inside 7 days)")
    sys.exit(code)


def cmd_log(a):
    if a.reason not in REASONS:
        die(f"unknown reason {a.reason}; one of {sorted(REASONS)}")
    write_missed_lines()
    s = delivery_state()
    _, hhmm = parse_slot_id(a.slot)
    funnel = json.loads(a.funnel) if a.funnel else None
    line = {
        "ts": iso(now_utc()), "slot_id": a.slot, "mode": a.mode or s.get("modes", {}).get(hhmm, "trial"),
        "stage": stage_of(s), "batch_ids": [b for b in (a.batch_ids or "").split(",") if b],
        "attempts": a.attempts, "critic_model": a.critic_model, "grok_calls": a.grok_calls,
        "grok_ok": to_bool(a.grok_ok), "endpoint_ok": to_bool(a.endpoint_ok), "funnel": funnel,
        "delivered": a.delivered, "recommended": a.recommended, "emailed": bool(to_bool(a.emailed)),
        "minutes_to_sent": a.minutes_to_sent, "sent_before_window": to_bool(a.sent_before_window),
        "allowance_today": a.allowance_today, "posted_today": a.posted_today, "reason": a.reason,
        "detail": a.detail, "widen_used": bool(to_bool(a.widen_used)), "wall_min": a.wall_min, "alarm": None,
    }
    day = local(now_utc()).date()
    line["grok_calls_left_run"], _, line["grok_calls_left_today"] = grok_left(a.slot, day)
    refused = [r["refused"] for r in grok_rows() if r.get("slot_id") == a.slot and r.get("refused")]
    line["grok_stop"] = refused[-1] if refused else None
    append_jsonl(state_file("scheduler_log.jsonl"), line)
    if a.reason == "no_pass":
        release_lock(a.slot)
    append_jsonl(state_file("spend.jsonl"), {"ts": line["ts"], "slot_id": a.slot, "grok_calls": a.grok_calls,
                                              "agy_calls": a.agy_calls, "tok_in": a.tok_in,
                                              "tok_out": a.tok_out, "wall_min": a.wall_min})
    h = health()
    if h["alarm"]:
        h["alarm_written"] = run_alarm(h["alarm_reason"], h["alarm_text"]) == 0
    write_status()
    print(json.dumps({"logged": a.slot, "reason": a.reason, "health": h}))


# ---------- status -------------------------------------------------------------------
def status_line():
    outcomes = list(slot_outcomes().items())
    s = delivery_state()
    last = max((i for i, (_, r) in enumerate(outcomes) if r == "delivered"), default=-1)
    since = outcomes[last + 1:]
    bad = [r for _, r in since if r != "delivered"]
    stage = f"Stage {stage_of(s)}."
    if not since:
        return f"Since the last mail: no slot without mail. {stage}"
    words = ", ".join(sorted({REASON_WORDS.get(r, r) for r in bad}))
    return f"Since the last mail: {len(since)} slots, {len(bad)} without mail ({words}). {stage}"


def write_status():
    s = delivery_state()
    lines = slot_log()
    by_slot = {}
    for l in lines:
        if l.get("slot_id"):
            by_slot.setdefault(l["slot_id"], []).append(l)
    rows = []
    for sid in sorted(by_slot)[-10:]:
        ls = by_slot[sid]
        best = next((l for l in ls if l.get("reason") == "delivered"), ls[-1])
        grok = sum(int(l.get("grok_calls") or 0) for l in ls)
        rows.append(f"| {sid} | {best.get('reason')} | {best.get('delivered') if best.get('delivered') is not None else '-'} "
                    f"| {best.get('recommended') if best.get('recommended') is not None else '-'} "
                    f"| {best.get('minutes_to_sent') if best.get('minutes_to_sent') is not None else '-'} | {grok} |")
    stage = stage_of(s)
    nxt = "stage 3 is the last stage" if stage >= 3 else (
        "yes" if stage_check(s, stage + 1)[0] else "no: " + stage_check(s, stage + 1)[1])
    alarms = [r for r in read_jsonl(state_file("alarms.jsonl"))
              if parse_ts(r.get("ts")) and now_utc() - parse_ts(r["ts"]) < dt.timedelta(days=7)]
    day = today_local()
    st = stage_params(stage)
    allowance = int(min(st["all_replies_per_day"], avg_last_7(day) + P["volume"]["allowance_avg_plus"]))
    pause = (pause_reason_text(s) if paused(s, day) else "none")
    out = ["# Reply pipeline status", "",
           f"Updated {local(now_utc()).strftime('%Y-%m-%d %H:%M')} Israel. Written by `bin/slot_state.py status`; do not edit.", "",
           "## Last 10 slots", "", "| slot | reason | items | recommended | minutes to Sent | grok calls |",
           "|---|---|---|---|---|---|"] + (rows or ["| - | - | - | - | - | - |"]) + [
           "", "## Stage", "", f"- stage: {stage}", f"- next stage can open: {nxt}", "",
           "## Posting recommendation today", "",
           f"- allowance today (all his replies): {allowance}",
           f"- per run: up to {st['post_per_run']}; pipeline items a day: {st['pipeline_per_day']}", "",
           "## Open alarms", ""] + ([f"- {r['ts']} {r['reason']}: {r['text']}" for r in alarms] or ["- none"]) + [
           "", "## Pause", "", f"- {pause}", ""]
    STATUS_FILE.parent.mkdir(parents=True, exist_ok=True)
    STATUS_FILE.write_text("\n".join(out))


def cmd_status(a):
    if a.line:
        print(status_line())
        return
    write_status()
    print(f"wrote {STATUS_FILE}")


# ---------- history ------------------------------------------------------------------------
def cmd_history(a):
    now = now_utc()
    horizon = now - dt.timedelta(days=a.days)
    if a.urls:
        for u in sorted({r.get("url") for r in ledger()
                         if r.get("url") and (parse_ts(r.get("delivered_at")) or now) >= horizon}):
            print(u)
        return
    seen = set()
    for r in reply_log():
        t = parse_ts(r.get("posted_at"))
        txt = (r.get("text_posted") or "").replace("\n", " ").strip()
        if txt and t and t >= horizon and r.get("reply_url") not in seen:
            seen.add(r.get("reply_url"))
            print(txt)
    for r in ledger():
        t = parse_ts(r.get("delivered_at"))
        if r.get("starter") and t and now - t < dt.timedelta(hours=48):
            print(r["starter"].replace("\n", " "))


# ---------- trial report --------------------------------------------------------------------
def cmd_trial_report(a):
    T = P["trial"]
    lines = [l for l in slot_log() if l.get("mode", "trial") == "trial"]
    per = {}
    for l in lines:
        _, hhmm = parse_slot_id(l["slot_id"])
        per.setdefault(hhmm, []).append(l)
    rep, ok_all, tot_pass, tot_runs = [], True, 0, 0
    rep.append(f"# Trial report ({today_local().isoformat()})\n")
    for hhmm, ls in sorted(per.items()):
        gated = [l for l in ls if l.get("reason") in ("delivered", "no_pass")]
        days = {parse_slot_id(l["slot_id"])[0] for l in gated}
        wd = sum(1 for d in days if d.weekday() < 5)
        we = sum(1 for d in days if d.weekday() >= 5)
        passed = sum(1 for l in gated if l.get("reason") == "delivered")
        share = passed / len(gated) if gated else 0.0
        tot_pass += passed
        tot_runs += len(gated)
        cover = wd >= T["min_weekdays"] and we >= T["min_weekend_days"]
        ok_all &= cover
        mins = [l["minutes_to_sent"] for l in ls if isinstance(l.get("minutes_to_sent"), (int, float))]
        late = sum(1 for l in ls if l.get("sent_before_window") is False)
        grok = [int(l.get("grok_calls") or 0) for l in gated]
        rep += [f"## Slot {hhmm}", "",
                f"- runs that reached the gate: {len(gated)} (weekdays {wd}, weekend days {we}; coverage {'ok' if cover else 'missing'})",
                f"- runs with a passing item: {passed} of {len(gated)} = {share:.2f} ({'live-ready' if share >= T['pass_share'] else 'not live-ready'})",
                f"- infra stops: {sum(1 for l in ls if l.get('reason') not in ('delivered', 'no_pass', 'missed'))}; missed: {sum(1 for l in ls if l.get('reason') == 'missed')}",
                f"- minutes to Sent (median): {statistics.median(mins) if mins else 'n/a'}; mails in Sent after the window opened: {late}",
                f"- grok calls per run (mean): {sum(grok) / len(grok) if grok else 'n/a'}", ""]
    share = tot_pass / tot_runs if tot_runs else 0.0
    ok_all = ok_all and bool(per) and share >= T["pass_share"]
    rep.append(f"Overall: {tot_pass} of {tot_runs} = {share:.2f}. Verdict: {'trial passed' if ok_all else 'not yet'}.")
    path = ANALYTICS / "trial_report.md"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(rep) + "\n")
    print("\n".join(rep))
    sys.exit(0 if ok_all else 1)


# ---------- cli --------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("slot-id")
    p.add_argument("--slot")
    p = sub.add_parser("budget")
    g = p.add_mutually_exclusive_group(required=True)
    g.add_argument("--posted-today", type=int)
    g.add_argument("--posted-today-unknown", action="store_true")
    p.add_argument("--partial", action="store_true")
    p.add_argument("--slot")
    p = sub.add_parser("set-stage")
    p.add_argument("stage", type=int, choices=[2, 3])
    p.add_argument("--reason", required=True)
    p = sub.add_parser("record")
    p.add_argument("--slot", required=True)
    p.add_argument("--replies", required=True)
    p = sub.add_parser("log")
    p.add_argument("--slot", required=True)
    p.add_argument("--reason", required=True)
    for f in ("funnel", "batch-ids", "critic-model", "grok-ok", "endpoint-ok", "emailed", "sent-before-window",
              "detail", "widen-used", "mode"):
        p.add_argument("--" + f)
    for f in ("minutes-to-sent", "wall-min", "tok-in", "tok-out"):
        p.add_argument("--" + f, type=float)
    for f in ("grok-calls", "agy-calls", "attempts", "delivered", "recommended", "allowance-today", "posted-today"):
        p.add_argument("--" + f, type=int)
    sub.add_parser("health")
    p = sub.add_parser("alarm")
    p.add_argument("--reason", required=True)
    p.add_argument("--text", required=True)
    p = sub.add_parser("status")
    p.add_argument("--line", action="store_true")
    p = sub.add_parser("history")
    p.add_argument("--days", type=int, required=True)
    p.add_argument("--urls", action="store_true")
    p = sub.add_parser("set-mode")
    p.add_argument("--slot", required=True)
    p.add_argument("mode", choices=["trial", "live"])
    p = sub.add_parser("pause")
    p.add_argument("--days", type=int, required=True)
    p.add_argument("--reason", required=True)
    sub.add_parser("trial-report")
    p = sub.add_parser("grok-call")
    p.add_argument("--slot", required=True)
    p.add_argument("--purpose", required=True, choices=[*RUN_PURPOSES, "maintenance"])
    p.add_argument("--batch")
    p = sub.add_parser("grok-result")
    p.add_argument("--slot", required=True)
    p.add_argument("--purpose", required=True, choices=[*RUN_PURPOSES, "maintenance"])
    p.add_argument("--ok", required=True)
    a = ap.parse_args()
    if a.cmd == "slot-id":
        sid = current_slot_id(a.slot)
        if not sid:
            die("no slot window now", 3)
        print(sid)
        return
    {"budget": cmd_budget, "set-stage": cmd_set_stage, "record": cmd_record, "log": cmd_log,
     "health": cmd_health, "alarm": cmd_alarm, "status": cmd_status, "history": cmd_history,
     "set-mode": cmd_set_mode, "pause": cmd_pause, "trial-report": cmd_trial_report,
     "grok-call": cmd_grok_call, "grok-result": cmd_grok_result}[a.cmd](a)


if __name__ == "__main__":
    main()

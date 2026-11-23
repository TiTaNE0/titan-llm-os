#!/usr/bin/env python3
"""measure.py - per-reply log, marks, tripwire, agreement, X Analytics import and the period report
of the @ogrizkov reply pipeline (v3.2, DECISION section 3 as amended). Never sends email.

  init
  due
  merge --pages F
  tripwire
  marks --from-json F | marks --item ID --verdict V --reason R [--note T] --source chat
  gate-change --note T
  agreement [--export F]
  import-export --file F
  period --end DATE [--day 14|28]
"""
import argparse
import csv
import datetime as dt
import json
import re
import statistics
import sys
from pathlib import Path

BIN = Path(__file__).resolve().parent
sys.path.insert(0, str(BIN))
import slot_state as S  # noqa: E402

A = S.ANALYTICS
P = S.P
# Implied experience, the same rule as gate.sh --type clean (keep the two in step).
EXP_VERBS = (r"ran|run|running|built|build|use|used|using|tried|tested|shipped|saw|seen|hit|had|have|keep|kept|wrote|"
             r"write|measured|found|learned|switched|moved|got")
ADVERB = r"also|just|already|once|never|often|always|still|even|first|then|too|[a-z]+ly"
EXP_STRONG = re.compile(rf"\b(my|our|mine)\b|\bme too\b|\b(i|we)\s+(({ADVERB})\s+)?({EXP_VERBS})\b|\b(i|we)['’]ve\b", re.I)
EXP_WEAK = re.compile(r"\b(i['’](m|d)|we['’](re|d))\b|^[\s\W]*(tried|ran|hit|saw|tested|built|shipped|switched|measured|wrote)\b",
                      re.I)


def implied_experience(text):
    if EXP_STRONG.search(text or ""):
        return True
    for sent in re.findall(r"[^.!?;]+[.!?;]?", text or ""):
        if sent.rstrip().endswith("?") and re.search(r"\byou\b", sent, re.I):
            continue
        if EXP_WEAK.search(re.sub(r"^([\s\W]*)hit\s+rates?", r"\1rate", sent, flags=re.I)):
            return True
    return False
REASONS = ("good", "boring", "forced", "wrong post", "too late")


def die(msg, code=2):
    print(msg, file=sys.stderr)
    sys.exit(code)


def norm_words(s):
    return re.sub(r"[^a-z0-9]+", " ", (s or "").lower()).split()


def shares_run(a, b, k=5):
    wa, wb = norm_words(a), " " + " ".join(norm_words(b)) + " "
    return any(" " + " ".join(wa[i:i + k]) + " " in wb for i in range(len(wa) - k + 1))


def median(vals):
    vals = [v for v in vals if isinstance(v, (int, float))]
    if not vals:
        return None
    m = statistics.median(vals)
    return int(m) if float(m).is_integer() else round(m, 1)


# ---------- init / due -------------------------------------------------------------------
def cmd_init(a):
    A.mkdir(parents=True, exist_ok=True)
    w, m = A / "weekly.md", A / "marks.md"
    made = []
    if not w.exists():
        w.write_text("# Weekly operator numbers\n\nOperator file: profile visits and new follows once a week "
                     "(X app, profile analytics). The monthly X report goes to under_the_hood/YYYY-MM.json.\n\n"
                     "pinned_post_url: \n\n| week | profile visits | new follows |\n|---|---|---|\n| week 0 | | |\n")
        made.append(str(w))
    if not m.exists():
        m.write_text("# Marks\n\nOne line per mark, on recommended and review items alike:\n"
                     "`- DATE · ITEM_ID · URL · mark: would_post|would_not · reason: good|boring|forced|wrong post|"
                     "too late|none · gate: pass · source: email|posted|chat · note: TEXT`\n\n")
        made.append(str(m))
    print(json.dumps({"created": made}))


def proposal_newer_than(days):
    today = S.today_local()
    for f in A.glob("patterns_proposal_*.md"):
        m = re.search(r"(\d{4}-\d{2}-\d{2})", f.name)
        if m and (today - dt.date.fromisoformat(m.group(1))).days < days:
            return True
    return False


def qualification_due():
    cm = S.read_json(S.state_file("critic_model.json"), {})
    q = S.read_json(S.state_file("critic_qualified.json"), {})
    e = q.get(cm.get("telemetry_id"))
    t = S.parse_ts((e or {}).get("at"))
    return not t or S.now_utc() - t >= dt.timedelta(days=P["critic_qualified_days"])


def period_due():
    live = S.delivery_state().get("live_since")
    if not live:
        return None
    since = dt.date.fromisoformat(live)
    days = (S.today_local() - since).days
    done = [dt.date.fromisoformat(m.group(1)) for f in A.glob("period_*.md")
            if (m := re.search(r"(\d{4}-\d{2}-\d{2})", f.name))]
    for d in (P["measure"]["period_days"], 2 * P["measure"]["period_days"]):
        if days >= d and not any(x >= since + dt.timedelta(days=d) for x in done):
            return d
    return None


def cmd_due(a):
    now = S.now_utc()
    have = {(r.get("item_id"), r.get("reading")) for r in S.reply_log()}
    items = []
    for it in S.ledger():
        t = S.parse_ts(it.get("delivered_at"))
        if not t:
            continue
        age_h = (now - t).total_seconds() / 3600
        for h in P["measure"]["read_hours"]:
            if h <= age_h < h + 72 and (it["item_id"], f"{h}h") not in have:
                items.append({"item_id": it["item_id"], "url": it["url"], "reading": f"{h}h"})
    print(json.dumps({"items": items,
                      "patterns_refresh_due": not proposal_newer_than(P["measure"]["patterns_refresh_days"]),
                      "qualification_due": qualification_due(), "period_due": period_due()}, indent=2))


# ---------- merge -------------------------------------------------------------------------
def item_for(parent, led):
    for it in reversed(led):
        if parent in (it.get("url"), it.get("reply_to_url")):
            return it
    return None


def base_row(rd, it, now, arm):
    posted = S.parse_ts(rd.get("posted_at"))
    hours = round((now - posted).total_seconds() / 3600, 1) if posted else None
    reading = rd.get("reading") or ("24h" if hours is not None and hours < 36 else "48h")
    item_post = S.parse_ts((it or {}).get("posted_at"))
    text = rd.get("text") or ""
    starter = (it or {}).get("starter") or ""
    return {
        "reply_url": rd.get("reply_url"), "parent_url": rd.get("parent_url"), "arm": arm,
        "item_id": (it or {}).get("item_id"), "recommended": (it or {}).get("recommended"),
        "move": (it or {}).get("move"), "posted_at": rd.get("posted_at"), "read_at": S.iso(now),
        "hours_since_post": hours, "reading": reading, "views": rd.get("views"), "likes": rd.get("likes"),
        "replies": rd.get("replies"), "parent_views": rd.get("parent_views"),
        "parent_views_at_capture": (it or {}).get("parent_views_at_capture"),
        # None = not known (the answer lookup ran out of pages): kept as null, never counted as no answer
        "author_answered": None if rd.get("author_answered") is None else bool(rd.get("author_answered")),
        "author_only_corrected": bool(rd.get("author_only_corrected")),
        "followed_up": bool(rd.get("follow_up")) and bool(rd.get("author_answered")), "text_posted": text,
        "type": (it or {}).get("reply_type"), "tier": (it or {}).get("tier"),
        "hook": (it or {}).get("hook") if arm == "pipeline" else "",
        "added_experience": implied_experience(text) and not implied_experience(starter),
        "parent_age_min_at_post": int((posted - item_post).total_seconds() / 60) if posted and item_post else None,
        "replies_at_capture": (it or {}).get("replies_at_capture"), "slot": (it or {}).get("slot_id"),
        "delivery_mode": "B", "own_words": not shares_run(text, starter) if starter else True,
        "form": "question" if text.rstrip().endswith("?") else "statement", "replies_that_day": None,
    }


def follow_row(rd, it, now):
    f = rd["follow_up"]
    r = base_row({"reply_url": f.get("url"), "parent_url": rd.get("reply_url"), "posted_at": f.get("posted_at"),
                  "text": f.get("text"), "reading": rd.get("reading")}, it, now, "follow_up")
    r["item_id"] = (it or {}).get("item_id")
    return r


def append_mark(line_fields):
    A.mkdir(parents=True, exist_ok=True)
    m = A / "marks.md"
    if not m.exists():
        cmd_init(None)
    with m.open("a") as f:
        f.write(" · ".join(line_fields) + "\n")


def mark_line(date, item_id, url, verdict, reason, source, note):
    return [f"- {date}", item_id or "", url or "", f"mark: {verdict}", f"reason: {reason or 'none'}",
            "gate: pass", f"source: {source}", f"note: {(note or '').replace('·', '-')}"]


def update_counts(rows):
    pc = S.posted_counts()
    days = pc.setdefault("days", {})
    per = {}
    for r in rows:
        if r["arm"] in ("pipeline", "follow_up", "own"):
            d = S.local_date_of(r.get("posted_at"))
            if d:
                per.setdefault(d.isoformat(), set()).add(r["reply_url"])
    for d, urls in per.items():
        days[d] = max(int(days.get(d, 0) or 0), len(urls))
    S.write_json(S.state_file("posted_counts.json"), pc)
    return days


def load_pages(path):
    data = S.read_json(path, None)
    if data is None:
        die(f"cannot read pages: {path}")
    return data.get("readings", data) if isinstance(data, dict) else data


def cmd_merge(a):
    now = S.now_utc()
    led = S.ledger()
    log = S.reply_log()
    have = {(r.get("reply_url"), r.get("reading")) for r in log}
    new, unknown = [], 0
    for rd in load_pages(a.pages):
        # an unknown reading (a cursor left unread) is neither a reply nor "no reply"; the item stays due
        if rd.get("found", True) is None or rd.get("note") == "unknown":
            unknown += 1
            continue
        if not rd.get("found", True) or not rd.get("reply_url"):
            continue
        it = item_for(rd.get("parent_url"), led)
        arm = "pipeline" if it else "own"
        if arm == "own" and not P["cost"]["grok_own_arm"]:
            continue
        rows = [base_row(rd, it, now, arm)]
        if rd.get("follow_up") and rd.get("author_answered"):
            rows.append(follow_row(rd, it, now))
        for r in rows:
            if (r["reply_url"], r["reading"]) not in have:
                have.add((r["reply_url"], r["reading"]))
                new.append(r)
    days = update_counts(log + new)
    marked = {l.split(" · ")[1] for l in marks_lines() if "source: posted" in l}
    authors = S.read_json(S.state_file("authors.json"), {"authors": {}})
    for r in new:
        r["replies_that_day"] = days.get((S.local_date_of(r.get("posted_at")) or S.today_local()).isoformat())
        S.append_jsonl(A / "reply_log.jsonl", r)
        it = next((i for i in led if i.get("item_id") == r.get("item_id")), None)
        if r["arm"] == "pipeline" and it and it.get("mode") == "trial" and it["item_id"] not in marked:
            marked.add(it["item_id"])
            append_mark(mark_line(S.today_local().isoformat(), it["item_id"], it["url"], "would_post", "none",
                                  "posted", "he posted this trial item"))
        if r["arm"] == "pipeline" and r["author_answered"] is True and r["reading"] == "24h" and it:
            e = authors.setdefault("authors", {}).setdefault((it.get("author") or "").lower(),
                                                             {"author": it.get("author"), "answered_him": 0})
            e["answered_him"] = e.get("answered_him", 0) + 1
    S.write_json(S.state_file("authors.json"), authors)
    fix_followed_up(new)
    print(json.dumps({"rows_added": len(new), "unknown": unknown}))


def fix_followed_up(new):
    """A follow-up row marks the first reply of that thread as followed_up."""
    fu = {r["parent_url"] for r in new if r["arm"] == "follow_up"}
    if not fu:
        return
    rows = S.reply_log()
    for r in rows:
        if r.get("arm") == "pipeline" and r.get("reply_url") in fu:
            r["followed_up"] = True
    p = A / "reply_log.jsonl"
    p.write_text("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in rows))


# ---------- tripwire -------------------------------------------------------------------------
def cmd_tripwire(a):
    T = P["tripwire"]
    s = S.delivery_state()
    since = S.parse_ts(s.get("tripwire_counted_until"))
    rows = [r for r in S.pipeline_rows([r for r in S.reply_log() if r.get("reading") == f"{T['at_hours']}h"])
            if (r.get("parent_views") or 0) > T["min_parent_views"] and isinstance(r.get("views"), int)
            and (since is None or (S.parse_ts(r.get("posted_at")) or since) > since)]
    rows.sort(key=lambda r: r.get("posted_at") or "")
    last = rows[-T["run_length"]:]
    tripped = len(last) == T["run_length"] and all((r.get("views") or 0) <= T["max_views"] for r in last)
    if tripped:
        s = S.apply_pause(s, T["pause_days"], "tripwire", True)
        s["tripwire_counted_until"] = last[-1].get("posted_at")
        S.save_delivery_state(s)
        S.run_alarm("tripwire", f"tripwire: posting recommendation 0 until {s['paused_until']}; delivery for review goes on")
    print(json.dumps({"tripped": tripped, "counted": len(rows), "paused_until": s.get("paused_until")}))


# ---------- marks / gate changes / agreement ---------------------------------------------------
def marks_lines():
    try:
        return [l for l in (A / "marks.md").read_text().splitlines() if l.startswith("- ") and " · mark: " in l]
    except OSError:
        return []


def parse_mark(l):
    parts = l[2:].split(" · ")
    d = {"date": parts[0], "item_id": parts[1] if len(parts) > 1 else "", "url": parts[2] if len(parts) > 2 else ""}
    for p in parts[3:]:
        k, _, v = p.partition(": ")
        d[k] = v
    return d


def cmd_marks(a):
    led = {r["item_id"]: r for r in S.ledger()}
    today = S.today_local().isoformat()
    if a.item:
        if a.verdict not in ("would_post", "would_not"):
            die("--verdict must be would_post or would_not")
        append_mark(mark_line(today, a.item, (led.get(a.item) or {}).get("url"), a.verdict, a.reason,
                              a.source or "chat", a.note))
        print(json.dumps({"marked": a.item}))
        return
    seen_path = S.state_file("feedback_seen.json")
    seen = set(S.read_json(seen_path, []))
    raw = Path(a.from_json).read_text()
    try:
        msgs = json.loads(raw)
        msgs = msgs if isinstance(msgs, list) else [msgs]
    except ValueError:
        msgs = [json.loads(l) for l in raw.splitlines() if l.strip()]
    n = 0
    for m in msgs:
        if not m.get("message_id") or m["message_id"] in seen or not m.get("slot_id"):
            continue
        seen.add(m["message_id"])
        for mk in m.get("marks", []):
            iid = f"{m['slot_id']}#{mk['n']}"
            append_mark(mark_line(today, iid, (led.get(iid) or {}).get("url"), mk["verdict"], mk.get("reason"),
                                  "email", mk.get("note")))
            n += 1
    S.write_json(seen_path, sorted(seen))
    print(json.dumps({"marks_added": n}))


def cmd_gate_change(a):
    A.mkdir(parents=True, exist_ok=True)
    with (A / "gate_changes.md").open("a") as f:
        f.write(f"- {S.iso(S.now_utc())} · {a.note}\n")
    print("gate change recorded; a new 26-mark agreement window opens")


def last_gate_change():
    try:
        lines = [l for l in (A / "gate_changes.md").read_text().splitlines() if l.startswith("- ")]
    except OSError:
        return None
    return S.parse_ts(lines[-1][2:].split(" · ")[0]) if lines else None


def snapshot_for(it):
    for run in sorted((S.C / "runs").glob(f"{it.get('slot_id')}*_batch")):
        th = S.read_json(run / "00b_threads.json", {}).get("threads", [])
        for t in th:
            if t.get("url") == it.get("url"):
                return t
    return None


def cmd_agreement(a):
    T = P["trial"]
    gc = last_gate_change()
    marks = {}
    for l in marks_lines():
        m = parse_mark(l)
        marks[m["item_id"]] = m
    window = [it for it in S.ledger() if it.get("item_id") in marks
              and (gc is None or (S.parse_ts(it.get("delivered_at")) or gc) > gc)]
    window.sort(key=lambda it: it.get("delivered_at") or "")
    window = window[:T["marks_needed"]]
    agree = sum(1 for it in window if marks[it["item_id"]].get("mark") == "would_post")
    if a.export:
        S.write_json(a.export, {"items": [{"item_id": it["item_id"], "url": it["url"], "draft": it.get("starter"),
                                            "mark": marks[it["item_id"]].get("mark"),
                                            "reason": marks[it["item_id"]].get("reason"),
                                            "snapshot": snapshot_for(it)} for it in window]})
    ok = len(window) >= T["marks_needed"] and agree >= T["marks_agree"]
    print(json.dumps({"marked_items": len(window), "agree": agree, "needed": T["marks_needed"],
                      "bar": T["marks_agree"], "passed": ok,
                      "since_gate_change": S.iso(gc) if gc else None}))
    sys.exit(0 if ok else 1)


# ---------- import-export -------------------------------------------------------------------------
def col(header, *needles):
    for i, h in enumerate(header):
        hl = h.strip().lower()
        if any(n in hl for n in needles):
            return i
    return None


def cmd_import_export(a):
    try:
        rows = list(csv.reader(Path(a.file).read_text(encoding="utf-8-sig").splitlines()))
    except OSError as e:
        die(f"cannot read {a.file}: {e}")
    if not rows:
        die("empty export file", 1)
    header = rows[0]
    print("header: " + " | ".join(header))
    visits = col(header, "profile visit")
    post = col(header, "post id", "tweet id", "post link", "tweet permalink", "permalink", "post url")
    date = col(header, "date")
    follows = col(header, "new follow", "follows")
    out_path = A / f"export_{S.today_local().isoformat()}.json"
    if visits is not None and post is not None:
        print(f"mapping: post={header[post]!r} profile_visits={header[visits]!r} (per post)")
        log = {re.sub(r"\D", "", (r.get("reply_url") or "").rsplit("/", 1)[-1]): r for r in S.pipeline_rows()}
        joined = []
        for r in rows[1:]:
            if len(r) <= max(post, visits):
                continue
            pid = (re.search(r"(\d{6,})", r[post]) or [None, ""])[1]
            if pid in log:
                joined.append({"reply_url": log[pid]["reply_url"], "profile_visits": S.to_int(r[visits]),
                               "hook": log[pid].get("hook"), "tier": log[pid].get("tier")})
        S.write_json(out_path, {"kind": "per_post", "file": a.file, "mapping": {"post": header[post],
                                "profile_visits": header[visits]}, "rows": joined})
        print(f"joined {len(joined)} rows to the reply log; wrote {out_path}")
        return
    if visits is not None and date is not None:
        print(f"mapping: date={header[date]!r} profile_visits={header[visits]!r}"
              + (f" new_follows={header[follows]!r}" if follows is not None else "") + " (account totals)")
        tot = [{"date": r[date], "profile_visits": S.to_int(r[visits]),
                "new_follows": S.to_int(r[follows]) if follows is not None and len(r) > follows else None}
               for r in rows[1:] if len(r) > max(date, visits)]
        S.write_json(out_path, {"kind": "account_totals", "file": a.file, "rows": tot})
        print(f"this export has account totals only, no per-post profile visits; stored as weekly totals in {out_path}")
        return
    print("unknown layout: no profile-visits column with a post id or a date column; nothing imported", file=sys.stderr)
    sys.exit(1)


# ---------- period report --------------------------------------------------------------------------
def group_table(rows, keyfn, title, label):
    groups = {}
    for r in rows:
        groups.setdefault(keyfn(r), []).append(r)
    out = [f"### {title}", "", f"| {label} | replies | median views 48h | author answers | judged |", "|---|---|---|---|---|"]
    for k in sorted(groups, key=lambda x: str(x)):
        g = groups[k]
        n = len(g)
        if n < 30:
            out.append(f"| {k} | {n} | - | - | not judged |")
        else:
            out.append(f"| {k} | {n} | {median([r.get('views') for r in g])} | "
                       f"{sum(1 for r in g if r.get('author_answered') is True and not r.get('author_only_corrected'))} | yes |")
    return out + [""]


def weekly_rows():
    try:
        text = (A / "weekly.md").read_text()
    except OSError:
        return []
    out = []
    for l in text.splitlines():
        m = re.match(r"^\|\s*(week [^|]*)\|\s*([^|]*)\|\s*([^|]*)\|", l)
        if m:
            out.append((m.group(1).strip(), S.to_int(m.group(2).strip()), S.to_int(m.group(3).strip())))
    return out


def bottleneck_line():
    w = [r for r in weekly_rows() if r[1] is not None]
    if len(w) < 2 or w[0][0] != "week 0":
        return None
    base, last = w[0], w[-1]
    if last[1] > base[1] and (last[2] or 0) <= (base[2] or 0):
        return "The profile is the bottleneck: visits rose and follows did not."
    return None


def weakest_third():
    st = S.read_json(S.state_file("authors.json"), {"authors": {}}).get("authors", {})
    wl = S.read_json(S.env_path("PIPELINE_WATCHLIST", S.C / "agents" / "watchlist.json"), {}).get("authors", [])
    ranked = sorted(wl, key=lambda e: ((st.get(e["handle"].lower()) or {}).get("answered_him", 0),
                                       (st.get(e["handle"].lower()) or {}).get("delivered", 0)))
    return [e["handle"] for e in ranked[:max(1, len(ranked) // 3)]] if ranked else []


def period_rows(end, days):
    start = end - dt.timedelta(days=days)
    inwin = lambda ts: (d := S.local_date_of(ts)) is not None and start < d <= end
    rows = [r for r in S.reply_log() if inwin(r.get("posted_at"))]
    led = [it for it in S.ledger() if inwin(it.get("delivered_at"))]
    return rows, led, start


def volume_verdict(posted, share, answers, med, day28, prev_med, prev_posted):
    if day28 and med is not None and prev_med and med < prev_med / 2 and posted >= 20 and prev_posted >= 20:
        return "cut by 2"
    if posted >= 40 and share >= 0.7 and answers >= 3 and (med or 0) >= 10 and S.latest_monthly_label_free():
        return "raise"
    if day28 and answers < 3:
        return "replace the weakest third of the watchlist; volume stays"
    if posted < 40 and share >= 0.7:
        return "hold: decide on a second run inside the window"
    return "no volume change"


def cmd_period(a):
    end = dt.date.fromisoformat(a.end)
    days = P["measure"]["period_days"]
    live = S.delivery_state().get("live_since")
    day = a.day or (28 if live and (end - dt.date.fromisoformat(live)).days >= 2 * days else 14)
    rows, led, start = period_rows(end, days)
    pipe = [r for r in S.pipeline_rows(rows)]
    r48 = [r for r in pipe if r.get("reading") == "48h"] or [r for r in pipe if r.get("reading") == "24h"]
    posted = len({r["reply_url"] for r in pipe})
    rec = [it for it in led if it.get("recommended")]
    posted_items = {r.get("item_id"): r for r in pipe}
    in_time = sum(1 for it in rec if it["item_id"] in posted_items
                  and (S.parse_ts(posted_items[it["item_id"]].get("posted_at")) or S.now_utc())
                  <= (S.parse_ts(it.get("post_by")) or S.now_utc()))
    share = in_time / len(rec) if rec else 0.0
    answers = sum(1 for r in pipe if r.get("author_answered") is True and not r.get("author_only_corrected"))
    unknown_answer = sum(1 for r in pipe if r.get("author_answered") is None)
    med = median([r.get("views") for r in r48])
    prev_rows, _, _ = period_rows(start, days)
    prev_pipe = S.pipeline_rows(prev_rows)
    prev_med = median([r.get("views") for r in prev_pipe if r.get("reading") == "48h"])
    verdict = volume_verdict(posted, share, answers, med, day == 28, prev_med, len(prev_pipe))
    s = S.delivery_state()
    pauses = [t for t in s.get("tripwires", []) if (d := S.local_date_of(t)) and start < d <= end]
    fu = [r for r in rows if r.get("arm") == "follow_up"]
    fu_days = {}
    for r in fu:
        k = (r.get("item_id"), S.local_date_of(r.get("posted_at")))
        fu_days[k] = fu_days.get(k, 0) + 1
    funnel = [l.get("funnel") or {} for l in S.slot_log() if (d := S.local_date_of(l.get("ts"))) and start < d <= end]
    bands = {}
    for f in funnel:
        for b, v in (f.get("by_age_band") or {}).items():
            e = bands.setdefault(b, {"candidates": 0, "passed": 0})
            e["candidates"] += v.get("candidates", 0)
            e["passed"] += v.get("passed", 0)
    exports = sorted(A.glob("export_*.json"))
    per_post = next((S.read_json(f, {}) for f in reversed(exports) if S.read_json(f, {}).get("kind") == "per_post"), None)
    out = [f"# Period report, {start + dt.timedelta(days=1)} to {end} (day {day})", "",
           "Written by `bin/measure.py period`. Report only; never an email.", "",
           f"- posted replies (pipeline): {posted}",
           f"- posted share: {in_time} of {len(rec)} recommended items posted in time = {share:.2f} (review items do not count)",
           f"- author answers without corrections: {answers}",
           f"- author answer unknown (not counted): {unknown_answer}",
           f"- median views at 48 h: {med if med is not None else 'n/a'}",
           f"- pause events: {len(pauses)}",
           f"- follow-ups: {len(fu)}; threads with more than one a day: {sum(1 for v in fu_days.values() if v > 1)}", "",
           "## Fixed questions", "",
           f"- Q1, does he post what is delivered: posted share {share:.2f} (bar 0.70)",
           f"- Q2, do authors answer: {answers} answers in {posted - unknown_answer} posted with a known answer "
           f"(bar 3 in 40 or more)",
           "- Q3, typed against pasted: not tested in delivery mode B (he writes every reply)",
           f"- Q4, growth: {'per-post profile visits imported' if per_post else 'no per-post export imported yet'}; "
           f"weekly visits against week 0 in weekly.md", ""]
    out += ["## Report-only tables (groups under 30 replies are not judged)", ""]
    out += group_table(pipe, lambda r: "large account (tier 3)" if str(r.get("tier")) == "3" else "small authors (tiers 1-2)",
                       "Large-account lane against small authors", "group")
    out += group_table(pipe, lambda r: r.get("move") or "unknown", "By move", "move")
    mom = {it["item_id"]: it.get("momentum") for it in S.ledger()}
    out += group_table(pipe, lambda r: "momentum at capture" if mom.get(r.get("item_id")) else "no momentum",
                       "Posts with and without momentum at capture", "momentum")
    out += group_table(pipe, lambda r: r.get("hook") or "none", "By hook", "hook")
    out += group_table(pipe, lambda r: r.get("type") or "unknown", "By type (D2)", "type")
    out += group_table(pipe, lambda r: f"tier {r.get('tier')}", "By tier (D3)", "tier")
    out += group_table(pipe, lambda r: ("1-2" if (r.get("replies_that_day") or 0) <= 2 else
                                        "3-4" if (r.get("replies_that_day") or 0) <= 4 else "5+"),
                       "By replies that day (D1)", "replies that day")
    out += group_table(pipe, lambda r: "added experience" if r.get("added_experience") else "no added experience",
                       "Views by added experience", "text")
    out += ["### Candidates and passed items by age band", "", "| band | candidates | passed |", "|---|---|---|"]
    out += [f"| {b} | {v['candidates']} | {v['passed']} |" for b, v in sorted(bands.items())] or ["| - | 0 | 0 |"]
    out += [""]
    if per_post:
        out += ["### Per-post profile visits (imported export)", "", "| reply | profile visits |", "|---|---|"]
        out += [f"| {r['reply_url']} | {r['profile_visits']} |" for r in per_post.get("rows", [])] + [""]
    bl = bottleneck_line()
    if bl:
        out += [bl, ""]
    if verdict.startswith("replace"):
        out += ["Weakest third of the watchlist (fewest answers to him): " + ", ".join(weakest_third()), ""]
    out += [f"Verdict: {verdict}. The operator confirms.", ""]
    path = A / f"period_{end.isoformat()}.md"
    A.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(out))
    print(json.dumps({"wrote": str(path), "verdict": verdict, "posted": posted, "share": round(share, 2)}))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("init")
    sub.add_parser("due")
    p = sub.add_parser("merge")
    p.add_argument("--pages", required=True)
    sub.add_parser("tripwire")
    p = sub.add_parser("marks")
    p.add_argument("--from-json")
    p.add_argument("--item")
    p.add_argument("--verdict")
    p.add_argument("--reason", default="none")
    p.add_argument("--note", default="")
    p.add_argument("--source", default="chat")
    p = sub.add_parser("gate-change")
    p.add_argument("--note", required=True)
    p = sub.add_parser("agreement")
    p.add_argument("--export")
    p = sub.add_parser("import-export")
    p.add_argument("--file", required=True)
    p = sub.add_parser("period")
    p.add_argument("--end", required=True)
    p.add_argument("--day", type=int, choices=[14, 28])
    a = ap.parse_args()
    if a.cmd == "marks" and not (a.from_json or a.item):
        die("marks needs --from-json F or --item ID")
    {"init": cmd_init, "due": cmd_due, "merge": cmd_merge, "tripwire": cmd_tripwire, "marks": cmd_marks,
     "gate-change": cmd_gate_change, "agreement": cmd_agreement, "import-export": cmd_import_export,
     "period": cmd_period}[a.cmd](a)


if __name__ == "__main__":
    main()
